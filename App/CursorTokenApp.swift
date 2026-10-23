import AppKit
import ServiceManagement
import SwiftUI

@main
struct CursorTokenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: UsageModel

    init() {
        let model = UsageModel()
        _model = StateObject(wrappedValue: model)
        model.start()
    }

    var body: some Scene {
        Window("Cursor Tokens", id: "main") {
            ContentView()
                .environmentObject(model)
        }
        .defaultSize(width: 420, height: 560)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(model.isRefreshing)
            }
        }

        MenuBarExtra(isInserted: menuBarInserted) {
            VStack(alignment: .leading, spacing: 6) {
                UsageWidgetView(snapshot: model.snapshot)
                Button("Quit") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding(.bottom, 8)
            .frame(width: 180)
        } label: {
            Label(model.snapshot.menuTitle, systemImage: "chart.bar.fill")
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarInserted: Binding<Bool> {
        Binding(
            get: { model.showsMenuBarIcon },
            set: { newValue in
                guard newValue != model.showsMenuBarIcon else { return }
                DispatchQueue.main.async {
                    self.model.showsMenuBarIcon = newValue
                }
            }
        )
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if ProcessInfo.processInfo.arguments.contains("--menu-bar-off") {
            try? SMAppService.mainApp.unregister()
            NSApp.terminate(nil)
            return
        }
        guard Self.shouldStayInMenuBar else { return }
        NSApp.setActivationPolicy(.accessory)
        DispatchQueue.main.async {
            for window in NSApp.windows where window.canBecomeMain {
                window.close()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !MenuBarPreference.isEnabled()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSApp.setActivationPolicy(.regular)
        if !flag {
            for window in NSApp.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    private static var shouldStayInMenuBar: Bool {
        if ProcessInfo.processInfo.arguments.contains("--menu-bar") {
            return true
        }
        return launchedAsLoginItem
    }

    private static var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication,
              let reason = event.paramDescriptor(forKeyword: keyAEPropData) else {
            return false
        }
        return reason.enumCodeValue == keyAELaunchedAsLogInItem
    }
}
