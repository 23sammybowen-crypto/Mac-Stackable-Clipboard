import Foundation

/// One captured text value. Its stable identity lets the UI remove a specific
/// copy even when the same text appears more than once.
struct ClipboardItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let copiedAt = Date()
}

/// In-memory stack of captured text. Index zero is always the newest item.
struct TextStack {
    private(set) var items: [ClipboardItem] = []
    let capacity: Int

    /// Keep capacity positive so pushes can always apply a meaningful limit.
    init(capacity: Int = 50) { self.capacity = max(1, capacity) }

    /// Join from oldest to newest for the full-stack paste shortcut.
    var bottomToTopText: String { items.reversed().map(\.text).joined(separator: " ") }

    /// Add new copies at the top and discard the oldest item when full.
    mutating func push(_ text: String) {
        guard !text.isEmpty else { return }
        items.insert(ClipboardItem(text: text), at: 0)
        if items.count > capacity { items.removeLast(items.count - capacity) }
    }

    /// Remove only the selected entry, preserving other duplicate text copies.
    mutating func remove(_ id: UUID) { items.removeAll { $0.id == id } }

    /// Empty the stack without changing the macOS system clipboard.
    mutating func clear() { items.removeAll() }
}
