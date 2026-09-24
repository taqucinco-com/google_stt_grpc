//
//  OggMuxerNode.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio
import Foundation

/// Opusの生パケット(OpusEncoderNodeの出力、AVAudioCompressedBuffer)を、
/// Google STTが要求するOGG_OPUS(Oggコンテナ)のバイト列に梱包するだけの責務を
/// 持つ。RFC 3533(Ogg)とRFC 7845(Ogg Opus)に基づく最小実装で、単一の論理
/// ストリーム・1パケット1ページのみをサポートする(Opusパケットは常に1275バイト
/// 以下なので複数セグメントにまたがることはない)。EOSフラグの付与は行わない
/// (ストリーミング用途では必須ではないため)。
nonisolated final class OggMuxerNode: AudioPipelineNode {
  var onOutput: ((Data) -> Void)?

  private let serialNumber: UInt32
  private var pageSequenceNumber: UInt32 = 0
  private var granulePosition: Int64 = 0
  private let sampleRate: Double
  private let samplesPerPacket: Int64
  private var didWriteHeaderPages = false

  /// - Parameters:
  ///   - sampleRate: Opusのサンプルレート(Hz)。OpusEncoderNodeと一致させる。
  ///   - frameDurationMs: 1フレームの長さ(ms)。OpusEncoderNodeと一致させる。
  init(sampleRate: Double = 16000, frameDurationMs: Double = 20) {
    serialNumber = UInt32.random(in: UInt32.min...UInt32.max)
    self.sampleRate = sampleRate
    samplesPerPacket = Int64(sampleRate * frameDurationMs / 1000)
  }

  /// AudioPipelineNode準拠。最初の呼び出し時にOpusHead/OpusTagsのページを
  /// 先に送り、続けて音声データのページを送る。
  func process(_ input: AVAudioCompressedBuffer) {
    if !didWriteHeaderPages {
      writeHeaderPages()
      didWriteHeaderPages = true
    }
    let packet = Data(bytes: input.data, count: Int(input.byteLength))
    granulePosition += samplesPerPacket
    onOutput?(makePage(packet: packet, granulePosition: granulePosition, headerType: 0x00))
  }

  private func writeHeaderPages() {
    onOutput?(makePage(packet: makeOpusHead(), granulePosition: 0, headerType: 0x02))  // BOS
    onOutput?(makePage(packet: makeOpusTags(), granulePosition: 0, headerType: 0x00))
  }

  /// RFC 7845 Section 5.1
  private func makeOpusHead() -> Data {
    var data = Data()
    data.append(contentsOf: Array("OpusHead".utf8))
    data.append(1)                          // version
    data.append(1)                          // channel count (mono)
    data.appendLittleEndian(UInt16(0))       // pre-skip
    data.appendLittleEndian(UInt32(sampleRate))  // input sample rate(情報用、デコードには使われない)
    data.appendLittleEndian(Int16(0))        // output gain
    data.append(0)                          // channel mapping family(0 = mono/stereo)
    return data
  }

  /// RFC 7845 Section 5.2
  private func makeOpusTags() -> Data {
    var data = Data()
    data.append(contentsOf: Array("OpusTags".utf8))
    let vendor = Array("google_stt_grpc".utf8)
    data.appendLittleEndian(UInt32(vendor.count))
    data.append(contentsOf: vendor)
    data.appendLittleEndian(UInt32(0))       // user comment list length = 0
    return data
  }

  /// RFC 3533 Section 6(Oggページのフレーミング)。1パケット1ページで作る。
  private func makePage(packet: Data, granulePosition: Int64, headerType: UInt8) -> Data {
    var segments: [UInt8] = []
    var remaining = packet.count
    while remaining >= 255 {
      segments.append(255)
      remaining -= 255
    }
    segments.append(UInt8(remaining))

    var page = Data()
    page.append(contentsOf: Array("OggS".utf8))
    page.append(0)                                  // version
    page.append(headerType)
    page.appendLittleEndian(granulePosition)
    page.appendLittleEndian(serialNumber)
    page.appendLittleEndian(pageSequenceNumber)
    let crcFieldOffset = page.count
    page.appendLittleEndian(UInt32(0))               // CRCは後で埋める
    page.append(UInt8(segments.count))
    page.append(contentsOf: segments)
    page.append(packet)

    pageSequenceNumber += 1

    let crc = Self.oggCRC32(page)
    page.replaceSubrange(crcFieldOffset..<(crcFieldOffset + 4), with: withUnsafeBytes(of: crc.littleEndian) { Data($0) })
    return page
  }

  /// Oggで使われるCRC32(poly 0x04c11db7, 非反転, 初期値0)。zlib等の一般的な
  /// CRC32(反転あり)とは異なるので流用できない。
  private static let crcTable: [UInt32] = {
    (0..<256).map { i -> UInt32 in
      var crc = UInt32(i) << 24
      for _ in 0..<8 {
        crc = (crc & 0x80000000 != 0) ? (crc << 1) ^ 0x04c11db7 : crc << 1
      }
      return crc
    }
  }()

  private static func oggCRC32(_ data: Data) -> UInt32 {
    var crc: UInt32 = 0
    for byte in data {
      crc = (crc << 8) ^ crcTable[Int((crc >> 24) ^ UInt32(byte)) & 0xff]
    }
    return crc
  }
}

extension Data {
  fileprivate nonisolated mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
    var le = value.littleEndian
    Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
  }
}
