# AGENTS.md

このリポジトリで作業するAIコーディングエージェント向けの共通ガイドです。

## プロジェクト概要

iOSアプリからGoogle Cloud Speech-to-Text (STT) のgRPC streaming APIを利用するための
検証プロジェクト。以下の3ステップで段階的に構築している(詳細は
[docs/adr/](docs/adr/) のADRを参照):

1. 簡単なgRPCサーバーを立てる(`grpc/`) — 完了。[docs/adr/20260920.md](docs/adr/20260920.md)
2. iOS Swift側でgRPC Clientの実装を確立する(`iOS/`) — 完了
3. (1)(2)の土台をGoogle STT gRPCに適用する — 計画中。[docs/adr/20260923.md](docs/adr/20260923.md)

## ディレクトリ構成

```
.
├── grpc/            Goで実装したgRPCサーバー
│   ├── main.go
│   ├── helloworld/  Greeterサービス(proto + 生成コード)
│   └── Dockerfile
├── hono/            Hono(Node.js)で実装した、Google STT用アクセストークン発行サーバー
├── docker-compose.yml  grpc(50051番)・hono(8787番)サービスを起動
├── iOS/google_stt_grpc/  SwiftUIアプリ(Xcodeプロジェクト)
├── Android/         未着手
└── docs/adr/        Architecture Decision Record (yyyyMMdd.md形式)
```

## grpcサーバー(`grpc/`)

- 言語: Go(`grpc/go.mod`参照。`google.golang.org/grpc`を使用)
- サーバー起動:
  ```bash
  docker compose up -d --build
  ```
  ローカル実行のみなら:
  ```bash
  cd grpc && go run .
  ```
- 動作確認(reflectionを有効化しているので`grpcurl`でサービス一覧・RPC呼び出しが可能):
  ```bash
  grpcurl -plaintext localhost:50051 list
  grpcurl -plaintext localhost:50051 list greeter.Greeter
  grpcurl -plaintext -d '{"name": "taro"}' localhost:50051 greeter.Greeter.SayHello
  ```
- protoを変更した場合の再生成コマンド(`protoc` / `protoc-gen-go` /
  `protoc-gen-go-grpc`がPATH上にあること):
  ```bash
  cd grpc
  protoc --go_out=. --go_opt=paths=source_relative \
      --go-grpc_out=. --go-grpc_opt=paths=source_relative \
      helloworld/helloworld.proto
  ```
  生成された`*.pb.go`はリポジトリにコミットする(Docker build時にprotocを
  インストールしなくて済むようにするため)。

## iOSアプリ(`iOS/google_stt_grpc/`)

- SwiftUIアプリ。Xcodeプロジェクトは`iOS/google_stt_grpc/google_stt_grpc.xcodeproj`。
- gRPC Clientの実装には[grpc-swift 2](https://www.swift.org/blog/grpc-swift-2/)を使う想定(README参照)。

## ドキュメント運用

- 設計判断や区切りの良い作業単位は `docs/adr/yyyyMMdd.md` にADR(Architecture
  Decision Record)として残す。1日に複数書く場合はファイル名にサフィックスを付ける
  (例: `20260920-2.md`)。
- `CLAUDE.md`は本ファイルを参照するのみ。エージェント固有の追記が必要な場合は
  `CLAUDE.md`側に書き、共通のプロジェクト情報は本ファイルに集約する。

## 注意事項

- `.env`にはAPIキー等の秘匿情報が入るため絶対にコミットしない(`.gitignore`済み)。
  新しい秘匿情報を追加する場合は`.env.sample`にキー名のみ追記すること。
