import AppKit
import Combine
import DimiCheckMacCore
import Foundation
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    enum Phase: Equatable {
        case booting
        case signedOut
        case signingIn
        case ready
    }

    @Published private(set) var phase: Phase = .booting
    @Published private(set) var currentStatus: CurrentStatusPayload?
    @Published private(set) var favoriteStatus: AppStatusCode?
    @Published private(set) var schoolLifeToday: SchoolLifeTodayPayload?
    @Published private(set) var profile: StudentProfile?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isWorking = false
    @Published private(set) var isSchoolLifeLoading = false
    @Published private(set) var isVersionPolicyLoading = false
    @Published private(set) var pendingStatusCode: AppStatusCode?
    @Published private(set) var pendingFavoriteStatusCode: AppStatusCode?
    @Published private(set) var versionPolicy: MacVersionPolicyPayload?
    @Published private(set) var didCopyUpdateCommand = false
    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var launchAtLoginRequiresApproval = false

    let configuration: AppConfiguration

    private let api: DimiCheckAPI
    private let keychain: KeychainStore
    private let oauthCoordinator = OAuthSessionCoordinator.shared
    private let postWriteWatchdogDelaysNs: [UInt64] = [
        2_000_000_000,
        8_000_000_000
    ]

    private var accessToken: String?
    private var accessTokenExpiresAt: Date?
    private var didStart = false
    private var postWriteVerificationTask: Task<Void, Never>?

    init(configuration: AppConfiguration = .shared, api: DimiCheckAPI = .init()) {
        self.configuration = configuration
        self.api = api
        self.keychain = KeychainStore(service: configuration.keychainService)
    }

    var currentStatusCode: AppStatusCode? {
        currentStatus?.normalizedStatus
    }

    var currentStatusLabel: String {
        currentStatus?.statusLabel ?? "로그인 필요"
    }

    var favoriteLabel: String {
        (favoriteStatus ?? configuration.defaultFavoriteStatus).label
    }

    var menuSymbolName: String {
        switch phase {
        case .booting:
            return "arrow.triangle.2.circlepath.circle"
        case .signingIn:
            return "person.crop.circle.badge.clock"
        case .signedOut:
            return "person.crop.circle.badge.exclamationmark"
        case .ready:
            return currentStatusCode?.symbolName ?? "questionmark.circle"
        }
    }

    var quickStatuses: [AppStatusCode] {
        AppStatusCode.quickActions
    }

    var favoriteStatuses: [AppStatusCode] {
        AppStatusCode.favoriteOptions
    }

    var currentAppVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    var updateState: MacUpdateState {
        VersionPolicy.state(currentVersion: currentAppVersion, policy: versionPolicy)
    }

    var isUpdateRequired: Bool {
        updateState == .required
    }

    func start() {
        guard !didStart else { return }
        didStart = true
        refreshLaunchAtLoginSetting()
        Task { await refreshVersionPolicy() }
        Task {
            await restoreSessionIfPossible()
        }
    }

    func restoreSessionIfPossible() async {
        guard configuration.isConfigured else {
            phase = .signedOut
            errorMessage = "OAuth Client ID를 먼저 설정해야 합니다."
            return
        }
        do {
            guard let refreshToken = try keychain.load() else {
                phase = .signedOut
                return
            }
            try await applyRefreshedSession(using: refreshToken)
        } catch {
            if (error as? APIError)?.shouldClearStoredSession == true {
                keychain.delete()
            }
            accessToken = nil
            accessTokenExpiresAt = nil
            currentStatus = nil
            favoriteStatus = nil
            schoolLifeToday = nil
            profile = nil
            phase = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    func signIn() async {
        guard !isWorking else { return }
        guard configuration.isConfigured else {
            errorMessage = "OAuth Client ID가 비어 있습니다."
            phase = .signedOut
            return
        }
        isWorking = true
        errorMessage = nil
        phase = .signingIn

        defer {
            isWorking = false
        }

        do {
            let pkce = try PKCEChallenge.make()
            let signInResult = try await oauthCoordinator.signIn(using: configuration, pkce: pkce)
            let response = try await api.exchangeAuthorizationCode(
                config: configuration,
                code: signInResult.code,
                redirectURI: signInResult.redirectURI,
                codeVerifier: pkce.verifier
            )
            try keychain.save(response.refreshToken)
            storeAccessToken(response)
            try await refreshRemoteState()
            phase = .ready
            Task { await refreshSchoolLifeToday() }
        } catch {
            phase = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    func setStatus(_ status: AppStatusCode) async {
        guard !isUpdateRequired else {
            errorMessage = "업데이트 후 상태를 변경할 수 있습니다."
            return
        }
        guard !isWorking else { return }
        isWorking = true
        pendingStatusCode = status
        defer {
            isWorking = false
            pendingStatusCode = nil
        }

        do {
            let applied = try await applyStatusOnce(status: status)
            currentStatus = applied
            favoriteStatus = applied.normalizedFavoriteStatus ?? favoriteStatus
            errorMessage = nil
            phase = .ready
            schedulePostWriteVerification(expectedStatus: status, expectedReason: nil)
        } catch {
            errorMessage = "상태 적용 실패: \(error.localizedDescription)"
        }
    }

    func toggleFavoriteShortcut() async {
        let target = QuickTogglePolicy.targetStatus(
            current: currentStatusCode,
            favorite: favoriteStatus,
            defaultFavorite: configuration.defaultFavoriteStatus
        )
        await setStatus(target)
    }

    func setFavoriteStatus(_ status: AppStatusCode) async {
        guard !isWorking, pendingFavoriteStatusCode == nil else { return }
        pendingFavoriteStatusCode = status
        defer { pendingFavoriteStatusCode = nil }

        do {
            let token = try await validAccessToken()
            favoriteStatus = try await api.updateFavoriteStatus(
                config: configuration,
                accessToken: token,
                status: status
            )
            errorMessage = nil
        } catch {
            errorMessage = "즐겨찾기 변경 실패: \(error.localizedDescription)"
        }
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            if isEnabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status != .notRegistered {
                    try SMAppService.mainApp.unregister()
                }
            }
            errorMessage = nil
        } catch {
            errorMessage = "자동 시작 설정 실패: \(error.localizedDescription)"
        }
        refreshLaunchAtLoginSetting()
    }

    func refreshLaunchAtLoginSetting() {
        let status = SMAppService.mainApp.status
        launchAtLoginEnabled = status == .enabled
        launchAtLoginRequiresApproval = status == .requiresApproval
    }

    func refreshStatusSnapshot() async {
        guard phase == .ready || phase == .booting else { return }
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }

        do {
            try await refreshRemoteState()
            errorMessage = nil
            if phase == .booting {
                phase = .ready
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshSchoolLifeToday() async {
        guard phase == .ready else { return }
        guard !isSchoolLifeLoading else { return }
        isSchoolLifeLoading = true
        defer { isSchoolLifeLoading = false }

        do {
            let token = try await validAccessToken()
            schoolLifeToday = try await api.fetchSchoolLifeToday(config: configuration, accessToken: token)
        } catch {
            if schoolLifeToday == nil {
                errorMessage = "오늘 정보 로드 실패: \(error.localizedDescription)"
            }
        }
    }

    func refreshVersionPolicy() async {
        guard !isVersionPolicyLoading else { return }
        isVersionPolicyLoading = true
        defer { isVersionPolicyLoading = false }

        do {
            versionPolicy = try await api.fetchMacVersionPolicy(config: configuration)
        } catch {
            // Version checks must never block ordinary app startup when the policy endpoint is unreachable.
        }
    }

    func openInBrowser() {
        NSWorkspace.shared.open(configuration.browserURL)
    }

    func openDownloadPage() {
        guard let urlText = versionPolicy?.downloadURL, let url = URL(string: urlText) else {
            NSWorkspace.shared.open(configuration.serverBaseURL.appending(path: "/mac.html"))
            return
        }
        NSWorkspace.shared.open(url)
    }

    func copyHomebrewCommand() {
        guard let command = versionPolicy?.homebrewCommand, !command.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(command, forType: .string)
        didCopyUpdateCommand = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                self.didCopyUpdateCommand = false
            }
        }
    }

    func logOut() async {
        isWorking = true
        defer { isWorking = false }
        postWriteVerificationTask?.cancel()
        postWriteVerificationTask = nil

        do {
            if let refreshToken = try keychain.load() {
                try? await api.revokeRefreshToken(config: configuration, refreshToken: refreshToken)
            }
        } catch {
            // Best effort revoke.
        }

        keychain.delete()
        accessToken = nil
        accessTokenExpiresAt = nil
        currentStatus = nil
        favoriteStatus = nil
        schoolLifeToday = nil
        profile = nil
        errorMessage = nil
        phase = .signedOut
    }

    func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func validAccessToken() async throws -> String {
        if let accessToken, let accessTokenExpiresAt, accessTokenExpiresAt > Date().addingTimeInterval(30) {
            return accessToken
        }
        guard let refreshToken = try keychain.load() else {
            phase = .signedOut
            throw APIError.transport("로그인이 필요합니다.")
        }
        let response = try await api.refreshAccessToken(config: configuration, refreshToken: refreshToken)
        try keychain.save(response.refreshToken)
        storeAccessToken(response)
        return response.accessToken
    }

    private func applyRefreshedSession(using refreshToken: String) async throws {
        let response = try await api.refreshAccessToken(config: configuration, refreshToken: refreshToken)
        try keychain.save(response.refreshToken)
        storeAccessToken(response)
        try await refreshRemoteState()
        phase = .ready
        errorMessage = nil
        Task { await refreshSchoolLifeToday() }
    }

    private func refreshRemoteState() async throws {
        let token = try await validAccessToken()
        async let profileRequest = api.fetchUserProfile(config: configuration, accessToken: token)
        async let statusRequest = api.fetchCurrentStatus(config: configuration, accessToken: token)
        async let favoriteRequest = api.fetchFavoriteStatus(config: configuration, accessToken: token)

        let loadedProfile = try await profileRequest
        let loadedStatus = try await statusRequest
        let loadedFavorite = try await favoriteRequest

        self.profile = loadedProfile
        self.currentStatus = loadedStatus
        self.favoriteStatus = loadedFavorite ?? loadedStatus.normalizedFavoriteStatus
    }

    private func applyStatusOnce(status: AppStatusCode, reason: String? = nil) async throws -> CurrentStatusPayload {
        let token = try await validAccessToken()
        let applied = try await api.updateStatus(
            config: configuration,
            accessToken: token,
            status: status,
            reason: reason,
            expectedUpdatedAt: currentStatus?.updatedAt
        )
        guard applied.matches(status: status, reason: reason) else {
            throw APIError.transport("서버 응답이 요청한 상태와 다릅니다.")
        }
        return applied
    }

    private func storeAccessToken(_ response: OAuthTokenResponse) {
        accessToken = response.accessToken
        accessTokenExpiresAt = Date().addingTimeInterval(TimeInterval(response.expiresIn))
    }

    private func schedulePostWriteVerification(expectedStatus: AppStatusCode, expectedReason: String?) {
        postWriteVerificationTask?.cancel()
        postWriteVerificationTask = Task { [weak self] in
            guard let self else { return }
            for delay in postWriteWatchdogDelaysNs {
                do {
                    try await Task.sleep(nanoseconds: delay)
                    guard !Task.isCancelled else { return }
                    let token = try await self.validAccessToken()
                    let fetched = try await self.api.fetchCurrentStatus(config: self.configuration, accessToken: token)
                    await MainActor.run {
                        self.currentStatus = fetched
                        self.favoriteStatus = fetched.normalizedFavoriteStatus ?? self.favoriteStatus
                    }
                    if fetched.matches(status: expectedStatus, reason: expectedReason) {
                        continue
                    }

                    let repaired = try await self.applyStatusOnce(status: expectedStatus, reason: expectedReason)
                    await MainActor.run {
                        self.currentStatus = repaired
                        self.favoriteStatus = repaired.normalizedFavoriteStatus ?? self.favoriteStatus
                        self.errorMessage = "서버 상태가 되돌아가 다시 적용했습니다."
                    }
                } catch is CancellationError {
                    return
                } catch {
                    await MainActor.run {
                        self.errorMessage = "상태 유지 확인 실패: \(error.localizedDescription)"
                    }
                }
            }
        }
    }
}
