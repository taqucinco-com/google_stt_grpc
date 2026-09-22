//
//  grpc_sample.swift
//  google_stt_grpc
//

import AsyncAlgorithms
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import SwiftProtobuf

func testUnary() async throws -> String {
  try await withGRPCClient(
    transport: .http2NIOPosix(
      target: .dns(host: "localhost", port: 50051),
      transportSecurity: .plaintext
    )
  ) { client in
    let greeter = Greeter_Greeter.Client(wrapping: client)
    let reply = try await greeter.sayHello(.with { $0.name = "taro" })
    return reply.message
  }
}

func testServerStream() -> AsyncThrowingStream<String, Error> {
  AsyncThrowingStream { continuation in
    let task = Task {
      do {
        try await withGRPCClient(
          transport: .http2NIOPosix(
            target: .dns(host: "localhost", port: 50051),
            transportSecurity: .plaintext
          )
        ) { client in
          let greeter = Greeter_Greeter.Client(wrapping: client)
          try await greeter.sayHelloAgain(.with { $0.name = "taro" }) { response in
            for try await reply in response.messages {
              continuation.yield(reply.message)
            }
          }
        }
        continuation.finish()
      } catch {
        continuation.finish(throwing: error)
      }
    }
    continuation.onTermination = { _ in task.cancel() }
  }
}

func testClientStream() -> (send: (String) async -> Void, finish: () -> Void, result: Task<String, Error>) {
  let channel = AsyncThrowingChannel<String, Error>()

  let result = Task {
    try await withGRPCClient(
      transport: .http2NIOPosix(
        target: .dns(host: "localhost", port: 50051),
        transportSecurity: .plaintext
      )
    ) { client in
      let greeter = Greeter_Greeter.Client(wrapping: client)
      let response = try await greeter.sayHelloToMany { writer in
        for try await name in channel {
          try await writer.write(.with { $0.name = name })
        }
      }
      return response.message
    }
  }

  return (
    send: { name in await channel.send(name) },
    finish: { channel.finish() },
    result: result
  )
}
