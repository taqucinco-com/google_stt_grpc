## gRPC

### Dockerでサーバーを起動する

```bash
$ docker compose up -d --build
$ docker compose logs grpc --no-log-prefix --tail 20
# "server listening at [::]:50051" が出ていればOK
```

停止する場合:

```bash
$ docker compose down
```

### greeter.Greeterで確認

サーバーはreflectionを有効にしているので、`grpc/helloworld/helloworld.proto`
を手元に持っていなくても`grpcurl`だけでサービス一覧・呼び出しができる。

```bash
$ brew install grpcurl

# サービス一覧
$ grpcurl -plaintext localhost:50051 list

# greeter.Greeterが持つメソッド一覧
$ grpcurl -plaintext localhost:50051 list greeter.Greeter
```

出力例(そのままシェルに貼り付けないこと。以下はコマンドの実行結果であって
コマンドではない):

```
greeter.Greeter
grpc.reflection.v1.ServerReflection
grpc.reflection.v1alpha.ServerReflection

greeter.Greeter.SayChat
greeter.Greeter.SayHello
greeter.Greeter.SayHelloAgain
greeter.Greeter.SayHelloToMany
```

#### SayHello (unary)

```bash
grpcurl -plaintext -d '{"name": "taro"}' localhost:50051 greeter.Greeter.SayHello
```

出力例:

```
{
  "message": "Hello taro"
}
```

#### SayHelloAgain (server streaming)

```bash
grpcurl -plaintext -d '{"name": "taro"}' localhost:50051 greeter.Greeter.SayHelloAgain
```

出力例:

```
{
  "message": "Hello taro"
}
{
  "message": "Hello taro"
}
```

#### SayHelloToMany (client streaming)

`echo -e '...\n...' | grpcurl -d @ ...`だと標準入力をまとめて渡しているように見えて、
クライアントが複数回に分けて送っていることが伝わりにくい。`grpcurl`は標準入力を
逐次読みながら送るので、間に`sleep`を挟むと送信タイミングがずれていることが
サーバー側のログ(タイムスタンプ)で確認できる:

```bash
(echo '{"name": "taro"}'; sleep 1; echo '{"name": "hanako"}') \
    | grpcurl -d @ -plaintext localhost:50051 greeter.Greeter.SayHelloToMany
```

出力例:

```
{
  "message": "Hello! taro, hanako"
}
```

サーバー側のログで、1秒後に届いていることを確認できる:

```bash
$ docker compose logs grpc --no-log-prefix --tail 4
```

#### SayChat (bidirectional streaming)

```bash
$ (echo '{"name": "taro"}'; sleep 1; echo '{"name": "hanako"}') \
    | grpcurl -d @ -plaintext localhost:50051 greeter.Greeter.SayChat
```

出力例:

```
{
  "message": "Hello taro"
}
{
  "message": "Hello hanako"
}
```

サーバー側のログでも、1秒後に2件目を受信していることを確認できる:

```bash
$ docker compose logs grpc --no-log-prefix --tail 4
```

出力例:

```
2026/09/22 11:48:38 Open SayChat
2026/09/22 11:48:38 Received SayChat: taro
2026/09/22 11:48:39 Received SayChat: hanako   # 1秒後に届いている
2026/09/22 11:48:39 Closed SayChat
```

## iOS

https://www.swift.org/blog/grpc-swift-2/

### 前提条件

grpc-swift 2は **Swift tools version 6.1 / iOS 18.0以降** が必須(`gRPCSwift`の
availability macroが`iOS 18.0`以上で定義されているため)。
[google_stt_grpc.xcodeproj](iOS/google_stt_grpc/google_stt_grpc.xcodeproj) の
Deployment TargetがiOS 18以上か、Xcodeが16.3以降かを先に確認する。

### 1. SPMで依存関係を追加する

Xcode: `File > Add Package Dependencies...` で以下3つを追加する。

| Package URL | 使うProduct |
|---|---|
| `https://github.com/grpc/grpc-swift-2.git` (from 2.0.0) | `GRPCCore` |
| `https://github.com/grpc/grpc-swift-nio-transport.git` (from 2.0.0) | `GRPCNIOTransportHTTP2` |
| `https://github.com/grpc/grpc-swift-protobuf.git` (from 2.4.0) | `GRPCProtobuf`(ライブラリ)+ `GRPCProtobufGenerator`(plugin) |

パッケージ追加時に各Productの "Add to Target" を選ぶ表が出るので、
`GRPCCore` / `GRPCNIOTransportHTTP2` / `GRPCProtobuf` / `GRPCProtobufGenerator`
の**すべてを`google_stt_grpc`ターゲットに設定する(`None`のままにしない)**。
ライブラリ製品を`None`のままにするとimportがコンパイルエラーになる。
pluginの`GRPCProtobufGenerator`もここでターゲットを設定しておくと、Xcodeが
自動で「Run Build Tool Plug-ins」フェーズをチェック済みで追加してくれるため、
手順2-3の手動追加が不要になる(後述の手動手順は、`None`のまま追加してしまった
場合のフォールバック)。

