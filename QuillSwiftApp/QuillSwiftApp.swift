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
                .handlesExternalEvents(preferring: ["quillswift"], allowing: ["*"])
                .onOpenURL { url in
                    URLHandler.handle(url)
                }
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

            // File menu export commands
            CommandGroup(after: .importExport) {
                Divider()

                Button("Export as HTML...") {
                    NotificationCenter.default.post(
                        name: .exportHTML,
                        object: nil
                    )
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])

                Button("Export as PDF...") {
                    NotificationCenter.default.post(
                        name: .exportPDF,
                        object: nil
                    )
                }
                .keyboardShortcut("e", modifiers: [.command, .option])

                Divider()

                Button("Copy as HTML") {
                    NotificationCenter.default.post(
                        name: .copyAsHTML,
                        object: nil
                    )
                }
                .keyboardShortcut("c", modifiers: [.command, .option])
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

            // Format menu
            CommandMenu("Format") {
                // Text formatting
                Button("Bold") {
                    performFormattingCommand(.bold)
                }
                .keyboardShortcut("b", modifiers: .command)

                Button("Italic") {
                    performFormattingCommand(.italic)
                }
                .keyboardShortcut("i", modifiers: .command)

                Button("Strikethrough") {
                    performFormattingCommand(.strikethrough)
                }
                .keyboardShortcut("u", modifiers: [.command, .shift])

                Button("Inline Code") {
                    performFormattingCommand(.inlineCode)
                }
                .keyboardShortcut("`", modifiers: .command)

                Divider()

                // Links and images
                Button("Insert Link") {
                    performFormattingCommand(.link)
                }
                .keyboardShortcut("k", modifiers: .command)

                Button("Insert Image") {
                    performFormattingCommand(.image)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Divider()

                // Headings
                Menu("Heading") {
                    Button("Heading 1") {
                        performFormattingCommand(.heading(level: 1))
                    }
                    .keyboardShortcut("1", modifiers: .command)

                    Button("Heading 2") {
                        performFormattingCommand(.heading(level: 2))
                    }
                    .keyboardShortcut("2", modifiers: .command)

                    Button("Heading 3") {
                        performFormattingCommand(.heading(level: 3))
                    }
                    .keyboardShortcut("3", modifiers: .command)

                    Button("Heading 4") {
                        performFormattingCommand(.heading(level: 4))
                    }
                    .keyboardShortcut("4", modifiers: .command)

                    Button("Heading 5") {
                        performFormattingCommand(.heading(level: 5))
                    }
                    .keyboardShortcut("5", modifiers: .command)

                    Button("Heading 6") {
                        performFormattingCommand(.heading(level: 6))
                    }
                    .keyboardShortcut("6", modifiers: .command)

                    Divider()

                    Button("Remove Heading") {
                        performFormattingCommand(.removeHeading)
                    }
                    .keyboardShortcut("0", modifiers: .command)
                }

                Divider()

                // Block formatting
                Button("Blockquote") {
                    performFormattingCommand(.blockquote)
                }
                .keyboardShortcut("'", modifiers: .command)

                Button("Bulleted List") {
                    performFormattingCommand(.unorderedList)
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])

                Button("Checkbox") {
                    performFormattingCommand(.checkbox)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Code Block") {
                    performFormattingCommand(.codeBlock)
                }
                .keyboardShortcut("`", modifiers: [.command, .shift])
            }
        }

        // Settings window (Cmd+,)
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }

    /// Send a find panel action to the first responder
    private func performFindPanelAction(_ action: NSTextFinder.Action) {
        guard let window = NSApp.keyWindow,
              let responder = window.firstResponder as? NSTextView else {
            return
        }
        responder.performFindPanelAction(action)
    }

    /// Send a formatting command to the first responder
    private func performFormattingCommand(_ command: FormattingCommand) {
        guard let window = NSApp.keyWindow,
              let responder = window.firstResponder as? NSTextView else {
            return
        }
        responder.applyFormatting(command)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let togglePreview = Notification.Name("togglePreview")
    static let exportHTML = Notification.Name("exportHTML")
    static let exportPDF = Notification.Name("exportPDF")
    static let copyAsHTML = Notification.Name("copyAsHTML")
}
