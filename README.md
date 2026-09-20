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
greeter.Greeter
grpc.reflection.v1.ServerReflection
grpc.reflection.v1alpha.ServerReflection

# greeter.Greeterが持つメソッド一覧
$ grpcurl -plaintext localhost:50051 list greeter.Greeter
greeter.Greeter.SayChat
greeter.Greeter.SayHello
greeter.Greeter.SayHelloAgain
greeter.Greeter.SayHelloToMany
```

#### SayHello (unary)

```bash
$ grpcurl -plaintext -d '{"name": "taro"}' localhost:50051 greeter.Greeter.SayHello
{
  "message": "Hello taro"
}
```

#### SayHelloAgain (server streaming)

```bash
$ grpcurl -plaintext -d '{"name": "taro"}' localhost:50051 greeter.Greeter.SayHelloAgain
{
  "message": "Hello taro"
}
{
  "message": "Hello taro"
}
```

#### SayHelloToMany (client streaming)

```bash
$ echo -e '{"name": "taro"}\n{"name": "hanako"}' | grpcurl -d @ -plaintext localhost:50051 greeter.Greeter.SayHelloToMany
{
  "message": "Hello! taro, hanako"
}
```

#### SayChat (bidirectional streaming)

```bash
$ echo -e '{"name": "taro"}\n{"name": "hanako"}' | grpcurl -d @ -plaintext localhost:50051 greeter.Greeter.SayChat
{
  "message": "Hello taro"
}
{
  "message": "Hello hanako"
}
```

## iOS

https://www.swift.org/blog/grpc-swift-2/
