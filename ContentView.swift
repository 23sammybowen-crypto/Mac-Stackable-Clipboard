import SwiftUI

struct ContentView: View {
    @ObservedObject var clipboard: ClipboardManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            // App title, quick description, and current stack size.
            // Keep the most common action prominent and show its shortcut.
            HStack {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.largeTitle).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Clipboard Stack").font(.title2.bold())
                    Text("Copy a few things. Paste without losing your stack.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(clipboard.items.count)/50")
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }

            HStack {
                Label("Paste newest · keep stack", systemImage: "keyboard")
                Spacer()
                Text("⌘V").font(.headline.monospaced())
            }
            .padding(12).background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            // Explain the two less common global shortcuts.
            Text("⇧⌘V  Paste all, oldest first, separated by spaces    ·    ⌘C+V  Clear stack")
                .font(.caption).foregroundStyle(.secondary)

            if clipboard.items.isEmpty {
                // Empty state tells the user how new entries get into the stack.
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard").font(.system(size: 42)).foregroundStyle(.secondary)
                    Text("Your stack is ready").font(.headline)
                    Text("Copy text with ⌘C in any app.\nIt will appear here automatically.")
                        .multilineTextAlignment(.center).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Show newest first; item buttons copy without removing entries.
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(clipboard.items.enumerated()), id: \.element.id) { index, item in
                            HStack(alignment: .top, spacing: 12) {
                                Text(index == 0 ? "TOP" : "\(index + 1)")
                                    .font(.caption2.bold()).foregroundStyle(index == 0 ? Color.accentColor : .secondary)
                                    .frame(width: 34).padding(.top, 4)
                                Button { clipboard.copy(item) } label: {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(item.text).lineLimit(3).multilineTextAlignment(.leading)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("\(item.text.count) characters · click to copy")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }.contentShape(Rectangle())
                                }.buttonStyle(.plain).help("Copy this item without removing it")
                                Button { clipboard.remove(item) } label: {
                                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                                }.buttonStyle(.plain).help("Remove item")
                            }
                            .padding(12)
                            .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
            }

            Divider()
            // Capture controls and diagnostics help users see permission/shortcut state.
            HStack {
                Toggle("Pause capture", isOn: $clipboard.isPaused).toggleStyle(.checkbox)
                Spacer()
                Button("Clear stack") { clipboard.clear() }.disabled(clipboard.items.isEmpty)
            }
            Label(clipboard.shortcutsActive ? "Keyboard shortcuts active" : "Keyboard shortcuts inactive — enable Accessibility access",
                  systemImage: clipboard.shortcutsActive ? "checkmark.circle" : "exclamationmark.triangle")
                .font(.caption).foregroundStyle(clipboard.shortcutsActive ? Color.secondary : Color.orange)
            Text(clipboard.status).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Text("Text only · stored in memory until you quit")
                Spacer()
                Button("Enable paste access") { clipboard.requestAccessibility() }.buttonStyle(.link)
            }.font(.caption2).foregroundStyle(.secondary)
        }
        .padding(22).frame(minWidth: 440, minHeight: 470)
    }
}
