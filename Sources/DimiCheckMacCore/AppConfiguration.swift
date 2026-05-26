import Foundation

public struct AppConfiguration: Sendable {
    public let serverBaseURL: URL
    public let oauthClientID: String
    public let redirectURIs: [String]
    public let scopes: [String]
    public let keychainService: String
    public let defaultFavoriteStatus: AppStatusCode

    public init(
        serverBaseURL: URL,
        oauthClientID: String,
        redirectURIs: [String],
        scopes: [String],
        keychainService: String = "com.dimicheck.mac.auth",
        defaultFavoriteStatus: AppStatusCode = .toilet
    ) {
        self.serverBaseURL = serverBaseURL
        self.oauthClientID = oauthClientID
        self.redirectURIs = redirectURIs
        self.scopes = scopes
        self.keychainService = keychainService
        self.defaultFavoriteStatus = defaultFavoriteStatus
    }

    public static let shared = AppConfiguration(
        serverBaseURL: URL(string: ProcessInfo.processInfo.environment["DIMICHECK_SERVER_BASE_URL"] ?? "https://dimicheck.com")!,
        oauthClientID: ProcessInfo.processInfo.environment["DIMICHECK_OAUTH_CLIENT_ID"] ?? "dimicheck-mac-public",
        redirectURIs: Self.parseRedirectURIs(
            ProcessInfo.processInfo.environment["DIMICHECK_OAUTH_REDIRECT_URIS"]
            ?? ProcessInfo.processInfo.environment["DIMICHECK_OAUTH_REDIRECT_URI"]
            ?? "http://127.0.0.1:45823/oauth-callback http://127.0.0.1:45824/oauth-callback http://127.0.0.1:45825/oauth-callback http://127.0.0.1:45826/oauth-callback http://127.0.0.1:45827/oauth-callback dimicheckmac://oauth-callback"
        ),
        scopes: Self.parseScopes(ProcessInfo.processInfo.environment["DIMICHECK_OAUTH_SCOPES"] ?? "basic student_info status.read status.write")
    )

    public var isConfigured: Bool {
        !oauthClientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    public var callbackScheme: String? {
        redirectURL?.scheme
    }

    public var redirectURL: URL? {
        redirectURIs.compactMap(URL.init(string:)).first
    }

    public var redirectURLs: [URL] {
        redirectURIs.compactMap(URL.init(string:))
    }

    public var authorizeURL: URL {
        serverBaseURL.appending(path: "/oauth/authorize")
    }

    public var tokenURL: URL {
        serverBaseURL.appending(path: "/oauth/token")
    }

    public var revokeURL: URL {
        serverBaseURL.appending(path: "/oauth/revoke")
    }

    public var userinfoURL: URL {
        serverBaseURL.appending(path: "/oauth/userinfo")
    }

    public var statusURL: URL {
        serverBaseURL.appending(path: "/api/app/status")
    }

    public var myStatusURL: URL {
        serverBaseURL.appending(path: "/api/app/status/me")
    }

    public var favoriteURL: URL {
        serverBaseURL.appending(path: "/api/app/favorite")
    }

    public var schoolLifeTodayURL: URL {
        serverBaseURL.appending(path: "/api/app/schoollife/today")
    }

    public var macVersionPolicyURL: URL {
        serverBaseURL.appending(path: "/api/app/mac/version")
    }

    public var browserURL: URL {
        serverBaseURL.appending(path: "/user.html")
    }

    public func authorizationRequestURL(state: String, challenge: String, redirectURI: String) throws -> URL {
        guard isConfigured else {
            throw APIError.invalidConfiguration("OAuth client ID is not configured.")
        }
        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: oauthClientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ]
        guard let url = components?.url else {
            throw APIError.invalidConfiguration("Failed to build authorization URL.")
        }
        return url
    }

    private static func parseScopes(_ raw: String) -> [String] {
        raw.split(whereSeparator: \.isWhitespace).map(String.init).filter { !$0.isEmpty }
    }

    private static func parseRedirectURIs(_ raw: String) -> [String] {
        raw
            .split(whereSeparator: { $0.isWhitespace || $0 == "," || $0 == "\n" })
            .map(String.init)
            .filter { !$0.isEmpty }
    }
}
