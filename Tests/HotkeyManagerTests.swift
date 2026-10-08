import XCTest
import AppKit
@testable import ClipboardStack

final class HotkeyManagerTests: XCTestCase {
    // Build key events in the same shape the event-tap handler receives.
    private func event(_ type: CGEventType, key: CGKeyCode = 9,
                       flags: CGEventFlags = [.maskCommand, .maskShift]) -> CGEvent {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: type == .keyDown)!
        event.flags = flags
        var character: UniChar = flags.contains(.maskShift) ? 0x56 : 0x76
        event.keyboardSetUnicodeString(stringLength: 1, unicodeString: &character)
        return event
    }

    // The original paste event is consumed after direct text insertion succeeds.
    func testOrdinaryPasteForwardsOriginalDownAndUpImmediately() {
        var calls = 0
        let manager = HotkeyManager(insertText: { _ in true }) {
            guard case .pasteNext = $0 else { XCTFail("Expected single paste"); return .passThrough }
            calls += 1
            return .paste
        }
        for type in [CGEventType.keyDown, .keyUp] {
            let original = event(type, flags: .maskCommand)
            XCTAssertNil(manager.handle(type, original), "Paste into the focused field")
        }
        XCTAssertEqual(calls, 1)
    }

    // Full-stack paste inserts the already joined clipboard string without posting another key event.
    func testFullPasteInsertsSpaceJoinedClipboardAndConsumesShiftV() {
        var calls = 0
        var posted: [CGEvent] = []
        var pastedText: String?
        let manager = HotkeyManager(postEvent: { event, _ in posted.append(event) },
                                    insertText: { pastedText = $0; return true },
                                    readClipboard: { "first second third" }) {
            guard case .pasteAll = $0 else { XCTFail("Expected full paste"); return .passThrough }
            calls += 1
            return .paste
        }
        let down = event(.keyDown)
        XCTAssertNil(manager.handle(.keyDown, down))
        XCTAssertEqual(pastedText, "first second third")
        XCTAssertTrue(posted.isEmpty, "Focused text insertion should avoid another keyboard event")
        let release = event(.keyUp)
        XCTAssertNil(manager.handle(.keyUp, release))
        XCTAssertEqual(calls, 1)
    }

    // With no stack action, the user's original shortcut is allowed through.
    func testEmptyStackPassesOriginalShortcutThrough() {
        let manager = HotkeyManager { _ in .passThrough }
        let original = event(.keyDown)
        XCTAssertNotNil(manager.handle(.keyDown, original))
        XCTAssertEqual(original.flags, [.maskCommand, .maskShift])
    }

    // Command-C followed by V clears the app stack and suppresses that V keystroke.
    func testCommandCVConsumesChordWithoutPaste() {
        var cleared = false
        let manager = HotkeyManager {
            if case .clear = $0 { cleared = true }
            return .consume
        }
        let copy = event(.keyDown, key: 8, flags: .maskCommand)
        let down = event(.keyDown, flags: .maskCommand)
        let up = event(.keyUp, flags: .maskCommand)
        _ = manager.handle(.keyDown, copy)
        XCTAssertNil(manager.handle(.keyDown, down))
        XCTAssertTrue(cleared)
        XCTAssertNil(manager.handle(.keyUp, up))
    }
}
