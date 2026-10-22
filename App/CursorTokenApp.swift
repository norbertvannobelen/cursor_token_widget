import SwiftUI

@main
struct CursorTokenApp: App {
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

        MenuBarExtra {
            MenuBarMenu(model: model)
        } label: {
            Text(model.snapshot.menuTitle)
        }
        .menuBarExtraStyle(.menu)
    }
}
