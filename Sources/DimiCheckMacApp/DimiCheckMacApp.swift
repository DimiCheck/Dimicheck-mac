import AppKit
import SwiftUI

@MainActor
final class DimiCheckAppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusController = StatusItemController(model: model)
        model.start()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        OAuthSessionCoordinator.shared.handleIncoming(urls: urls)
    }
}

@main
struct DimiCheckMacApp: App {
    @NSApplicationDelegateAdaptor(DimiCheckAppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
