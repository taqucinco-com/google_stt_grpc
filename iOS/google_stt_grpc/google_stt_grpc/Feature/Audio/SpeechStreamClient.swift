//
//  SpeechStreamClient.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import Foundation
import GRPCCore
import GRPCNIOTransportHTTP2
import SwiftProtobuf

/// `hono`から取得したアクセストークンを`authorization: Bearer <token>`として
/// 各RPCのメタデータに注入するインターセプタ。
private struct AuthorizationInjectingInterceptor: ClientInterceptor {
  let fetchToken: @Sendable () async throws -> String

  func intercept<Input: Sendable, Output: Sendable>(
    request: StreamingClientRequest<Input>,
    context: ClientContext,
    next: @concurrent (
      _ request: StreamingClientRequest<Input>,
      _ context: ClientContext
    ) async throws -> StreamingClientResponse<Output>
  ) async throws -> StreamingClientResponse<Output> {
    let token = try await fetchToken()
    var request = request
    request.metadata.addString("Bearer \(token)", forKey: "authorization")
    return try await next(request, context)
  }
}

/// Google Cloud Speech-to-Text(v1)のStreamingRecognizeを叩く。
/// 最初のメッセージはconfigのみ、以降はaudio_content(OGG_OPUS)のみを送る。
func testSpeechStream(languageCode: String = "ja-JP") -> (send: (Data) -> Void, finish: () -> Void, result: AsyncThrowingStream<String, Error>) {
  let (outbound, outboundContinuation) = AsyncStream<Data>.makeStream()
  let (inbound, inboundContinuation) = AsyncThrowingStream<String, Error>.makeStream()

  let interceptor = AuthorizationInjectingInterceptor {
    try await AuthTokenClient().fetchToken().accessToken
  }

  let task = Task {
    do {
      try await withGRPCClient(
        transport: .http2NIOPosix(
          target: .dns(host: "speech.googleapis.com", port: 443),
          transportSecurity: .tls
        ),
        interceptors: [interceptor]
      ) { client in
        let speech = Google_Cloud_Speech_V1_Speech.Client(wrapping: client)
        try await speech.streamingRecognize { writer in
          try await writer.write(.with {
            $0.streamingConfig = .with {
              $0.config = .with {
                $0.encoding = .oggOpus
                $0.sampleRateHertz = 16000
                $0.languageCode = languageCode
              }
              $0.interimResults = true
            }
          })
          for await chunk in outbound {
            try await writer.write(.with { $0.audioContent = chunk })
          }
        } onResponse: { response in
          for try await res in response.messages {
            for result in res.results {
              if let alternative = result.alternatives.first {
                inboundContinuation.yield(alternative.transcript)
              }
            }
          }
        }
      }
      inboundContinuation.finish()
    } catch {
      inboundContinuation.finish(throwing: error)
    }
  }
  inboundContinuation.onTermination = { _ in task.cancel() }

  return (
    send: { data in outboundContinuation.yield(data) },
    finish: { outboundContinuation.finish() },
    result: inbound
  )
}
