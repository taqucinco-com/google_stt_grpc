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

## Google Cloud Speech-to-Text (STT) gRPC API

Step 3(非圧縮データ送信・OPUS対応)の実装前に調べた、STTのgRPC streaming API
の仕様。実装時にここを見返す用のメモ。

### サービス定義

`google.cloud.speech.v1.Speech`サービスの`StreamingRecognize`が
bidirectional streaming RPC。

```protobuf
rpc StreamingRecognize(stream StreamingRecognizeRequest)
    returns (stream StreamingRecognizeResponse) {}
```

これまで実装した`Greeter.SayChat`と同じ形(bidi streaming)なので、
clientの実装パターンはそのまま流用できる見込み。

### メッセージフロー(重要な制約)

```protobuf
message StreamingRecognizeRequest {
  oneof streaming_request {
    StreamingRecognitionConfig streaming_config = 1;
    bytes audio_content = 2;
  }
}
```

- **最初の1通目**: `streaming_config`のみを送る(`audio_content`は含めない)
- **2通目以降**: `audio_content`のみを送る(生バイト列。base64ではない)

`SayChat`にはなかった非対称なプロトコルなので、実装時に明示的に意識する必要がある。

### RecognitionConfigの主要フィールド

```protobuf
message RecognitionConfig {
  AudioEncoding encoding = 1;
  int32 sample_rate_hertz = 2;      // 8000〜48000。16000が最適
  string language_code = 3;          // 必須。例: "ja-JP"
  ...
}
```

### AudioEncoding(Step 3/4に直結)

```protobuf
enum AudioEncoding {
  ENCODING_UNSPECIFIED = 0;
  LINEAR16 = 1;   // 非圧縮16bit signed PCM ← Step 3で使う
  FLAC = 2;
  OGG_OPUS = 6;   // ← Step 4のOPUS検証で使う。8000/12000/16000/24000/48000Hz対応
  WEBM_OPUS = 9;
  ...
}
```

[AudioRecorder](iOS/google_stt_grpc/google_stt_grpc/Feature/Audio/AudioRecorder.swift)が
現状ネイティブフォーマット(Float32)でバッファを取得しているので、Step 3では
`AVAudioConverter`で**16bit signed little-endian PCM / 16000Hz**に変換してから
送る必要がある(公式サンプルもこの組み合わせを使用)。

### エンドポイント・認証

- エンドポイント: `speech.googleapis.com:443`(TLS)
- 認証: gRPCのメタデータに`authorization: Bearer <アクセストークン>`を付与する
  (サービスアカウントの認証情報からOAuth2トークンを生成)。これまでの`grpc/`
  サーバーは`-plaintext`かつ認証なしだったので、Step 3ではTLS接続+認証ヘッダーの
  実装が新たに必要になる。

#### APIキーは使えるか

**単体では使えない見込み**。Google Cloudの認証ドキュメントによると

> 標準のAPIキーはプリンシパル(principal)を認証しない。プリンシパルがないと、
> 呼び出し元が要求された操作を行う権限があるかをIAMでチェックできない

とあり、APIキーは「どのプロジェクトからの呼び出しか」を識別するだけで、
IAMの権限チェックが必要なSpeech-to-Textを単独では認可できない。
Speech-to-Text v1の公式認証ドキュメントにもAPIキーによる認証経路の記載は
一切なく、ADC/サービスアカウント/OAuth2 Bearerトークンのみが案内されている。
gRPCメタデータに`x-api-key`/`x-goog-api-key`としてAPIキーを渡す非公式な
試みも見られるが、動作報告は不安定(Broken Pipeで失敗した例もある)。

REST版の`speech:recognize`(unary、ファイル全体を投げる方式)には歴史的に
`?key=API_KEY`のクイックスタートがあるが、Step 3で使う`StreamingRecognize`は
gRPC限定のbidirectional streamingであり、この経路は使えない。
→ 発行したAPIキーはREST版での簡易疎通確認に使い、iOSアプリからのgRPC
streaming実装ではサービスアカウント+OAuth2 Bearerトークン方式を使う。

### 制限事項

- ストリーミングリクエスト1通あたり10MBの上限
- 1ストリームは数分程度で切れる(公式サンプルは60秒〜4-5分でストリーム再接続する
  ロジックを紹介)ため、長時間録音する場合は再接続処理が必要

### バージョンについて

v1・v1p1beta1に加えて、より新しいv2 APIも存在する(リージョナルエンドポイント
`<region>-speech.googleapis.com`を使う点が異なる)。既存の`grpc/`実装との
対称性やシンプルさを考えるとv1から始めるのが妥当。

