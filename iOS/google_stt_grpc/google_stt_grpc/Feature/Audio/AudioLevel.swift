//
//  AudioLevel.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio

/// AVAudioPCMBufferから概算音量を算出するユーティリティ。
enum AudioLevel {
  /// バッファのRMSをdBFS(0dBが最大振幅)で返す。無音の場合は`-.infinity`。
  static func dBFS(of buffer: AVAudioPCMBuffer) -> Float {
    guard let channelData = buffer.floatChannelData else { return -.infinity }

    let frameLength = Int(buffer.frameLength)
    let channelCount = Int(buffer.format.channelCount)
    guard frameLength > 0, channelCount > 0 else { return -.infinity }

    var sumOfSquares: Float = 0
    for channel in 0..<channelCount {
      let samples = channelData[channel]
      for frame in 0..<frameLength {
        let sample = samples[frame]
        sumOfSquares += sample * sample
      }
    }

    let rms = sqrt(sumOfSquares / Float(frameLength * channelCount))
    return 20 * log10(rms)
  }
}
