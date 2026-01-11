import SwiftUI

/// QuillSwift - A native macOS markdown editor
///
/// This app uses SwiftUI's DocumentGroup for document-based app architecture,
/// providing automatic file handling, recent files, and window management.
@main
struct QuillSwiftApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            // View menu additions
            CommandGroup(after: .toolbar) {
                Button("Toggle Preview") {
                    NotificationCenter.default.post(
                        name: .togglePreview,
                        object: nil
                    )
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let togglePreview = Notification.Name("togglePreview")
}
