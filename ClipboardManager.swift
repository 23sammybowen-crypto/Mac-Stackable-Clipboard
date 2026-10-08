import AppKit
import ApplicationServices
import Combine

final class ClipboardManager: ObservableObject {
    // Published state drives the window and menu bar UI.
    @Published private(set) var stack = TextStack()
    @Published private(set) var shortcutsActive = false
    @Published var isPaused = false
    @Published private(set) var status = "Copy some text to start your stack."
    private let pasteboard: NSPasteboard
    private var lastChangeCount: Int
    private var timer: Timer?
    private var hotkey: HotkeyManager?
    private var ignoreCopiesUntil = Date.distantPast

    var items: [ClipboardItem] { stack.items }

    init(pasteboard: NSPasteboard = .general, startMonitoring: Bool = true) {
        self.pasteboard = pasteboard
        // Start with future copies; do not import old clipboard contents.
        lastChangeCount = pasteboard.changeCount
        guard startMonitoring else { return }
        // Poll pasteboard changeCount because macOS exposes clipboard changes
        // through NSPasteboard rather than a continuous change notification.
        timer = Timer.scheduledTimer(withTimeInterval: 0.3, repeats: true) { [weak self] _ in
            self?.captureChanges()
            self?.hotkey?.start()
            self?.shortcutsActive = self?.hotkey?.isRegistered == true
        }
        // Keep shortcut recognition/delivery separate from stack state updates.
        hotkey = HotkeyManager(deliveryStatus: { [weak self] message in self?.status = message }) { [weak self] action in
            self?.handleShortcut(action) ?? .passThrough
        }
        hotkey?.start()
        shortcutsActive = hotkey?.isRegistered == true
        if hotkey?.isRegistered != true {
            status = "Enable paste access to use ⌘V, ⇧⌘V, and ⌘C+V."
        }
    }

    func captureChanges() {
        // Ignore unchanged contents, our own writes, paused capture, and copies
        // intentionally suppressed after the Command-C+V clear chord.
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard !isPaused, Date() >= ignoreCopiesUntil else { return }
        // Respect common password-manager privacy markers.
        let privateTypes = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType"]
        guard !privateTypes.contains(where: { pasteboard.availableType(from: [NSPasteboard.PasteboardType($0)]) != nil }),
              let text = pasteboard.string(forType: .string), !text.isEmpty else { return }
        stack.push(text)
        status = "Added to stack · \(items.count) item\(items.count == 1 ? "" : "s")"
    }

    @discardableResult
    func copy(_ item: ClipboardItem) -> Bool {
        // A manual copy updates the system clipboard but never consumes the stack item.
        pasteboard.clearContents()
        let success = pasteboard.setString(item.text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        status = success ? "Copied to the system clipboard. ⌘V still uses the next stack item." : "Could not write to the clipboard."
        return success
    }

    func remove(_ item: ClipboardItem) { stack.remove(item.id) }

    /// Clear app history only; leave whatever another app copied intact.
    func clear() {
        stack.clear()
        lastChangeCount = pasteboard.changeCount
        status = "Stack cleared. The system clipboard is unchanged."
    }

    func requestAccessibility() {
        // The event tap and focused-field text insertion require Accessibility access.
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        status = "Enable ClipboardStack in System Settings → Privacy & Security → Accessibility."
    }

    func handleShortcut(_ action: HotkeyManager.Action) -> HotkeyManager.Result {
        if case .clear = action {
            clear()
            // Command-C may still be finishing in the other app when V arrives.
            ignoreCopiesUntil = Date().addingTimeInterval(0.4)
            return .consume
        }
        captureChanges()
        guard !items.isEmpty else { return .passThrough }
        // Prepare the clipboard payload; HotkeyManager then delivers it to the
        // focused app and leaves every stack entry available for later pastes.
        let text: String
        switch action {
        case .pasteAll: text = stack.bottomToTopText
        case .pasteNext: text = items[0].text
        case .clear: return .consume
        }
        pasteboard.clearContents()
        let success = pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        guard success else {
            status = "Could not write to the clipboard. Stack kept for retry."
            return .consume
        }
        switch action {
        case .pasteAll:
            status = "Pasted full stack oldest to newest, separated by spaces. All items kept."
        case .pasteNext:
            status = "Sent newest item. All \(items.count) items kept."
        case .clear: break
        }
        return .paste
    }
}