### 参考ドキュメント

- [Package google.cloud.speech.v1 proto (googleapis/googleapis)](https://github.com/googleapis/googleapis/blob/master/google/cloud/speech/v1/cloud_speech.proto)
- [Transcribe audio from streaming input | Cloud Speech-to-Text](https://docs.cloud.google.com/speech-to-text/docs/v1/transcribe-streaming-audio)
- [Package google.cloud.speech.v2 | Cloud Speech-to-Text](https://docs.cloud.google.com/speech-to-text/docs/reference/rpc/google.cloud.speech.v2)
- [gRPC Authentication guide](https://grpc.io/docs/guides/auth/)

## 認証トークン発行サーバー(`hono/`)

Step 3でiOSアプリからGoogle STTのgRPCへ直接繋ぐには、
`authorization: Bearer <アクセストークン>`が必要になる(前掲の
「エンドポイント・認証」参照)。しかしこのアクセストークンはサービスアカウントの
秘密鍵から発行するものであり、Googleの公式ベストプラクティスは以下を明言している。

> クライアントサイドのアプリケーション(ツール、デスクトッププログラム、
> モバイルアプリなど)では、サービスアカウントを使用しないでください

秘密鍵をモバイルアプリのバイナリに同梱するとリバースエンジニアリングで
抽出されうるため、モバイルアプリ単体でアクセストークンを安全に得る方法は
存在しない。そのため、以下の方針を採用する。

### 採用した方式

サービスアカウントの秘密鍵はサーバー側だけが持ち、**アクセストークンの発行のみ**
を代行する軽量なバックエンドを新設する(iOSからGoogle STTへの通信そのものを
中継する「フルプロキシ」方式は今回は採用しない。iOSは発行されたトークンを使って
`speech.googleapis.com`と直接gRPCで話す)。

- ディレクトリ: リポジトリルート直下に`hono/`(`grpc/`・`iOS/`と並ぶ構成)
- フレームワーク: [Hono](https://hono.dev/)。Nest.jsも候補に挙がったが、
  この責務は「サービスアカウントの認証情報から`google-auth-library`で
  アクセストークンを発行してJSONで返す」という単一エンドポイントのみであり、
  DI・モジュールを前提としたNest.jsの構成を組むほどの規模ではないため、
  薄いルーティング層のみのHonoを選定した。
- 起動方法: Dockerで起動し、ローカル環境でも`docker compose up`で
  `grpc`サービスと一緒に立ち上げられる(`docker-compose.yml`に`grpc`と
  並ぶ形で`hono`サービスを追加済み)。
- 秘密鍵の扱い: サービスアカウントの認証情報は`.env`経由で渡し、リポジトリには
  コミットしない(AGENTS.mdの「注意事項」を参照)。

### セットアップ手順(scaffold)

[Hono公式のNode.js向けセットアップ](https://hono.dev/docs/getting-started/nodejs)
に従い、リポジトリルートで`create-hono`を使って`hono/`ディレクトリを作成した。
対話プロンプトを避けるため`--template`/`--pm`/`--install`を明示している。

```bash
$ npm create hono@latest hono -- --template nodejs --pm npm --install
```

生成された`hono/src/index.ts`のデフォルト実装(`GET /`で`"Hello Hono!"`を
返すだけ)に対して、以下の2点だけ変更した。

- ポートを`3000`→`8787`に変更(Dockerの`ports`設定・後述の動作確認と合わせるため)
- レスポンス文言を`"hello, hono!"`に変更(まずは疎通確認用)

### Dockerで起動する

```bash
$ docker compose up -d --build hono
$ docker compose logs hono --no-log-prefix --tail 10
```

出力例(そのままシェルに貼り付けないこと。以下はコマンドの実行結果であって
コマンドではない):

```
> dev
> tsx watch src/index.ts

Server is running on http://localhost:8787
```

### 動作確認

```bash
$ curl -s http://localhost:8787/
```

出力例:

```
hello, hono!
```

停止する場合:

```bash
$ docker compose down
```

### `/token`エンドポイント

[google-auth-library](https://github.com/googleapis/google-auth-library-nodejs)の
`GoogleAuth`を使い、`GET /token`でGoogle STT用のアクセストークンを発行する
(`{"access_token": "...", "expires_in": 3599}`をJSONで返す。認証情報が
読めない場合は500)。

```ts
const auth = new GoogleAuth({
  scopes: ['https://www.googleapis.com/auth/cloud-platform'],
})

app.get('/token', async (c) => {
  const client = await auth.getClient()
  const { token } = await client.getAccessToken()
  // getAccessToken()自体はtokenしか返さないため、有効期限は
  // 副作用で更新されるclient.credentials.expiry_date(epoch ms)から算出する。
  const expiryDate = client.credentials.expiry_date
  const expiresIn = expiryDate ? Math.floor((expiryDate - Date.now()) / 1000) : null
  return c.json({ access_token: token, expires_in: expiresIn })
})
```

#### トークンの生存期間

Googleのサービスアカウントアクセストークンはデフォルトで**最大1時間
(3600秒)**が有効期限。実際に発行して確認したところ`expires_in: 3599`
(≒3600秒)だった。組織ポリシー
(`constraints/iam.allowServiceAccountCredentialLifetimeExtension`)で
最大12時間まで延長可能だが、今回は特に設定していないのでデフォルトの
1時間。iOSアプリ側はこの`expires_in`を見て、期限が近づいたら`/token`を
再度叩き直す実装が必要になる(「未解決事項」参照)。

`GoogleAuth`はADC(Application Default Credentials)の探索順に従い、
`GOOGLE_APPLICATION_CREDENTIALS`環境変数が指すJSONキーファイルを読みに行く。
`docker-compose.yml`の`hono`サービスで

```yaml
environment:
  - GOOGLE_APPLICATION_CREDENTIALS=/usr/src/app/secrets/service-account.json
```

と設定済み。`./hono:/usr/src/app`を丸ごとbind mountしているので、
**ホスト側の`hono/secrets/service-account.json`にサービスアカウントの
JSONキーを置くだけ**でコンテナ内から読める(`hono/secrets/`は`.gitkeep`を
除いてgitignore済み)。

#### サービスアカウントの準備手順

1. GCPコンソールでサービスアカウントを作成し、[Speech-to-Text用の
   predefined role](https://docs.cloud.google.com/iam/docs/roles-permissions/speech)
   のうち`roles/speech.client`(呼び出し専用の最小権限ロール)を付与する。
   `roles/speech.admin`・`roles/speech.editor`は管理系操作も含むため不要。
2. そのサービスアカウントのJSONキーを発行し、`hono/secrets/service-account.json`
   として配置する(このファイル自体はコミットしない)。

#### 動作確認(キー未配置の状態)

キーを配置する前に、意図通りエラーになることを確認済み:

```bash
$ curl -s -i http://localhost:8787/token
HTTP/1.1 500 Internal Server Error
{"error":"failed to issue access token"}
```

```bash
$ docker compose logs hono --no-log-prefix --tail 5
Error: Unable to read the credential file specified by the GOOGLE_APPLICATION_CREDENTIALS
environment variable: The file at /usr/src/app/secrets/service-account.json does not
exist, or it is not a file. ENOENT: no such file or directory, ...
```

#### 動作確認(キー配置後)

実際にサービスアカウントを作成し(`roles/speech.client`付与、Speech-to-Text API
有効化)、`hono/secrets/service-account.json`にJSONキーを配置した状態で確認済み:

```bash
$ docker compose up -d --build hono
$ curl -s -o /tmp/token_response.json -w "HTTP %{http_code}\n" http://localhost:8787/token
HTTP 200
```

```json
{"access_token": "ya29.c.c0AZ4...(実際は1024文字程度のトークン)", "expires_in": 3599}
```

`ya29.`で始まる実際のGoogle OAuth2アクセストークンが返ることを確認した
(トークン値そのものは秘匿情報なのでログ・ドキュメントには残さない)。

#### トークンの有効性そのものの確認(Google側のtokeninfoエンドポイント)

`/token`が返した値が「本当にGoogleに通用するトークンか」を、Google自身の
検証エンドポイント[`https://oauth2.googleapis.com/tokeninfo`](https://developers.google.com/identity/protocols/oauth2)
に投げて確認した:

```bash
$ curl -s "https://oauth2.googleapis.com/tokeninfo?access_token=${TOKEN}"
```

```json
{
  "scope": "https://www.googleapis.com/auth/cloud-platform",
  "expires_in": 3599,
  "access_type": "online"
}
```

`HTTP 200`で返り、`scope`が要求した`cloud-platform`と一致、`expires_in`も
`/token`のレスポンスと一致した。これで`hono`が発行しているのは
Google自身が正当と認める本物のアクセストークンであることを確認できた。

### 未解決事項(今後の実装で詰める)

- iOSアプリ側はアクセストークンの有効期限管理・失効時の再取得ロジックを
  自前で持つ必要がある(フルプロキシ方式なら不要だった責務)。
