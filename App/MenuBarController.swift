import AppKit
import Combine
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate, ObservableObject {
    private var model: UsageModel?
    private var observation: AnyCancellable?
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var hostingView: NSHostingView<MenuBarPanel>?
    private var rightClickMonitor: Any?
    private var outsideClickMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private var handedOff = false
    private var uiReady = false

    static weak var current: MenuBarController?

    static func relinquishForHandoff() {
        current?.handedOff = true
        current?.close()
    }

    func bind(_ model: UsageModel) {
        guard self.model == nil else { return }
        Self.current = self
        self.model = model
        observation = model.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.sync()
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didFinishLaunchingNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.uiReady = true
                self?.sync()
            }
        }
    }

    func sync() {
        guard uiReady, !handedOff, let model else { return }
        guard model.showsMenuBarIcon else {
            close()
            return
        }
        let item = ensureStatusItem()
        applyIcon(to: item.button, snapshot: model.snapshot)
        updatePanel(snapshot: model.snapshot)
    }

    private func applyIcon(to button: NSStatusBarButton?, snapshot: UsageSnapshot) {
        guard let button else { return }
        button.title = ""
        button.imagePosition = .imageOnly
        let tone = UsageFormatting.menuBarIconTone(
            cursor: snapshot.cursorModelsPercent,
            other: snapshot.otherModelsPercent,
            onDemandPercent: snapshot.onDemand?.percent,
            onDemandUsedCents: snapshot.onDemandUsedCents
        )
        let base = NSImage(systemSymbolName: "chart.bar.fill", accessibilityDescription: "Cursor Tokens")
        switch tone {
        case .normal:
            base?.isTemplate = true
            button.image = base
        case .warning:
            button.image = tinted(base, color: .systemOrange)
        case .onDemand:
            button.image = tinted(base, color: .systemRed)
        }
    }

    private func tinted(_ image: NSImage?, color: NSColor) -> NSImage? {
        let tinted = image?.withSymbolConfiguration(NSImage.SymbolConfiguration(paletteColors: [color]))
        tinted?.isTemplate = false
        return tinted
    }

    private func ensureStatusItem() -> NSStatusItem {
        if let statusItem {
            return statusItem
        }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(handleClick(_:))
        statusItem = item
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            guard let self, let button = self.statusItem?.button, event.window == button.window else {
                return event
            }
            self.showQuitMenu()
            return nil
        }
        return item
    }

    private func updatePanel(snapshot: UsageSnapshot) {
        let host: NSHostingView<MenuBarPanel>
        if let hostingView {
            hostingView.rootView = MenuBarPanel(snapshot: snapshot)
            host = hostingView
        } else {
            host = NSHostingView(rootView: MenuBarPanel(snapshot: snapshot))
            host.sizingOptions = .intrinsicContentSize
            host.wantsLayer = true
            host.layer?.backgroundColor = NSColor.clear.cgColor
            host.layer?.cornerRadius = 16
            host.layer?.cornerCurve = .continuous
            host.layer?.masksToBounds = true
            hostingView = host
        }
        let size = panelSize(for: host)
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.level = .statusBar
            panel.isFloatingPanel = true
            panel.isMovable = false
            panel.hidesOnDeactivate = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.isOpaque = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.contentView = host
            self.panel = panel
        }
        panel?.setContentSize(size)
    }

    private func panelSize(for host: NSHostingView<MenuBarPanel>) -> NSSize {
        let fitted = host.intrinsicContentSize
        let height = fitted.height > 1 ? fitted.height : 190
        return NSSize(width: 180, height: height)
    }

    private func close() {
        panel?.orderOut(nil)
        panel = nil
        hostingView = nil
        if let rightClickMonitor {
            NSEvent.removeMonitor(rightClickMonitor)
            self.rightClickMonitor = nil
        }
        stopOutsideClickMonitor()
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
            self.activationObserver = nil
        }
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            self.statusItem = nil
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        let contextClick = event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true
        if contextClick {
            showQuitMenu()
            return
        }
        togglePanel(from: sender)
    }

    private func togglePanel(from button: NSStatusBarButton) {
        guard let panel else { return }
        if panel.isVisible {
            hidePanel()
            return
        }
        guard let window = button.window else { return }
        let size = panel.frame.size
        let buttonFrame = window.frame
        var origin = NSPoint(
            x: buttonFrame.midX - size.width / 2,
            y: buttonFrame.minY - size.height
        )
        if let screen = window.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        }
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
        startOutsideClickMonitor()
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        stopOutsideClickMonitor()
    }

    private func startOutsideClickMonitor() {
        guard outsideClickMonitor == nil else { return }
        outsideClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            guard let self, let panel = self.panel, panel.isVisible else { return event }
            if event.window == panel || event.window == self.statusItem?.button?.window {
                return event
            }
            self.hidePanel()
            return event
        }
        guard activationObserver == nil else { return }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let activated = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard activated?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            Task { @MainActor in
                self?.hidePanel()
            }
        }
    }

    private func stopOutsideClickMonitor() {
        if let outsideClickMonitor {
            NSEvent.removeMonitor(outsideClickMonitor)
            self.outsideClickMonitor = nil
        }
    }

    private func showQuitMenu() {
        hidePanel()
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()
        menu.delegate = self
        let quit = NSMenuItem(title: "Quit", action: #selector(quitIcon(_:)), keyEquivalent: "")
        quit.target = self
        menu.addItem(quit)
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height), in: button)
    }

    @objc private func quitIcon(_ sender: Any?) {
        model?.setMenuBarIconEnabled(false)
        let hasWindow = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
        if !hasWindow {
            NSApp.terminate(nil)
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
    }
}

private struct MenuBarPanel: View {
    var snapshot: UsageSnapshot

    var body: some View {
        UsageWidgetView(snapshot: snapshot)
            .frame(width: 180)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.separator.opacity(0.35), lineWidth: 1)
            }
    }
}

enum MenuBarAgentLauncher {
    static let argument = "--menu-bar-agent"

    static var isAgent: Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    /// Launch Services drops extra arguments when it starts this app, so the
    /// quitting process leaves a file the replacement reads for itself.
    static func markNextLaunch() {
        let url = markerURL()
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? Data("1".utf8).write(to: url, options: .atomic)
    }

    static func consumeStayRequest() -> Bool {
        let marked = FileManager.default.fileExists(atPath: markerURL().path)
        if marked {
            try? FileManager.default.removeItem(at: markerURL())
        }
        return isAgent || marked
    }

    static func launchReplacement(completion: @escaping () -> Void) {
        markNextLaunch()
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.arguments = [argument]
        configuration.activates = false
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            completion()
        }
    }

    private static func markerURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return base.appendingPathComponent("menu-bar-agent")
    }
}
