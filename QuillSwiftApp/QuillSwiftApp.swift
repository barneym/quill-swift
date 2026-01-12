import SwiftUI
import AppKit

/// QuillSwift - A native macOS markdown editor
///
/// This app uses SwiftUI's DocumentGroup for document-based app architecture,
/// providing automatic file handling, recent files, and window management.
@main
struct QuillSwiftApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document, fileURL: file.fileURL)
        }
        .commands {
            // Include standard text editing commands
            TextEditingCommands()

            // Find menu commands
            CommandGroup(after: .textEditing) {
                Divider()

                Button("Find...") {
                    performFindPanelAction(.showFindInterface)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Find and Replace...") {
                    performFindPanelAction(.showReplaceInterface)
                }
                .keyboardShortcut("f", modifiers: [.command, .option])

                Button("Find Next") {
                    performFindPanelAction(.nextMatch)
                }
                .keyboardShortcut("g", modifiers: .command)

                Button("Find Previous") {
                    performFindPanelAction(.previousMatch)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                Button("Use Selection for Find") {
                    performFindPanelAction(.setSearchString)
                }
                .keyboardShortcut("e", modifiers: .command)

                Divider()
            }

            // View menu additions
            CommandGroup(after: .toolbar) {
                Button("Toggle Preview") {
                    NotificationCenter.default.post(
                        name: .togglePreview,
                        object: nil
                    )
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }

    /// Send a find panel action to the first responder
    private func performFindPanelAction(_ action: NSTextFinder.Action) {
        guard let window = NSApp.keyWindow,
              let responder = window.firstResponder as? NSTextView else {
            return
        }
        responder.performFindPanelAction(action)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let togglePreview = Notification.Name("togglePreview")
}
