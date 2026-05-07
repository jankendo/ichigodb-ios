import Foundation

struct AuthSession: Codable, Equatable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Date
    var user: AuthUser

    var shouldRefresh: Bool {
        expiresAt.timeIntervalSinceNow < 300
    }
}

struct AuthUser: Codable, Equatable {
    var id: String
    var email: String?

    enum CodingKeys: String, CodingKey {
        case id
        case email
    }
}

enum AuthError: LocalizedError, Equatable {
    case invalidCredentials
    case missingSession
    case badStatus(Int, String)
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "メールアドレスまたはパスワードが違います。"
        case .missingSession:
            return "ログイン情報を取得できませんでした。"
        case .badStatus(let status, let body):
            if status == 400 || status == 401 {
                return "メールアドレスまたはパスワードが違います。"
            }
            return "認証に失敗しました。status=\(status) \(body)"
        case .invalidURL:
            return "認証URLが不正です。"
        }
    }
}

final class SupabaseAuthClient {
    private let config: SupabaseConfig
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(config: SupabaseConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        var request = try authRequest(path: "auth/v1/token", queryItems: [URLQueryItem(name: "grant_type", value: "password")])
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "email": email.trimmingCharacters(in: .whitespacesAndNewlines),
            "password": password
        ])
        return try await performTokenRequest(request)
    }

    func refresh(refreshToken: String) async throws -> AuthSession {
        var request = try authRequest(path: "auth/v1/token", queryItems: [URLQueryItem(name: "grant_type", value: "refresh_token")])
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": refreshToken])
        return try await performTokenRequest(request)
    }

    func signOut(accessToken: String) async {
        guard var request = try? authRequest(path: "auth/v1/logout") else { return }
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        _ = try? await session.data(for: request)
    }

    private func performTokenRequest(_ request: URLRequest) async throws -> AuthSession {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AuthError.missingSession
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AuthError.badStatus(http.statusCode, body)
        }
        let responseBody = try decoder.decode(AuthTokenResponse.self, from: data)
        guard let accessToken = responseBody.accessToken,
              let refreshToken = responseBody.refreshToken,
              let user = responseBody.user else {
            throw AuthError.missingSession
        }
        let expiresIn = max(60, responseBody.expiresIn ?? 3600)
        return AuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(expiresIn)),
            user: user
        )
    }

    private func authRequest(path: String, queryItems: [URLQueryItem] = []) throws -> URLRequest {
        let base = config.url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard var components = URLComponents(string: "\(base)/\(path)") else {
            throw AuthError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw AuthError.invalidURL
        }
        var request = URLRequest(url: url)
        request.setValue(config.anonKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }
}

private struct AuthTokenResponse: Decodable {
    var accessToken: String?
    var refreshToken: String?
    var expiresIn: Int?
    var user: AuthUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case user
    }
}
