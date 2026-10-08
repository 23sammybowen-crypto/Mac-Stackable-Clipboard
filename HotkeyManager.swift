import AppKit
import ApplicationServices

/// Prepares the clipboard before forwarding the user's original key event.
/// Never suppress ordinary paste in order to inject a second keystroke later.
final class HotkeyManager {
    // `paste` means the manager has prepared clipboard contents and the original
    // shortcut should be delivered; `consume` suppresses the key entirely.
    enum Action: Equatable { case pasteNext, pasteAll, clear }
    enum Result { case passThrough, paste, consume }
    private let action: (Action) -> Result
    private let postEvent: (CGEvent, pid_t) -> Void
    private let insertText: (String) -> Bool
    private let readClipboard: () -> String?
    private let deliveryStatus: (String) -> Void
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var cIsDown = false
    private var consumeVRelease = false
    var isRegistered: Bool {
        guard let tap else { return false }
        return CGEvent.tapIsEnabled(tap: tap)
    }

    init(postEvent: @escaping (CGEvent, pid_t) -> Void = { $0.postToPid($1) },
         insertText: @escaping (String) -> Bool = { HotkeyManager.insertIntoFocusedTextElement($0) },
         readClipboard: @escaping () -> String? = { NSPasteboard.general.string(forType: .string) },
         deliveryStatus: @escaping (String) -> Void = { _ in },
         action: @escaping (Action) -> Result) {
        self.postEvent = postEvent
        self.insertText = insertText
        self.readClipboard = readClipboard
        self.deliveryStatus = deliveryStatus
        self.action = action
    }

    func start() {
        // A session event tap sees shortcuts system-wide. Do not register before
        // Accessibility permission is granted; start() may be retried while polling.
        guard tap == nil, AXIsProcessTrusted() else { return }
        let mask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
            tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(mask), callback: { proxy, type, event, context in
                guard let context else { return Unmanaged.passUnretained(event) }
                return Unmanaged<HotkeyManager>.fromOpaque(context).takeUnretainedValue().handle(type, event, proxy: proxy)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap {
            source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
        }
    }

    func handle(_ type: CGEventType, _ event: CGEvent, proxy: CGEventTapProxy? = nil) -> Unmanaged<CGEvent>? {
        // macOS can disable event taps temporarily; reset chord state and re-enable.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            cIsDown = false
            consumeVRelease = false
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        if type == .flagsChanged {
            // Track whether Command-C was pressed before the following V keydown.
            if !event.flags.contains(.maskCommand) { cIsDown = false }
            return Unmanaged.passUnretained(event)
        }
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if key == 8 { cIsDown = type == .keyDown }
        guard key == 9 else { return Unmanaged.passUnretained(event) }
        if type == .keyUp {
            defer { consumeVRelease = false }
            if consumeVRelease { return nil }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown, event.flags.contains(.maskCommand),
              !event.flags.contains(.maskAlternate), !event.flags.contains(.maskControl) else {
            return Unmanaged.passUnretained(event)
        }
        let requested: Action = cIsDown ? .clear : (event.flags.contains(.maskShift) ? .pasteAll : .pasteNext)
        switch action(requested) {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .consume:
            consumeVRelease = true
            return nil
        case .paste:
            // Prefer replacing/inserting text through Accessibility, which avoids
            // synthesizing a second shortcut that the target app might miss.
            let text = readClipboard() ?? ""
            if !text.isEmpty, insertText(text) {
                deliveryStatus("Inserted text directly into the focused field.")
                consumeVRelease = true
                return nil
            }
            // If the focused app has no editable Accessibility text element, keep
            // the prepared clipboard and send a plain Command-V directly to it.
            let targetPID = Self.focusedApplicationPID()
            guard targetPID > 0, targetPID != ProcessInfo.processInfo.processIdentifier,
                  let source = CGEventSource(stateID: .combinedSessionState),
                  let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
                deliveryStatus("Clipboard is ready; no editable text field accepted the paste.")
                consumeVRelease = true
                return nil
            }
            for replacement in [down, up] {
                replacement.flags = .maskCommand
                var character: UniChar = 0x76
                replacement.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
            }
            consumeVRelease = true
            postEvent(down, targetPID)
            postEvent(up, targetPID)
            deliveryStatus("Sent Command-V directly to the focused app.")
            return nil
        }
    }

    private static func focusedApplicationPID() -> pid_t {
        // Used only by the fallback that posts Command-V directly to the target app.
        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString,
                                            &focusedValue) == .success,
              let focusedValue else { return 0 }
        let application = focusedValue as! AXUIElement
        var pid: pid_t = 0
        guard AXUIElementGetPid(application, &pid) == .success else { return 0 }
        return pid
    }

    private static func insertIntoFocusedTextElement(_ text: String) -> Bool {
        // Setting selected text replaces the current selection, or inserts at the cursor.
        let system = AXUIElementCreateSystemWide()
        var focusedAppValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedApplicationAttribute as CFString,
                                            &focusedAppValue) == .success,
              let focusedAppValue else { return false }
        let application = focusedAppValue as! AXUIElement
        var elementValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXFocusedUIElementAttribute as CFString,
                                            &elementValue) == .success,
              let elementValue else { return false }
        let element = elementValue as! AXUIElement
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, kAXSelectedTextAttribute as CFString,
                                             &settable) == .success, settable.boolValue else { return false }
        return AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString,
                                            text as CFTypeRef) == .success
    }

    deinit {
        // Remove run-loop resources and invalidate the system event tap on shutdown.
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
    }
}
