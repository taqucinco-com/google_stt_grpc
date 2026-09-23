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

  var body: some View {
    VStack(spacing: 20) {
      Text(isRecording ? "録音中" : "停止中")
      Text(volumeText)
      Button(isRecording ? "録音を停止" : "録音を開始") {
        if isRecording {
          recorder.stop()
          isRecording = false
          volumeContinuation?.finish()
          volumeContinuation = nil
          volumeTask?.cancel()
          volumeTask = nil
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
              try await recorder.start { buffer in
                continuation.yield(AudioLevel.dBFS(of: buffer))
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
