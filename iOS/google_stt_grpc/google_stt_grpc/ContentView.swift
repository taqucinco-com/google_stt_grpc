//
//  ContentView.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/20.
//

import SwiftUI
import GRPCCore
import GRPCNIOTransportHTTP2
import GRPCProtobuf
import SwiftProtobuf

struct ContentView: View {
  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("Hello, world!")
      Button("Click Me") {
        Task {
          try await withGRPCClient(
            transport: .http2NIOPosix(
              target: .dns(host: "localhost", port: 50051),
              transportSecurity: .plaintext
            )
          ) { client in
            let greeter = Greeter_Greeter.Client(wrapping: client)
            let reply = try await greeter.sayHello(.with { $0.name = "taro" })
            print(reply.message)  // ここがdebug consoleに出る
          }
        }
      }
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
