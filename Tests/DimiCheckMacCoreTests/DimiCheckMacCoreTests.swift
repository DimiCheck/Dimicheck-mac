import DimiCheckMacCore
import Testing

struct DimiCheckMacCoreTests {
    @Test
    func pkceChallengeUsesS256Base64URL() throws {
        let verifier = "dimicheck-mac-verifier"
        let challenge = PKCEChallenge.makeCodeChallenge(from: verifier)
        #expect(challenge == "bkCVWczJtEl5yNt1ZtXfiQu5c6qAhowoD7mVjsUu0-w")
    }

    @Test
    func quickToggleMovesOutToFavoriteAndBackToClassroom() {
        #expect(QuickTogglePolicy.targetStatus(current: .section, favorite: .project) == .project)
        #expect(QuickTogglePolicy.targetStatus(current: .hallway, favorite: .project) == .section)
        #expect(QuickTogglePolicy.targetStatus(current: nil, favorite: nil, defaultFavorite: .toilet) == .toilet)
    }

    @Test
    func currentStatusPayloadMatchesExpectedStatusAndReason() {
        let hallway = CurrentStatusPayload(
            grade: 2,
            section: 4,
            number: 7,
            statusCode: "hallway",
            statusLabel: "복도",
            reason: nil,
            favoriteStatus: "project"
        )
        #expect(hallway.matches(status: .hallway))
        #expect(!hallway.matches(status: .project))

        let etc = CurrentStatusPayload(
            grade: 2,
            section: 4,
            number: 7,
            statusCode: "etc",
            statusLabel: "기타",
            reason: "보건실",
            favoriteStatus: nil
        )
        #expect(etc.matches(status: .etc, reason: "보건실"))
        #expect(!etc.matches(status: .etc, reason: "상담"))
    }

    @Test
    func versionPolicyClassifiesOptionalAndRequiredUpdates() {
        let policy = MacVersionPolicyPayload(
            latestVersion: "0.1.3",
            minSupportedVersion: "0.1.2",
            downloadURL: "https://dimicheck.com/mac.html",
            homebrewCommand: "brew upgrade --cask dimicheck/dimicheck-mac",
            message: "업데이트"
        )

        #expect(VersionPolicy.state(currentVersion: "0.1.1", policy: policy) == .required)
        #expect(VersionPolicy.state(currentVersion: "0.1.2", policy: policy) == .optional)
        #expect(VersionPolicy.state(currentVersion: "0.1.3", policy: policy) == .current)
        #expect(VersionPolicy.state(currentVersion: "0.1.10", policy: policy) == .current)
        #expect(VersionPolicy.state(currentVersion: "0.1.3-beta", policy: policy) == .current)
        #expect(VersionPolicy.state(currentVersion: "0.1.3", policy: nil) == .unknown)
    }
}
