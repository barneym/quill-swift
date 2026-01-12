import SwiftUI
import UniformTypeIdentifiers

/// A markdown document that can be opened, edited, and saved.
///
/// Conforms to `FileDocument` for integration with SwiftUI's DocumentGroup.
/// The document handles file reading and writing while maintaining the
/// text content for editing.
struct MarkdownDocument: FileDocument {

    // MARK: - Properties

    /// The markdown text content
    var text: String

    // MARK: - FileDocument Conformance

    /// Supported content types for this document
    static var readableContentTypes: [UTType] {
        [.markdown, .plainText]
    }

    /// Writable content types (same as readable)
    static var writableContentTypes: [UTType] {
        [.markdown]
    }

    // MARK: - Initialization

    /// Creates a new empty document
    init() {
        self.text = ""
    }

    /// Creates a document with initial text
    init(text: String) {
        self.text = text
    }

    /// Reads a document from a file
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }

        // Try UTF-8 first, fall back to other encodings
        if let text = String(data: data, encoding: .utf8) {
            self.text = text
        } else if let text = String(data: data, encoding: .utf16) {
            self.text = text
        } else if let text = String(data: data, encoding: .isoLatin1) {
            self.text = text
        } else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
    }

    /// Writes the document to a file
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = text.data(using: .utf8) else {
            throw CocoaError(.fileWriteInapplicableStringEncoding)
        }
        return FileWrapper(regularFileWithContents: data)
    }
}

// MARK: - UTType Extension

extension UTType {
    /// Markdown file type
    static var markdown: UTType {
        UTType(filenameExtension: "md") ?? .plainText
    }
}
