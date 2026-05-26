import Foundation

public enum APIError: LocalizedError, Sendable {
    case invalidConfiguration(String)
    case invalidResponse
    case invalidCallback
    case stateMismatch
    case missingAuthorizationCode
    case server(statusCode: Int, message: String)
    case transport(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message),
             .transport(let message):
            return message
        case .invalidResponse:
            return "Unexpected server response."
        case .invalidCallback:
            return "Invalid login callback."
        case .stateMismatch:
            return "Login state verification failed."
        case .missingAuthorizationCode:
            return "Authorization code missing."
        case .server(_, let message):
            return message
        }
    }

    public var shouldClearStoredSession: Bool {
        switch self {
        case .server(let statusCode, _):
            return statusCode == 400 || statusCode == 401 || statusCode == 403
        case .invalidCallback, .stateMismatch, .missingAuthorizationCode:
            return true
        case .invalidConfiguration, .invalidResponse, .transport:
            return false
        }
    }
}

public struct DimiCheckAPI: Sendable {
    public init() {}

    public func exchangeAuthorizationCode(
        config: AppConfiguration,
        code: String,
        redirectURI: String,
        codeVerifier: String
    ) async throws -> OAuthTokenResponse {
        try await sendTokenRequest(
            url: config.tokenURL,
            form: [
                "grant_type": "authorization_code",
                "client_id": config.oauthClientID,
                "code": code,
                "redirect_uri": redirectURI,
                "code_verifier": codeVerifier
            ]
        )
    }

    public func refreshAccessToken(
        config: AppConfiguration,
        refreshToken: String
    ) async throws -> OAuthTokenResponse {
        try await sendTokenRequest(
            url: config.tokenURL,
            form: [
                "grant_type": "refresh_token",
                "client_id": config.oauthClientID,
                "refresh_token": refreshToken
            ]
        )
    }

    public func revokeRefreshToken(
        config: AppConfiguration,
        refreshToken: String
    ) async throws {
        var request = URLRequest(url: config.revokeURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncodedData([
            "client_id": config.oauthClientID,
            "token": refreshToken
        ])
        _ = try await perform(request, decode: EmptyResponse.self)
    }

    public func fetchUserProfile(config: AppConfiguration, accessToken: String) async throws -> StudentProfile {
        var request = URLRequest(url: config.userinfoURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request, decode: StudentProfile.self)
    }

    public func fetchCurrentStatus(config: AppConfiguration, accessToken: String) async throws -> CurrentStatusPayload {
        var request = URLRequest(url: config.myStatusURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request, decode: CurrentStatusPayload.self)
    }

    public func fetchFavoriteStatus(config: AppConfiguration, accessToken: String) async throws -> AppStatusCode? {
        var request = URLRequest(url: config.favoriteURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        let payload: FavoritePayload = try await perform(request, decode: FavoritePayload.self)
        return payload.normalizedFavoriteStatus
    }

    public func updateFavoriteStatus(
        config: AppConfiguration,
        accessToken: String,
        status: AppStatusCode?
    ) async throws -> AppStatusCode? {
        var request = URLRequest(url: config.favoriteURL)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(UpdateFavoriteRequest(statusCode: status?.rawValue))
        let payload: FavoritePayload = try await perform(request, decode: FavoritePayload.self)
        return payload.normalizedFavoriteStatus
    }

    public func fetchSchoolLifeToday(config: AppConfiguration, accessToken: String) async throws -> SchoolLifeTodayPayload {
        var request = URLRequest(url: config.schoolLifeTodayURL)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        return try await perform(request, decode: SchoolLifeTodayPayload.self)
    }

    public func fetchMacVersionPolicy(config: AppConfiguration) async throws -> MacVersionPolicyPayload {
        let request = URLRequest(url: config.macVersionPolicyURL)
        return try await perform(request, decode: MacVersionPolicyPayload.self)
    }

    public func updateStatus(
        config: AppConfiguration,
        accessToken: String,
        status: AppStatusCode,
        reason: String? = nil,
        expectedUpdatedAt: String? = nil
    ) async throws -> CurrentStatusPayload {
        var request = URLRequest(url: config.statusURL)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            UpdateStatusRequest(
                statusCode: status.rawValue,
                reason: reason,
                expectedUpdatedAt: expectedUpdatedAt
            )
        )
        let response: UpdateStatusResponse = try await perform(request, decode: UpdateStatusResponse.self)
        return response.status
    }

    private func sendTokenRequest(url: URL, form: [String: String]) async throws -> OAuthTokenResponse {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = formEncodedData(form)
        return try await perform(request, decode: OAuthTokenResponse.self)
    }

    private func perform<Response: Decodable>(_ request: URLRequest, decode type: Response.Type) async throws -> Response {
        var request = request
        request.cachePolicy = .reloadIgnoringLocalCacheData
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = Self.serverMessage(statusCode: httpResponse.statusCode, data: data)
            throw APIError.server(statusCode: httpResponse.statusCode, message: message)
        }

        do {
            return try JSONDecoder().decode(Response.self, from: data)
        } catch {
            throw APIError.transport("Failed to decode server response: \(error.localizedDescription)")
        }
    }

