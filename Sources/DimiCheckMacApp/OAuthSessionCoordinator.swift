import AppKit
import DimiCheckMacCore
import Foundation
import Network

@MainActor
final class OAuthSessionCoordinator {
    static let shared = OAuthSessionCoordinator()

    struct SignInResult: Sendable {
        let code: String
        let redirectURI: String
    }

    private var continuation: CheckedContinuation<URL, Error>?
    private var expectedScheme: String?
    private var loopbackServer: LoopbackCallbackServer?

    private init() {}

    func signIn(using configuration: AppConfiguration, pkce: PKCEChallenge) async throws -> SignInResult {
        if let redirectURL = firstAvailableLoopbackRedirect(from: configuration.redirectURLs) {
            let authURL = try configuration.authorizationRequestURL(
                state: pkce.state,
                challenge: pkce.challenge,
                redirectURI: redirectURL.absoluteString
            )
            let callbackURL = try await waitForLoopbackCallback(redirectURL: redirectURL) {
                NSWorkspace.shared.open(authURL)
            }
            let code = try Self.extractAuthorizationCode(from: callbackURL, expectedState: pkce.state)
            return SignInResult(code: code, redirectURI: redirectURL.absoluteString)
        }

        guard let customSchemeRedirect = configuration.redirectURLs.first(where: { url in
            let scheme = url.scheme?.lowercased() ?? ""
            return scheme != "http" && scheme != "https"
        }) else {
            throw APIError.invalidConfiguration("No valid redirect URI is configured.")
        }

        let authURL = try configuration.authorizationRequestURL(
            state: pkce.state,
            challenge: pkce.challenge,
            redirectURI: customSchemeRedirect.absoluteString
        )

        guard let callbackScheme = configuration.callbackScheme else {
            throw APIError.invalidConfiguration("Redirect URI scheme is missing.")
        }

        let callbackURL = try await waitForCustomSchemeCallback(expectedScheme: callbackScheme) {
            NSWorkspace.shared.open(authURL)
        }

        let code = try Self.extractAuthorizationCode(from: callbackURL, expectedState: pkce.state)
        return SignInResult(code: code, redirectURI: customSchemeRedirect.absoluteString)
    }

    private func firstAvailableLoopbackRedirect(from urls: [URL]) -> URL? {
        for url in urls {
            guard let scheme = url.scheme?.lowercased(), scheme == "http",
                  let host = url.host?.lowercased(), host == "127.0.0.1" || host == "localhost",
                  let portValue = url.port,
                  let port = NWEndpoint.Port(rawValue: UInt16(portValue))
            else {
                continue
            }

            do {
                let listener = try NWListener(using: .tcp, on: port)
                listener.cancel()
                return url
            } catch {
                continue
            }
        }
        return nil
    }

    func handleIncoming(urls: [URL]) {
        guard let continuation, let expectedScheme else { return }
        guard let callbackURL = urls.first(where: { $0.scheme?.caseInsensitiveCompare(expectedScheme) == .orderedSame }) else {
            return
        }
        self.continuation = nil
        self.expectedScheme = nil
        continuation.resume(returning: callbackURL)
    }

    private func waitForCustomSchemeCallback(expectedScheme: String, launch: () -> Void) async throws -> URL {
        if continuation != nil {
            throw APIError.transport("Another login flow is already in progress.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            self.expectedScheme = expectedScheme
            self.continuation = continuation
            launch()
        }
    }

    private func waitForLoopbackCallback(redirectURL: URL, launch: () -> Void) async throws -> URL {
        if continuation != nil || loopbackServer != nil {
            throw APIError.transport("Another login flow is already in progress.")
        }

        return try await withCheckedThrowingContinuation { continuation in
            do {
                let server = try LoopbackCallbackServer(redirectURL: redirectURL) { [weak self] result in
                    Task { @MainActor in
                        self?.loopbackServer = nil
                        switch result {
                        case .success(let url):
                            continuation.resume(returning: url)
                        case .failure(let error):
                            continuation.resume(throwing: error)
                        }
                    }
                }
                self.loopbackServer = server
                try server.start()
                launch()
            } catch {
                self.loopbackServer = nil
                continuation.resume(throwing: error)
            }
        }
    }

    private static func extractAuthorizationCode(from callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidCallback
        }
        let queryItems = components.queryItems ?? []
        let state = queryItems.first(where: { $0.name == "state" })?.value
        guard state == expectedState else {
            throw APIError.stateMismatch
        }
        if let errorValue = queryItems.first(where: { $0.name == "error" })?.value {
            throw APIError.server(statusCode: 400, message: errorValue)
        }
        guard let code = queryItems.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw APIError.missingAuthorizationCode
        }
        return code
    }
}

