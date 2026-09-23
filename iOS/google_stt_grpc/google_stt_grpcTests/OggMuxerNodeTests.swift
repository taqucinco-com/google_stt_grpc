//
//  OggMuxerNodeTests.swift
//  google_stt_grpcTests
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio
import Testing
@testable import google_stt_grpc

struct OggMuxerNodeTests {
  private let sampleRate = 48000.0
  private let frameDurationMs = 20.0

  @Test func muxesRealOpusPacketsFromSineWaveIntoWellFormedOggPages() throws {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
    let encoder = try #require(OpusEncoderNode(inputFormat: format, frameDurationMs: frameDurationMs))

    var packets: [AVAudioCompressedBuffer] = []
    encoder.onOutput = { packets.append($0) }

    let frameLength = AVAudioFrameCount(sampleRate * frameDurationMs / 1000)
    for chunkIndex in 0..<3 {
      let input = SineWaveFixture.makeBuffer(
        format: format,
        frameLength: frameLength,
        startSampleIndex: Int(frameLength) * chunkIndex,
        frequency: 440,
        sampleRate: sampleRate
      )
      encoder.process(input)
    }
    #expect(packets.count == 3)

    let muxer = OggMuxerNode(sampleRate: sampleRate, frameDurationMs: frameDurationMs)
    var pages: [Data] = []
    muxer.onOutput = { pages.append($0) }
    for packet in packets {
      muxer.process(packet)
    }

    // OpusHead + OpusTags + 音声ページ3枚
    #expect(pages.count == 5)

    for page in pages {
      #expect(page.count >= 27)
      #expect(String(bytes: page.prefix(4), encoding: .ascii) == "OggS")
    }

    #expect(pages[0][5] == 0x02)  // 先頭ページはBOS
    for page in pages[1...] {
      #expect(page[5] == 0x00)
    }

    // ページ番号(page_sequence_number, offset 18-21)が0から連番になっていること
    for (index, page) in pages.enumerated() {
      let pageSeq = readUInt32LE(page, offset: 18)
      #expect(pageSeq == UInt32(index))
    }

    // granule position(offset 6-13)が音声ページごとに960ずつ増えていくこと
    let granulePositions = pages[2...].map { readInt64LE($0, offset: 6) }
    #expect(granulePositions == [960, 1920, 2880])

    // 全ページのCRC(offset 22-25)が自己整合していることを確認する
    // (production側のCRC実装はprivateなので、検証用に同一のアルゴリズムをここで独立に実装する)。
    for page in pages {
      var zeroed = page
      zeroed.replaceSubrange(22..<26, with: [0, 0, 0, 0])
      #expect(oggCRC32(zeroed) == readUInt32LE(page, offset: 22))
    }
  }

  // MARK: - 検証用ヘルパー(production側のOggMuxerNode実装とは独立)

  private func readUInt32LE(_ data: Data, offset: Int) -> UInt32 {
    data.subdata(in: offset..<(offset + 4)).withUnsafeBytes { $0.load(as: UInt32.self) }.littleEndian
  }

  private func readInt64LE(_ data: Data, offset: Int) -> Int64 {
    data.subdata(in: offset..<(offset + 8)).withUnsafeBytes { $0.load(as: Int64.self) }.littleEndian
  }

  private func oggCRC32(_ data: Data) -> UInt32 {
    let table: [UInt32] = (0..<256).map { i -> UInt32 in
      var crc = UInt32(i) << 24
      for _ in 0..<8 {
        crc = (crc & 0x80000000 != 0) ? (crc << 1) ^ 0x04c11db7 : crc << 1
      }
      return crc
    }
    var crc: UInt32 = 0
    for byte in data {
      crc = (crc << 8) ^ table[Int((crc >> 24) ^ UInt32(byte)) & 0xff]
    }
    return crc
  }
}
