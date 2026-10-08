import SwiftUI

@main
struct ClipboardStackApp: App {
    // Share one manager between the main window and menu bar commands.
    @StateObject private var clipboard = ClipboardManager()

    var body: some Scene {
        // Main window for inspecting, copying, and managing stack entries.
        WindowGroup("Clipboard Stack") {
            ContentView(clipboard: clipboard)
        }
        .defaultSize(width: 480, height: 570)

        // Persistent menu bar entry provides quick status and stack controls.
        MenuBarExtra("Clipboard Stack", systemImage: "square.stack.3d.up") {
            Text("\(clipboard.items.count) items in stack")
            Text("Paste newest: ⌘V")
            Text("Paste all (oldest first): ⇧⌘V")
            Text("Clear: hold ⌘C, press V")
            Divider()
            Toggle("Pause capture", isOn: $clipboard.isPaused)
            Button("Clear stack") { clipboard.clear() }
                .disabled(clipboard.items.isEmpty)
            Divider()
            Button("Quit Clipboard Stack") { NSApplication.shared.terminate(nil) }
        }
    }
}
