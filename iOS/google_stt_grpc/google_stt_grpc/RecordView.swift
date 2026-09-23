//
//  RecordView.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import SwiftUI

struct RecordView: View {
  @State private var isRecording = false

  var body: some View {
    VStack(spacing: 20) {
      Text(isRecording ? "録音中" : "停止中")
      Button(isRecording ? "録音を停止" : "録音を開始") {
        isRecording.toggle()
      }
    }
    .padding()
  }
}

#Preview {
  RecordView()
}