    private func formEncodedData(_ values: [String: String]) -> Data {
        let payload = values
            .sorted { $0.key < $1.key }
            .map { key, value in
                "\(escapeFormComponent(key))=\(escapeFormComponent(value))"
            }
            .joined(separator: "&")
        return Data(payload.utf8)
    }

    private func escapeFormComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    static func serverMessage(statusCode: Int, data: Data) -> String {
        parseErrorMessage(from: data) ?? fallbackServerMessage(statusCode: statusCode)
    }

    private static func fallbackServerMessage(statusCode: Int) -> String {
        switch statusCode {
        case 502, 503, 504:
            return "DimiCheck 서버가 잠시 불안정합니다. 잠시 후 다시 시도해 주세요. (\(statusCode))"
        case 500...599:
            return "서버 오류가 발생했습니다. 잠시 후 다시 시도해 주세요. (\(statusCode))"
        case 401:
            return "로그인이 만료되었습니다. 다시 로그인해 주세요."
        case 403:
            return "요청 권한이 없습니다. 브라우저에서 다시 확인해 주세요."
        default:
            return HTTPURLResponse.localizedString(forStatusCode: statusCode)
        }
    }

    private static func parseErrorMessage(from data: Data) -> String? {
        struct ErrorEnvelope: Decodable {
            struct ErrorBody: Decodable {
                let code: String?
                let message: String?
            }
            let error: ErrorBody?
            let message: String?
            let errorDescription: String?

            enum CodingKeys: String, CodingKey {
                case error
                case message
                case errorDescription = "error_description"
            }
        }

        if let decoded = try? JSONDecoder().decode(ErrorEnvelope.self, from: data) {
            return decoded.error?.message ?? decoded.message ?? decoded.errorDescription
        }
        guard let rawText = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawText.isEmpty,
              !rawText.looksLikeHTML
        else {
            return nil
        }
        return rawText.count > 240 ? String(rawText.prefix(240)) : rawText
    }
}

private extension String {
    var looksLikeHTML: Bool {
        let lowercasedText = lowercased()
        return lowercasedText.hasPrefix("<!doctype html")
            || lowercasedText.hasPrefix("<html")
            || lowercasedText.contains("<body")
            || lowercasedText.contains("<head")
            || lowercasedText.contains("</html>")
    }
}

private struct UpdateStatusRequest: Codable, Sendable {
    let statusCode: String
    let reason: String?
    let expectedUpdatedAt: String?
}

private struct UpdateFavoriteRequest: Codable, Sendable {
    let statusCode: String?
}

private struct EmptyResponse: Decodable, Sendable {}
