//
//  PCMFrameBufferNode.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import AVFAudio

/// 連続したAVAudioPCMBufferを蓄積し、固定フレーム長(例: Opusの20ms)ぴったりの
/// AVAudioPCMBufferに整形してpushするだけの責務を持つ。入力側のバッファ境界
/// (CoreAudioが実際に渡すフレーム数は保証されない)と、出力側が要求する固定
/// フレーム長を分離するためのノード。サンプル型(Int16/Float32)には依存しない。
final class PCMFrameBufferNode: AudioPipelineNode {
  var onOutput: ((AVAudioPCMBuffer) -> Void)?
  private let format: AVAudioFormat
  private let frameCount: AVAudioFrameCount
  private var pending: AVAudioPCMBuffer

  /// - Parameters:
  ///   - format: 入出力のPCMフォーマット(入力もこの形式で来る前提)。
  ///   - frameDurationMs: 1フレームの長さ(ms)。Opusは2.5/5/10/20/40/60のいずれか。
  init(format: AVAudioFormat, frameDurationMs: Double = 20) {
    self.format = format
    frameCount = AVAudioFrameCount(format.sampleRate * frameDurationMs / 1000)
    pending = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
  }

  func process(_ input: AVAudioPCMBuffer) {
    var offset: AVAudioFrameCount = 0
    while offset < input.frameLength {
      let space = frameCount - pending.frameLength
      let count = min(space, input.frameLength - offset)
      copy(from: input, sourceFrameOffset: offset, to: pending, destFrameOffset: pending.frameLength, frameCount: count)
      pending.frameLength += count
      offset += count

      if pending.frameLength == frameCount {
        emit()
      }
    }
  }

  private func emit() {
    guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
    copy(from: pending, sourceFrameOffset: 0, to: output, destFrameOffset: 0, frameCount: frameCount)
    output.frameLength = frameCount
    onOutput?(output)
    pending.frameLength = 0
  }

  /// フレーム単位でチャンネルデータを生バイトのままコピーする(サンプル型に依存しない)。
  private func copy(
    from source: AVAudioPCMBuffer, sourceFrameOffset: AVAudioFrameCount,
    to dest: AVAudioPCMBuffer, destFrameOffset: AVAudioFrameCount,
    frameCount: AVAudioFrameCount
  ) {
    let bytesPerFrame = Int(format.streamDescription.pointee.mBytesPerFrame)
    let srcList = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
    let dstList = UnsafeMutableAudioBufferListPointer(dest.mutableAudioBufferList)
    for channel in 0..<srcList.count {
      guard let srcData = srcList[channel].mData, let dstData = dstList[channel].mData else { continue }
      let srcPtr = srcData.advanced(by: Int(sourceFrameOffset) * bytesPerFrame)
      let dstPtr = dstData.advanced(by: Int(destFrameOffset) * bytesPerFrame)
      dstPtr.copyMemory(from: srcPtr, byteCount: Int(frameCount) * bytesPerFrame)
    }
  }
}
