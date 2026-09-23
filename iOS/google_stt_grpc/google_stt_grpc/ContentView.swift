//
//  ContentView.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/20.
//

import SwiftUI

struct ContentView: View {
  var body: some View {
    TabView {
      HomeView()
        .tabItem {
          Label("Home", systemImage: "house")
        }
      RecordView()
        .tabItem {
          Label("Record", systemImage: "mic")
        }
    }
  }
}

#Preview {
  ContentView()
}