private final class LoopbackCallbackServer: @unchecked Sendable {
    private let redirectURL: URL
    private let completion: @Sendable (Result<URL, Error>) -> Void
    private let queue = DispatchQueue(label: "dimicheck.mac.oauth.loopback")
    private var listener: NWListener?
    private var hasCompleted = false

    init(redirectURL: URL, completion: @escaping @Sendable (Result<URL, Error>) -> Void) throws {
        self.redirectURL = redirectURL
        self.completion = completion
    }

    func start() throws {
        guard let portValue = redirectURL.port else {
            throw APIError.invalidConfiguration("Loopback redirect URI must include a port.")
        }
        guard let port = NWEndpoint.Port(rawValue: UInt16(portValue)) else {
            throw APIError.invalidConfiguration("Invalid loopback redirect port.")
        }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener = try NWListener(using: parameters, on: port)
        self.listener = listener

        listener.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed(let error):
                self?.finish(.failure(APIError.transport("OAuth callback listener failed: \(error.localizedDescription)")))
            default:
                break
            }
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.handle(connection: connection)
        }

        listener.start(queue: queue)
    }

    private func handle(connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            guard let self else { return }
            if let error {
                self.finish(.failure(APIError.transport("OAuth callback receive failed: \(error.localizedDescription)")))
                connection.cancel()
                return
            }

            guard let data, let request = String(data: data, encoding: .utf8) else {
                self.finish(.failure(APIError.invalidCallback))
                connection.cancel()
                return
            }

            guard let callbackURL = self.parseCallbackURL(from: request) else {
                self.respond(connection: connection, body: "잘못된 콜백입니다.")
                self.finish(.failure(APIError.invalidCallback))
                return
            }

            self.respond(connection: connection, body: "로그인이 완료되었습니다. DimiCheck Mac으로 돌아가세요.")
            self.finish(.success(callbackURL))
        }
    }

    private func parseCallbackURL(from request: String) -> URL? {
        guard let firstLine = request.split(separator: "\r\n").first else { return nil }
        let parts = firstLine.split(separator: " ")
        guard parts.count >= 2 else { return nil }
        let pathAndQuery = String(parts[1])
        var components = URLComponents()
        components.scheme = redirectURL.scheme
        components.host = redirectURL.host
        components.port = redirectURL.port
        components.percentEncodedPath = redirectURL.path

        if let questionIndex = pathAndQuery.firstIndex(of: "?") {
            let path = String(pathAndQuery[..<questionIndex])
            let query = String(pathAndQuery[pathAndQuery.index(after: questionIndex)...])
            components.percentEncodedPath = path
            components.percentEncodedQuery = query
        } else {
            components.percentEncodedPath = pathAndQuery
        }

        return components.url
    }

    private func respond(connection: NWConnection, body: String) {
        let html = """
        <!DOCTYPE html>
        <html lang="ko">
          <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1" />
            <title>DimiCheck Mac</title>
            <style>
              body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; padding: 32px; color: #111827; background: #f8fafc; }
              .card { max-width: 460px; margin: 8vh auto; padding: 24px; border-radius: 20px; background: white; box-shadow: 0 16px 40px rgba(15, 23, 42, 0.08); }
              h1 { font-size: 24px; margin: 0 0 12px; }
              p { color: #475467; line-height: 1.6; margin: 0; }
            </style>
          </head>
          <body>
            <div class="card">
              <h1>DimiCheck Mac</h1>
              <p>\(body)</p>
            </div>
          </body>
        </html>
        """
        let response = """
        HTTP/1.1 200 OK\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(html.utf8.count)\r
        Connection: close\r
        \r
        \(html)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func finish(_ result: Result<URL, Error>) {
        guard !hasCompleted else { return }
        hasCompleted = true
        listener?.cancel()
        listener = nil
        completion(result)
    }
}
