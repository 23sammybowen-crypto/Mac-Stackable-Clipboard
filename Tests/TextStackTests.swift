import XCTest
@testable import ClipboardStack

final class TextStackTests: XCTestCase {
    // The full-stack representation is oldest-to-newest even though display order is newest-first.
    func testFullStackUsesBottomToTopOrder() {
        var stack = TextStack()
        ["first", "second", "third"].forEach { stack.push($0) }
        XCTAssertEqual(stack.bottomToTopText, "first second third")
        stack.remove(stack.items[0].id)
        XCTAssertEqual(stack.bottomToTopText, "first second")
        stack.clear()
        XCTAssertEqual(stack.bottomToTopText, "")
    }

    // Capacity limits should retain the newest copies.
    func testNewestFirstAndCapacity() {
        var stack = TextStack(capacity: 2)
        ["one", "two", "three"].forEach { stack.push($0) }
        XCTAssertEqual(stack.items.map(\.text), ["three", "two"])
    }

    // Duplicate text remains independently removable, and empty text is ignored.
    func testRepeatedCopiesHaveIndependentIdentity() {
        var stack = TextStack()
        stack.push("same")
        stack.push("same")
        stack.remove(stack.items[0].id)
        XCTAssertEqual(stack.items.map(\.text), ["same"])
        stack.push("")
        XCTAssertEqual(stack.items.count, 1)
        stack.clear()
        XCTAssertTrue(stack.items.isEmpty)
    }
}
