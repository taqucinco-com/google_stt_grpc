//
//  PCMBufferSerializerNode.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio
import Foundation

/// AVAudioPCMBuffer(Int16, interleaved)をDataへ変換するだけの責務を持つ。
nonisolated final class PCMBufferSerializerNode: AudioPipelineNode {
  var onOutput: ((Data) -> Void)?

  func process(_ input: AVAudioPCMBuffer) {
    guard let channelData = input.int16ChannelData else { return }
    let byteCount = Int(input.frameLength) * MemoryLayout<Int16>.size
    onOutput?(Data(bytes: channelData[0], count: byteCount))
  }
}
