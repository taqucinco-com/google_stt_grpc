//
//  PCMFormatConverterNode.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio
import Foundation

/// AVAudioPCMBuffer(ネイティブフォーマット)を、Google STTが要求する
/// LINEAR16(16bit signed PCM, 16kHz, mono)のAVAudioPCMBufferに変換するだけの
/// 責務を持つ。バイト列(Data)化は行わない(PCMBufferSerializerNodeの責務)ので、
/// 録音のgRPC送信以外の用途(ファイル書き込み等)にも転用しやすい。
final class PCMFormatConverterNode: AudioPipelineNode {
  private let converter: AVAudioConverter
  let outputFormat: AVAudioFormat
  var onOutput: ((AVAudioPCMBuffer) -> Void)?

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

  func convert(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
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

    guard conversionError == nil else { return nil }
    return outputBuffer
  }

  /// AudioPipelineNode準拠。変換結果を`onOutput`へpushする。
  func process(_ input: AVAudioPCMBuffer) {
    if let output = convert(input) {
      onOutput?(output)
    }
  }
}
