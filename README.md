# Clipboard Stack

A native macOS text clipboard stack. Requires macOS 13+ and Xcode or Swift command-line tools.

## Build and launch

```sh
bash scripts/build-app.sh
open .build/ClipboardStack.app
```

Open `Package.swift` in Xcode to edit the app. Run `swift test` for stack behavior tests.

## Use

1. Keep the app running and copy text with **⌘C**. New copies appear at the top.
2. Focus a text field in another app and press **Command–V** to paste the newest item without removing it.
3. Repeated Command–V pastes the newest item again: copy A, B, C → paste C, C, C.
4. **Command–Shift–V** pastes the entire stack oldest to newest, with a space between items, without removing any items.
5. To clear without pasting, hold **Command+C**, press **V**, then release. This is a simultaneous chord, not Command-C followed by Command-V.

With an empty stack, normal paste shortcuts pass through to the active app. Shortcuts require Accessibility access; the app automatically activates them once permission is granted.

Automatic paste requires **System Settings → Privacy & Security → Accessibility → ClipboardStack**. Click **Enable paste access** to request it, then retry the shortcut in the destination app. If necessary, add `.build/ClipboardStack.app` using the + button in Accessibility settings. Rebuilding this locally signed app may require granting access again.

Click any item to copy it to the system clipboard without removing it. While the stack has entries, **⌘V** still takes the newest stack item. Use × to remove one item, **Clear stack** to empty the list, or **Pause capture** to stop recording. Clearing the stack leaves the system clipboard unchanged.

## First-version limits

- Plain text only, newest first, with a maximum of 50 items. Repeated copies remain separate entries.
- Captures future clipboard changes every 0.3 seconds. Very rapid copies between polls can be missed.
- History stays in memory and disappears on quit. No history files or network traffic.
- Entries marked concealed or transient by other apps are skipped. Unmarked sensitive text can still be captured.
- Copying adds entries; pasting never removes them. Only explicit clear/remove actions delete entries (or the 50-item capacity limit discards the oldest entry). macOS does not confirm whether the destination accepted a paste.
- Images, files, rich text, saved history, configurable shortcuts, and launch at login are future work.

## Flow

`ClipboardManager` watches `NSPasteboard` → creates a `ClipboardItem` → pushes it onto `TextStack`. `HotkeyManager` receives Command–V → restores the newest text to the pasteboard → forwards ordinary Command-V while keeping all entries. A keyboard event tap also handles full-stack paste and the clear chord. `ContentView` provides the list and controls; `ClipboardStack.swift` starts the window and menu bar item.
