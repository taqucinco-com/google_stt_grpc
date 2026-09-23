//
//  AudioRecorder.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio
import Foundation

/// AVAudioEngineでマイク入力をバッファリングするだけの責務を持つ。
/// `start(onBuffer:)`の引数として呼び出し側に委譲する。
final class AudioRecorder {
  private let engine = AVAudioEngine()
  private(set) var isRecording = false

  /// - Parameter onBuffer: マイク入力バッファを受け取るたびに呼ばれるコールバック。
  func start(onBuffer: @escaping (AVAudioPCMBuffer) -> Void) async throws {
    guard !isRecording else { return }

    guard await AVAudioApplication.requestRecordPermission() else {
      throw AudioRecorderError.permissionDenied
    }

    let session = AVAudioSession.sharedInstance()
    try session.setCategory(.record, mode: .measurement)
    try session.setActive(true)

    let inputNode = engine.inputNode
    let format = inputNode.outputFormat(forBus: 0)
    inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
      onBuffer(buffer)
    }

    engine.prepare()
    try engine.start()
    isRecording = true
  }

  func stop() {
    guard isRecording else { return }
    engine.inputNode.removeTap(onBus: 0)
    engine.stop()
    try? AVAudioSession.sharedInstance().setActive(false)
    isRecording = false
  }
}

enum AudioRecorderError: Error {
  case permissionDenied
}
