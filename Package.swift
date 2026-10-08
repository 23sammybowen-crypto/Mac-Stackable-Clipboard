// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipboardStack",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "ClipboardStack", targets: ["ClipboardStack"])],
    targets: [
        .executableTarget(name: "ClipboardStack", path: ".",
            exclude: ["README.md", "scripts", "Tests"],
            sources: ["ClipboardStack.swift", "ClipboardItem.swift", "ClipboardManager.swift", "ContentView.swift", "HotkeyManager.swift"]),
        .testTarget(name: "ClipboardStackTests", dependencies: ["ClipboardStack"], path: "Tests")
    ]
)
