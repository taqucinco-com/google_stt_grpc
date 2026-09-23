//
//  SineWaveFixture.swift
//  google_stt_grpcTests
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio

/// テスト用に、指定した周波数のサイン波をAVAudioPCMBufferとして生成する。
enum SineWaveFixture {
  static func makeBuffer(
    format: AVAudioFormat,
    frameLength: AVAudioFrameCount,
    startSampleIndex: Int,
    frequency: Double = 440,
    sampleRate: Double
  ) -> AVAudioPCMBuffer {
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength)!
    buffer.frameLength = frameLength
    let channelData = buffer.floatChannelData![0]
    for i in 0..<Int(frameLength) {
      let sampleIndex = startSampleIndex + i
      channelData[i] = Float(sin(2 * Double.pi * frequency * Double(sampleIndex) / sampleRate))
    }
    return buffer
  }
}
