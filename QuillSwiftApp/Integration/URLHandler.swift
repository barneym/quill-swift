import Foundation
import AppKit

/// Handles custom URL scheme for QuillSwift.
///
/// Supports the `quillswift://` URL scheme with the following actions:
/// - `quillswift://open?path=/path/to/file.md` - Open a file
/// - `quillswift://new` - Create a new document
/// - `quillswift://new?text=...` - Create a new document with initial text
@MainActor
struct URLHandler {

    // MARK: - URL Actions

    enum Action {
        case open(path: String)
        case new(text: String?)
        case unknown
    }

    // MARK: - Parsing

    /// Parse a URL into an action
    static func parse(_ url: URL) -> Action {
        guard url.scheme?.lowercased() == "quillswift" else {
            return .unknown
        }

        let host = url.host?.lowercased() ?? ""
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        switch host {
        case "open":
            // quillswift://open?path=/path/to/file.md
            if let path = queryItems.first(where: { $0.name == "path" })?.value {
                return .open(path: path)
            }
            return .unknown

        case "new":
            // quillswift://new or quillswift://new?text=Hello
            let text = queryItems.first(where: { $0.name == "text" })?.value
            return .new(text: text)

        default:
            // Try to interpret the path as a file path
            // quillswift:///path/to/file.md
            if !url.path.isEmpty && url.path != "/" {
                return .open(path: url.path)
            }
            return .unknown
        }
    }

    // MARK: - Execution

    /// Handle a URL action
    static func handle(_ url: URL) {
        let action = parse(url)

        switch action {
        case .open(let path):
            openFile(at: path)

        case .new(let text):
            createNewDocument(with: text)

        case .unknown:
            print("Unknown URL action: \(url)")
        }
    }

    // MARK: - Private Methods

    private static func openFile(at path: String) {
        let fileURL = URL(fileURLWithPath: path)

        // Verify file exists
        guard FileManager.default.fileExists(atPath: path) else {
            print("File not found: \(path)")
            return
        }

        // Open the file using NSWorkspace (will be handled by DocumentGroup)
        NSWorkspace.shared.open(fileURL)
    }

    private static func createNewDocument(with text: String?) {
        if let text = text {
            // Post notification to create new document with text
            NotificationCenter.default.post(
                name: .createNewDocumentWithText,
                object: nil,
                userInfo: ["text": text]
            )
        } else {
            // Use standard new document command
            NSApp.sendAction(#selector(NSDocumentController.newDocument(_:)), to: nil, from: nil)
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when a new document should be created with initial text
    static let createNewDocumentWithText = Notification.Name("createNewDocumentWithText")
}
