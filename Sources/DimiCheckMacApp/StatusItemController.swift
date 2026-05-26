import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController {
    private let model: AppModel
    private let statusItem: NSStatusItem
    private let popover: NSPopover
    private var cancellables = Set<AnyCancellable>()

    init(model: AppModel) {
        self.model = model
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.popover = NSPopover()
        configurePopover()
        configureStatusItem()
        bind()
        updateStatusItemAppearance()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 420)
        popover.contentViewController = NSHostingController(rootView: MenuBarContentView(model: model))
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(handleStatusItemPress(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    private func bind() {
        model.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.updateStatusItemAppearance()
                }
            }
            .store(in: &cancellables)
    }

    private func updateStatusItemAppearance() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: model.menuSymbolName, accessibilityDescription: "DimiCheck")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "DimiCheck · \(model.currentStatusLabel)"
    }

    @objc
    private func handleStatusItemPress(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover(relativeTo: sender)
            return
        }

        switch event.type {
        case .rightMouseUp:
            Task { await model.toggleFavoriteShortcut() }
        default:
            togglePopover(relativeTo: sender)
        }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            Task { await model.refreshStatusSnapshot() }
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.becomeKey()
        }
    }
}
