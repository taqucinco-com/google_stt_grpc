//
//  AudioPipelineNode.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import Foundation

/// 音声処理パイプラインの1ノードが満たす契約(AudioUnitのnode接続を参考にした設計)。
/// 入力を`process(_:)`で受け取り、出力があれば`onOutput`へ0回以上push する。
/// `onOutput`は接続時に1回だけ設定し、呼び出し側は`process`の都度これを
/// 意識する必要がない(コールバックのネストを避けるため)。
protocol AudioPipelineNode: AnyObject {
  associatedtype Input
  associatedtype Output
  var onOutput: ((Output) -> Void)? { get set }
  func process(_ input: Input)
}

extension AudioPipelineNode {
  /// 次段ノードの`process`を`onOutput`として接続する。
  @discardableResult
  func connect<Next: AudioPipelineNode>(to next: Next) -> Next where Next.Input == Output {
    onOutput = { [weak next] output in next?.process(output) }
    return next
  }
}
