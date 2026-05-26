import Foundation

public enum AppStatusCode: String, Codable, CaseIterable, Sendable {
    case section
    case toilet
    case hallway
    case club
    case afterschool
    case project
    case early
    case etc
    case absence

    public var label: String {
        switch self {
        case .section: return "교실"
        case .toilet: return "화장실(물)"
        case .hallway: return "복도"
        case .club: return "동아리"
        case .afterschool: return "방과후"
        case .project: return "프로젝트"
        case .early: return "조기입실"
        case .etc: return "기타"
        case .absence: return "결석(조퇴)"
        }
    }

    public var symbolName: String {
        switch self {
        case .section: return "checkmark.circle.fill"
        case .toilet: return "drop.fill"
        case .hallway: return "figure.walk"
        case .club: return "person.3.fill"
        case .afterschool: return "book.closed.fill"
        case .project: return "hammer.fill"
        case .early: return "sun.max.fill"
        case .etc: return "ellipsis.circle.fill"
        case .absence: return "bed.double.fill"
        }
    }

    public static let quickActions: [AppStatusCode] = [
        .section,
        .toilet,
        .hallway,
        .club,
        .afterschool,
        .project,
        .early,
        .absence
    ]

    public static let favoriteOptions: [AppStatusCode] = [
        .toilet,
        .hallway,
        .club,
        .afterschool,
        .project,
        .early,
        .absence
    ]
}

public struct StudentProfile: Codable, Equatable, Sendable {
    public let userID: Int
    public let email: String
    public let grade: Int
    public let classNumber: Int
    public let number: Int

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case grade
        case classNumber = "class"
        case number
    }
}

public struct CurrentStatusPayload: Codable, Equatable, Sendable {
    public let grade: Int
    public let section: Int
    public let number: Int
    public let statusCode: String
    public let statusLabel: String
    public let reason: String?
    public let favoriteStatus: String?
    public let updatedAt: String?

    public init(
        grade: Int,
        section: Int,
        number: Int,
        statusCode: String,
        statusLabel: String,
        reason: String?,
        favoriteStatus: String?,
        updatedAt: String? = nil
    ) {
        self.grade = grade
        self.section = section
        self.number = number
        self.statusCode = statusCode
        self.statusLabel = statusLabel
        self.reason = reason
        self.favoriteStatus = favoriteStatus
        self.updatedAt = updatedAt
    }

    public var normalizedStatus: AppStatusCode? {
        AppStatusCode(rawValue: statusCode)
    }

    public var normalizedFavoriteStatus: AppStatusCode? {
        guard let favoriteStatus else { return nil }
        return AppStatusCode(rawValue: favoriteStatus)
    }

    public func matches(status expectedStatus: AppStatusCode, reason expectedReason: String? = nil) -> Bool {
        guard normalizedStatus == expectedStatus else { return false }
        let normalizedExpectedReason = expectedReason?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedActualReason = reason?.trimmingCharacters(in: .whitespacesAndNewlines)

        if expectedStatus == .etc {
            return normalizedActualReason == normalizedExpectedReason
        }

        return true
    }
}

public struct FavoritePayload: Codable, Equatable, Sendable {
    public let favoriteStatus: String?

    public var normalizedFavoriteStatus: AppStatusCode? {
        guard let favoriteStatus else { return nil }
        return AppStatusCode(rawValue: favoriteStatus)
    }
}

public struct UpdateStatusResponse: Codable, Equatable, Sendable {
    public let ok: Bool
    public let status: CurrentStatusPayload
}

public struct SchoolLifeTodayPayload: Codable, Equatable, Sendable {
    public let date: String
    public let grade: Int
    public let section: Int
    public let timetable: TimetablePayload?
    public let meal: MealPayload?
    public let errors: [String: String]?
}

public struct TimetablePayload: Codable, Equatable, Sendable {
    public let lessons: [LessonPayload]
    public let maxPeriod: Int
    public let date: String
    public let message: String?
}

public struct LessonPayload: Codable, Equatable, Sendable {
    public let period: Int?
    public let subject: String
}

public struct MealPayload: Codable, Equatable, Sendable {
    public let date: String
    public let breakfast: String?
    public let lunch: String?
    public let dinner: String?
}

public struct OAuthTokenResponse: Codable, Equatable, Sendable {
    public let accessToken: String
    public let tokenType: String
    public let expiresIn: Int
    public let refreshToken: String
    public let scope: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case scope
    }
}
