//
//  HomeView.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import SwiftUI

struct HomeView: View {
  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text("Hello, world!")
      Button("Test Unary") {
        Task {
          let message = try await testUnary()
          print(message)
        }
      }
      Button("Test Server Stream") {
        Task {
          for try await message in testServerStream() {
            print(message)
          }
        }
      }
      Button("Test Client Stream") {
        Task {
          let stream = testClientStream()
          await stream.send("taro")
          try await Task.sleep(nanoseconds: 1_000_000_000)
          await stream.send("hanako")
          stream.finish()
          let message = try await stream.result.value
          print(message)
        }
      }
      Button("Test Bidi Stream") {
        let stream = testBidiStream()
        Task {
          for try await message in stream.result {
            print(message)
          }
        }
        Task {
          await stream.send("taro")
          try await Task.sleep(nanoseconds: 1_000_000_000)
          await stream.send("hanako")
          stream.finish()
        }
      }
    }
    .padding()
  }
}

#Preview {
  HomeView()
}
