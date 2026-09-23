//
//  OpusEncoderNodeTests.swift
//  google_stt_grpcTests
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio
import Testing
@testable import google_stt_grpc

struct OpusEncoderNodeTests {
  private let sampleRate = 48000.0
  private let frameDurationMs = 20.0

  @Test func encodesExactFrameIntoNonEmptyOpusPacket() throws {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
    let node = try #require(OpusEncoderNode(inputFormat: format, frameDurationMs: frameDurationMs))

    var emitted: [AVAudioCompressedBuffer] = []
    node.onOutput = { emitted.append($0) }

    let frameLength = AVAudioFrameCount(sampleRate * frameDurationMs / 1000)  // 960
    let input = SineWaveFixture.makeBuffer(
      format: format, frameLength: frameLength, startSampleIndex: 0, frequency: 440, sampleRate: sampleRate
    )
    node.process(input)

    #expect(emitted.count == 1)
    let packet = try #require(emitted.first)
    #expect(packet.byteLength > 0)
    #expect(packet.byteLength <= 1275)  // Opusパケットの仕様上の最大サイズ(RFC 6716)
  }

  @Test func roundTripDecodePreservesApproximateFrequency() throws {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
    let encoder = try #require(OpusEncoderNode(inputFormat: format, frameDurationMs: frameDurationMs))

    var packets: [AVAudioCompressedBuffer] = []
    encoder.onOutput = { packets.append($0) }

    let frameLength = AVAudioFrameCount(sampleRate * frameDurationMs / 1000)
    let input = SineWaveFixture.makeBuffer(
      format: format, frameLength: frameLength, startSampleIndex: 0, frequency: 440, sampleRate: sampleRate
    )
    encoder.process(input)
    let packet = try #require(packets.first)

    // OpusEncoderNodeと対になるデコーダをAVAudioConverter + kAudioFormatOpusで
    // 組み立て、エンコード結果を実際にPCMへ復元できること・440Hz付近の周波数が
    // 保たれていることを確認する。packetがAVAudioCompressedBufferのままなので、
    // そのままデコーダの入力として使え、手動でのバイトコピー復元は不要。
    let decoder = try #require(AVAudioConverter(from: packet.format, to: format))

    let outputBuffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameLength))
    var didProvideInput = false
    var conversionError: NSError?
    decoder.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
      if didProvideInput {
        outStatus.pointee = .noDataNow
        return nil
      }
      didProvideInput = true
      outStatus.pointee = .haveData
      return packet
    }
    #expect(conversionError == nil)
    // デコーダ側のプライミング遅延等により、戻ってくるフレーム数は常に
    // ぴったり960になるとは限らない(実測で840になるケースを確認済み)ため、
    // 厳密な長さの一致は求めない。
    #expect(outputBuffer.frameLength > 0)

    // ゼロクロス回数から実際のフレーム長に応じた周波数を推定し、440Hz付近に
    // 収まっているかを確認する(フレーム長に依存しない頑健な検証)。
    let ptr = outputBuffer.floatChannelData![0]
    var zeroCrossings = 0
    for i in 1..<Int(outputBuffer.frameLength) {
      if (ptr[i - 1] < 0) != (ptr[i] < 0) {
        zeroCrossings += 1
      }
    }
    let durationSeconds = Double(outputBuffer.frameLength) / sampleRate
    let estimatedFrequency = Double(zeroCrossings) / 2.0 / durationSeconds
    #expect((300.0...600.0).contains(estimatedFrequency))
  }
}
