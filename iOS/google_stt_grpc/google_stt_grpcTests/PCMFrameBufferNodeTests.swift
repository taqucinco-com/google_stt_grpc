//
//  PCMFrameBufferNodeTests.swift
//  google_stt_grpcTests
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio
import Testing
@testable import google_stt_grpc

struct PCMFrameBufferNodeTests {
  private let sampleRate = 48000.0

  @Test func reshapesContinuousSineWaveIntoExactFrameLengths() throws {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
    let node = PCMFrameBufferNode(format: format, frameDurationMs: 20)  // 960サンプル/フレーム

    var emitted: [AVAudioPCMBuffer] = []
    node.onOutput = { emitted.append($0) }

    // 440Hzのサイン波を、フレーム長(960)の倍数にならない1440サンプルずつ2回に分けて流す。
    let chunkFrameLength: AVAudioFrameCount = 1440
    for chunkIndex in 0..<2 {
      let input = SineWaveFixture.makeBuffer(
        format: format,
        frameLength: chunkFrameLength,
        startSampleIndex: Int(chunkFrameLength) * chunkIndex,
        frequency: 440,
        sampleRate: sampleRate
      )
      node.process(input)
    }

    // 1440 * 2 = 2880 = 960 * 3。端数なくちょうど3フレーム出るはず。
    #expect(emitted.count == 3)
    for buffer in emitted {
      #expect(buffer.frameLength == 960)
    }

    // 連結した出力が、途切れなく連続したサイン波と一致することを確認する
    // (バッファ境界をまたいでもサンプルの欠落・重複・順序崩れがないことの検証)。
    let actual = emitted.flatMap { buffer -> [Float] in
      let ptr = buffer.floatChannelData![0]
      return (0..<Int(buffer.frameLength)).map { ptr[$0] }
    }
    let expected = (0..<2880).map { i in
      Float(sin(2 * Double.pi * 440 * Double(i) / sampleRate))
    }
    #expect(actual.count == expected.count)
    for (a, e) in zip(actual, expected) {
      #expect(abs(a - e) < 0.0001)
    }
  }

  @Test func doesNotEmitUntilOneFullFrameIsAccumulated() throws {
    let format = try #require(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
    let node = PCMFrameBufferNode(format: format, frameDurationMs: 20)  // 960サンプル/フレーム

    var emitted: [AVAudioPCMBuffer] = []
    node.onOutput = { emitted.append($0) }

    // 960未満(500サンプル)しか渡していないので、まだ1フレーム分溜まっていない。
    let input = SineWaveFixture.makeBuffer(
      format: format, frameLength: 500, startSampleIndex: 0, frequency: 440, sampleRate: sampleRate
    )
    node.process(input)

    #expect(emitted.isEmpty)
  }
}
