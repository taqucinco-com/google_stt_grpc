---
name: grpc-server-dev
description: Regenerate Go gRPC stubs from .proto files under grpc/, then rebuild and run the gRPC server via Docker Compose, and verify it with grpcurl. Use this whenever the user edits or adds a .proto file in this repo, asks to start/restart/rebuild the local gRPC server, or wants to confirm gRPC services/methods are reachable (e.g. "grpcのprotoを更新した", "gRPCサーバーを起動して", "grpcurlで確認して", mentions protoc/protoc-gen-go/protoc-gen-go-grpc/grpcurl in this repo's context). Always run all three steps together (regenerate, rebuild, verify) rather than stopping after just editing the .proto file.
---

# gRPC server dev loop (Go + Docker + grpcurl)

This repo's gRPC server lives in `grpc/` (Go module `google_stt_grpc/grpc`). A
`.proto` change is not "done" until the generated Go code, the running server,
and an actual RPC call have all been verified — a proto edit with no
regeneration, or a server restart with no grpcurl check, is an incomplete task.
The exact same three-step loop applies whether this is the first time a
service is added or the fiftieth.

## Step 1 — Regenerate the Go stubs

Only needed if a `.proto` file under `grpc/` was added or changed. Generated
`*.pb.go` files are committed to the repo (see `AGENTS.md`), specifically so
`docker build` never needs `protoc` installed — that means every proto edit
must be regenerated and committed locally, not left for Docker to do.

```bash
which protoc protoc-gen-go protoc-gen-go-grpc || true
# If protoc-gen-go / protoc-gen-go-grpc are missing from PATH, install them
# for the active `go` toolchain and put GOPATH/bin on PATH for this command:
go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@latest

cd grpc
PATH="$(go env GOPATH)/bin:$PATH" protoc \
  --go_out=. --go_opt=paths=source_relative \
  --go-grpc_out=. --go-grpc_opt=paths=source_relative \
  <path/to/your.proto>   # e.g. helloworld/helloworld.proto
```

Then implement/update the service methods in the corresponding `main.go` (or
service file), and confirm it compiles locally before touching Docker:

```bash
cd grpc && go build -o /tmp/grpc_server_test . && go vet ./...
```

## Step 2 — Rebuild and start the server via Docker

The server is defined as the `grpc` service in the repo-root
`docker-compose.yml`, exposing port `50051`.

```bash
docker compose up -d --build
docker compose logs grpc --no-log-prefix --tail 20   # confirm "server listening at ..."
```

## Step 3 — Verify with grpcurl

The server registers `reflection.Register`, so grpcurl can introspect it
without needing the `.proto` file. Always check both that the service is
listed AND that at least one RPC actually returns the expected response —
reflection listing the service doesn't prove the implementation works.

```bash
grpcurl -plaintext localhost:50051 list                     # service inventory
grpcurl -plaintext localhost:50051 list <package>.<Service>  # methods on one service
grpcurl -plaintext -d '{"...": "..."}' localhost:50051 <package>.<Service>.<Method>
```

If a call fails or hangs, check `docker compose logs grpc` before assuming
the client-side call is wrong — most issues at this stage are on the server
(unimplemented method, panic, wrong port).

## Keep AGENTS.md in sync

`AGENTS.md` documents this same loop as the project's source of truth for
build/run commands. If the commands here ever need to change (new proto
plugin version, new compose service name, etc.), update both files together.
