import XCTest
import AppKit
@testable import ClipboardStack

final class ClipboardManagerTests: XCTestCase {
    // Both paste actions update clipboard contents while retaining the captured history.
    func testRepeatedSingleAndFullPastesPreserveEveryItem() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let manager = ClipboardManager(pasteboard: board, startMonitoring: false)
        for text in ["first", "second", "third"] {
            board.clearContents()
            board.setString(text, forType: .string)
            manager.captureChanges()
        }
        let original = manager.items
        for _ in 0..<2 {
            _ = manager.handleShortcut(.pasteNext)
            XCTAssertEqual(board.string(forType: .string), "third")
            XCTAssertEqual(manager.items, original)
            _ = manager.handleShortcut(.pasteAll)
            XCTAssertEqual(board.string(forType: .string), "first second third")
            XCTAssertEqual(manager.items, original)
            manager.captureChanges()
            XCTAssertEqual(manager.items, original, "Our own paste must not create a new entry")
        }
        _ = manager.handleShortcut(.clear)
        XCTAssertTrue(manager.items.isEmpty)
    }

    // Clicking a saved row copies its text without removing or recapturing it.
    func testCopyingExistingItemDoesNotRemoveOrDuplicateIt() {
        let board = NSPasteboard.withUniqueName()
        defer { board.releaseGlobally() }
        let manager = ClipboardManager(pasteboard: board, startMonitoring: false)
        board.clearContents()
        board.setString("keep me", forType: .string)
        manager.captureChanges()
        let original = manager.items
        guard let item = original.first else { return XCTFail("Copy was not captured") }
        XCTAssertTrue(manager.copy(item))
        manager.captureChanges()
        XCTAssertEqual(manager.items, original)
    }
}
