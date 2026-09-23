//
//  OpusEncoderNode.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio
import Foundation

/// AVAudioPCMBufferをOpus(生パケット、Oggコンテナ化前)のAVAudioCompressedBufferに
/// 変換するだけの責務を持つ。AVAudioConverter + kAudioFormatOpus(iOS 11〜、
/// AVFoundationのみで完結する)を使う。入力は1フレーム分ぴったりのAVAudioPCMBuffer
/// である必要がある(PCMFrameBufferNodeの出力を受け取る前提)。バイト列(Data)化は
/// 行わない(OggMuxerNodeの責務)。
final class OpusEncoderNode: AudioPipelineNode {
  var onOutput: ((AVAudioCompressedBuffer) -> Void)?
  private let converter: AVAudioConverter
  private let outputFormat: AVAudioFormat

  /// - Parameters:
  ///   - inputFormat: 入力PCMのフォーマット(PCMFrameBufferNodeと同じものを渡す)。
  ///   - frameDurationMs: 1フレームの長さ(ms)。PCMFrameBufferNodeと必ず一致させる。
  ///   - bitRate: エンコードビットレート(bps)。
  init?(inputFormat: AVAudioFormat, frameDurationMs: Double = 20, bitRate: Int = 24000) {
    var opusDesc = AudioStreamBasicDescription()
    opusDesc.mSampleRate = 48000
    opusDesc.mFormatID = kAudioFormatOpus
    opusDesc.mChannelsPerFrame = 1
    opusDesc.mFramesPerPacket = UInt32(48000 * frameDurationMs / 1000)
    guard let outputFormat = AVAudioFormat(streamDescription: &opusDesc) else { return nil }
    guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else { return nil }
    converter.bitRate = bitRate
    converter.bitRateStrategy = AVAudioBitRateStrategy_Constant
    self.converter = converter
    self.outputFormat = outputFormat
  }

  func process(_ input: AVAudioPCMBuffer) {
    let compressedBuffer = AVAudioCompressedBuffer(
      format: outputFormat,
      packetCapacity: 1,
      maximumPacketSize: converter.maximumOutputPacketSize
    )

    var didProvideInput = false
    var conversionError: NSError?
    let status = converter.convert(to: compressedBuffer, error: &conversionError) { _, outStatus in
      if didProvideInput {
        outStatus.pointee = .noDataNow
        return nil
      }
      didProvideInput = true
      outStatus.pointee = .haveData
      return input
    }

    guard status == .haveData, conversionError == nil else { return }
    onOutput?(compressedBuffer)
  }
}
