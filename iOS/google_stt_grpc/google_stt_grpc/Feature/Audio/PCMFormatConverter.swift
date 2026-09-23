//
//  PCMFormatConverter.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio
import Foundation

/// AVAudioPCMBuffer(ネイティブフォーマット)を、Google STTが要求する
/// LINEAR16(16bit signed PCM, 16kHz, mono)のDataに変換するだけの責務を持つ。
final class PCMFormatConverter {
  private let converter: AVAudioConverter
  let outputFormat: AVAudioFormat

  init?(inputFormat: AVAudioFormat) {
    guard let outputFormat = AVAudioFormat(
      commonFormat: .pcmFormatInt16,
      sampleRate: 16000,
      channels: 1,
      interleaved: true
    ) else { return nil }
    guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { return nil }
    self.converter = converter
    self.outputFormat = outputFormat
  }

  func convert(_ buffer: AVAudioPCMBuffer) -> Data? {
    let ratio = outputFormat.sampleRate / buffer.format.sampleRate
    let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
    guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputFrameCapacity) else {
      return nil
    }

    var didProvideInput = false
    var conversionError: NSError?
    converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
      if didProvideInput {
        outStatus.pointee = .noDataNow
        return nil
      }
      didProvideInput = true
      outStatus.pointee = .haveData
      return buffer
    }

    guard conversionError == nil, let channelData = outputBuffer.int16ChannelData else { return nil }
    let byteCount = Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
    return Data(bytes: channelData[0], count: byteCount)
  }
}
