import CryptoKit
import Foundation
import Security

public struct PKCEChallenge: Equatable, Sendable {
    public let verifier: String
    public let challenge: String
    public let state: String

    public init(verifier: String, challenge: String, state: String) {
        self.verifier = verifier
        self.challenge = challenge
        self.state = state
    }

    public static func make() throws -> PKCEChallenge {
        let verifier = try randomURLSafeString(length: 48)
        let challenge = makeCodeChallenge(from: verifier)
        let state = try randomURLSafeString(length: 24)
        return PKCEChallenge(verifier: verifier, challenge: challenge, state: state)
    }

    public static func makeCodeChallenge(from verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
    }

    private static func randomURLSafeString(length: Int) throws -> String {
        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, length, buffer.baseAddress!)
        }
        guard result == errSecSuccess else {
            throw APIError.transport("Failed to generate secure random bytes.")
        }
        return data.base64URLEncodedString()
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
