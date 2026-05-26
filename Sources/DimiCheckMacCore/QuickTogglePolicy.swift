import Foundation

public enum QuickTogglePolicy {
    public static func targetStatus(
        current: AppStatusCode?,
        favorite: AppStatusCode?,
        defaultFavorite: AppStatusCode = .toilet
    ) -> AppStatusCode {
        guard let current else {
            return favorite ?? defaultFavorite
        }
        return current == .section ? (favorite ?? defaultFavorite) : .section
    }
}
