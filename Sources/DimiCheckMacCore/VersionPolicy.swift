import Foundation

public struct MacVersionPolicyPayload: Codable, Equatable, Sendable {
    public let latestVersion: String
    public let minSupportedVersion: String
    public let downloadURL: String
    public let homebrewCommand: String
    public let message: String

    public init(
        latestVersion: String,
        minSupportedVersion: String,
        downloadURL: String,
        homebrewCommand: String,
        message: String
    ) {
        self.latestVersion = latestVersion
        self.minSupportedVersion = minSupportedVersion
        self.downloadURL = downloadURL
        self.homebrewCommand = homebrewCommand
        self.message = message
    }
}

public enum MacUpdateState: Equatable, Sendable {
    case current
    case optional
    case required
    case unknown
}

public struct AppVersion: Comparable, Equatable, Sendable {
    private let components: [Int]

    public init(_ rawValue: String) {
        let parsed = rawValue
            .split(separator: ".", omittingEmptySubsequences: false)
            .map { component in
                let numericPrefix = component.prefix { $0.isNumber }
                return Int(numericPrefix) ?? 0
            }
        self.components = parsed.isEmpty ? [0] : parsed
    }

    public static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let maxCount = max(lhs.components.count, rhs.components.count)
        for index in 0..<maxCount {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right {
                return left < right
            }
        }
        return false
    }
}

public enum VersionPolicy {
    public static func state(currentVersion: String, policy: MacVersionPolicyPayload?) -> MacUpdateState {
        guard let policy else { return .unknown }
        let current = AppVersion(currentVersion)
        if current < AppVersion(policy.minSupportedVersion) {
            return .required
        }
        if current < AppVersion(policy.latestVersion) {
            return .optional
        }
        return .current
    }
}
