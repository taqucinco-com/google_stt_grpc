//
//  AuthTokenClient.swift
//  google_stt_grpc
//
//  Created by sudo takuya on 2026/09/23.
//

import Foundation

/// `hono/`サーバー(`GET /token`)が発行するGoogle STT用アクセストークン。
struct AuthToken: Decodable {
  let accessToken: String
  let expiresIn: Int?

  enum CodingKeys: String, CodingKey {
    case accessToken = "access_token"
    case expiresIn = "expires_in"
  }
}

enum AuthTokenClientError: Error {
  case invalidResponse
}

/// `hono/`サーバーの`/token`エンドポイントを叩くだけの責務を持つクライアント。
final class AuthTokenClient {
  private let tokenURL: URL

  init(tokenURL: URL = URL(string: "http://localhost:8787/token")!) {
    self.tokenURL = tokenURL
  }

  func fetchToken() async throws -> AuthToken {
    let (data, response) = try await URLSession.shared.data(from: tokenURL)
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw AuthTokenClientError.invalidResponse
    }
    return try JSONDecoder().decode(AuthToken.self, from: data)
  }
}
