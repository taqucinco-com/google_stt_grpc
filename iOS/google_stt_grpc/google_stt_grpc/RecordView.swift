//
//  RecordView.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio
import SwiftUI

struct RecordView: View {
  @State private var recorder = AudioRecorder()
  @State private var isRecording = false
  @State private var errorMessage: String?
  @State private var volumeInDB: Float = -.infinity
  @State private var volumeContinuation: AsyncStream<Float>.Continuation?
  @State private var volumeTask: Task<Void, Never>?
  @State private var transcript = ""
  @State private var audioFinish: (() -> Void)?
  @State private var transcriptTask: Task<Void, Never>?

  var body: some View {
    VStack(spacing: 20) {
      Text(isRecording ? "録音中" : "停止中")
      Text(volumeText)
      Text(transcript.isEmpty ? "認識結果: -" : "認識結果: \(transcript)")
      Button(isRecording ? "録音を停止" : "録音を開始") {
        if isRecording {
          recorder.stop()
          isRecording = false
          volumeContinuation?.finish()
          volumeContinuation = nil
          volumeTask?.cancel()
          volumeTask = nil
          audioFinish?()
          audioFinish = nil
          transcriptTask?.cancel()
          transcriptTask = nil
        } else {
          Task {
            do {
              let (stream, continuation) = AsyncStream<Float>.makeStream()
              volumeContinuation = continuation
              volumeTask = Task { @MainActor in
                for await volume in stream {
                  volumeInDB = volume
                }
              }

              let speechStream = testSpeechStream()
              audioFinish = speechStream.finish
              transcript = ""
              transcriptTask = Task {
                do {
                  for try await result in speechStream.result {
                    transcript = result
                  }
                } catch {
                  print("StreamingRecognize error: \(error)")
                }
              }

              let serializer = PCMBufferSerializer()
              serializer.onOutput = { data in speechStream.send(data) }

              var converter: PCMFormatConverter?
              try await recorder.start { buffer in
                continuation.yield(AudioLevel.dBFS(of: buffer))

                if converter == nil {
                  let newConverter = PCMFormatConverter(inputFormat: buffer.format)
                  newConverter?.connect(to: serializer)
                  converter = newConverter
                }
                converter?.process(buffer)
              }
              isRecording = true
            } catch {
              errorMessage = "\(error)"
            }
          }
        }
      }
      if let errorMessage {
        Text(errorMessage)
          .foregroundStyle(.red)
      }
    }
    .padding()
  }

  private var volumeText: String {
    guard volumeInDB.isFinite else { return "音量: -- dB" }
    return String(format: "音量: %.1f dB", max(volumeInDB, -80))
  }
}

#Preview {
  RecordView()
}