#### フォールバック: `GRPCProtobuf`だけ`None`のまま追加してしまった場合

`grpc-swift-protobuf`のパッケージ参照だけ登録されて、`GRPCProtobuf`(ライブラリ)が
どのターゲットにもリンクされていない状態になることがある(Xcodeのバージョンや
操作タイミングによって、Product選択がスキップされることがある)。その場合は
手動でライブラリを追加する。

1. プロジェクト選択 → `google_stt_grpc`ターゲット → `General`タブ →
   `Frameworks, Libraries, and Embedded Content` → `+`
2. 検索欄で「grpc-swift-protobuf」または「GRPCProtobuf」を探して追加
   (すでにパッケージ参照は登録済みなので一覧に出てくるはず)

pluginの`GRPCProtobufGenerator`のフォールバックは手順2-3を参照。

### 2. protoからのコード生成(build plugin方式)

アプリ(他パッケージから依存されないもの)には、ビルド時に自動生成される
build plugin方式が推奨されている(生成物のコミットは不要)。Goサーバー側は
生成物をコミットする方針だが、iOS側はplugin方式で毎回自動生成する。

1. `grpc/helloworld/helloworld.proto` と同じ内容のファイルを、Xcodeプロジェクト内
   (例: `google_stt_grpc/Protos/helloworld.proto`)に追加。"Add to target:
   google_stt_grpc" にチェックする。
2. 同じフォルダに、名前が固定の `grpc-swift-proto-generator-config.json`
   を追加(これも対象ターゲットに含める):
   ```json
   {
     "generate": { "clients": true, "servers": true, "messages": true }
   }
   ```
3. (フォールバック)手順1でpluginのターゲットを`None`のまま追加してしまった場合は、
   ターゲットの `Build Phases` タブを開き、一覧に最初から存在する
   **`Run Build Tool Plug-ins`** という専用セクションを探す(上部の`+`で新規作成
   するものではない)。まだ何も追加していなければ
   `No build tool plug-ins were found in any of this target's package
   dependencies.` という空状態のメッセージが出ているので、そのセクションの
   **`Choose package plug-ins`** をクリックし、一覧から`GRPCProtobufGenerator`
   にチェックを入れる。
4. 一度ビルドすると、Xcodeが「信頼されていないビルドツールプラグインを実行しよう
   としています」というダイアログを出すので **Trust & Enable** を選択する
   (しないと毎回スキップされる)。

`protoc`をローカルにインストールしていなくても(`grpc-swift-protobuf`が同梱する
protocを使うため)、ビルドのたびに以下のSwift型が自動生成される:

- サービス: `Greeter_Greeter`(protoの`package greeter` + `service Greeter` →
  `{Package}_{Service}`という命名規則。クライアントは`Greeter_Greeter.Client`)
- メッセージ: `Greeter_HelloRequest`, `Greeter_HelloResponse`

### 3. ローカル通信の許可(ATS)

iOSはデフォルトで平文(TLSなし)通信をブロックする。`localhost:50051`へ
`grpcurl -plaintext`相当の接続をするには、`Info.plist`に以下を追加する:

```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsLocalNetworking</key>
    <true/>
</dict>
```

`NSAllowsLocalNetworking`は`localhost`/ループバックアドレス宛だけを許可する
限定的なキーなので、`NSAllowsArbitraryLoads`のような広い穴を開けずに済む。

Simulatorなら`localhost`はMac自身を指すのでそのまま動く。実機で試す場合は
MacのLAN IPに変える必要があり、さらにiOS 14以降のローカルネットワークアクセス
許可(`NSLocalNetworkUsageDescription`)も必要になる。

### 4. 書くべきコードの形

ボタンタップでunary RPCを呼び、結果をdebug consoleに`print`する場合の骨組み:

```swift
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf

// Button(...) { action: ... } の中身のイメージ
Task {
    try await withGRPCClient(
        transport: .http2NIOPosix(
            target: .dns(host: "localhost", port: 50051),
            transportSecurity: .plaintext
        )
    ) { client in
        let greeter = Greeter_Greeter.Client(wrapping: client)
        let reply = try await greeter.sayHello(.with { $0.name = "taro" })
        print(reply.message)   // ここがdebug consoleに出る
    }
}
```

ポイント:
- SwiftUIの`Button`の`action`クロージャは同期関数なので、非同期の
  `withGRPCClient`は`Task { }`で包む必要がある。
- `withGRPCClient(transport:_:)`はクライアントの生成〜クローズまでを1つの
  クロージャで面倒見る設計なので、毎回接続を張って閉じる形になる。何度も
  ボタンを押す想定なら、クライアントを`@State`や`@Observable`のクラスで
  保持して使い回す設計に後で発展させると良い。
- エラーは`try`が伝播するので、まずは`try?`にするかdo/catchで
  `print(error)`しておくとデバッグしやすい。

### 確認の流れ

1. `docker compose up -d --build` でGoサーバーを起動
2. iOSアプリをSimulatorでビルド・実行してボタンをタップ
3. Xcodeのdebug consoleに`Hello taro`のようなメッセージが出れば成功
