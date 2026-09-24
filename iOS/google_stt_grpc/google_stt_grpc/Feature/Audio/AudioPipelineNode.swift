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
///
/// `process`はCoreAudioのリアルタイムオーディオスレッドから同期的に呼ばれる
/// 前提のため、契約全体を`nonisolated`にしている(MainActorへホップすると
/// リアルタイム処理の同期性・低レイテンシが崩れるため)。準拠する各クラスも
/// `nonisolated`にする必要がある。
protocol AudioPipelineNode: AnyObject {
  associatedtype Input
  associatedtype Output
  nonisolated var onOutput: ((Output) -> Void)? { get set }
  nonisolated func process(_ input: Input)
}

extension AudioPipelineNode {
  /// 次段ノードの`process`を`onOutput`として接続する。パイプラインは常に
  /// 一直線(循環しない)なので、`next`は強参照で保持する。これにより
  /// 呼び出し側は先頭ノードだけを保持すればチェーン全体が生存し続ける
  /// (中間ノードを個別に強参照し続ける必要がない)。
  @discardableResult
  nonisolated func connect<Next: AudioPipelineNode>(to next: Next) -> Next where Next.Input == Output {
    onOutput = { output in next.process(output) }
    return next
  }
}
