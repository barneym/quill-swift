import Foundation

/// A standalone syntax highlighting library.
///
/// Provides tokenization and highlighting for code blocks.
/// Designed for reuse outside of QuillSwift.
///
/// ## Usage
///
/// ```swift
/// let highlighted = SyntaxHighlighter.highlight(
///     code: "func hello() { }",
///     language: .swift,
///     theme: .defaultDark
/// )
///
/// let html = highlighted.html
/// let attributed = highlighted.attributedString
/// ```
public struct SyntaxHighlighter {

    // MARK: - Types

    /// Result of highlighting code
    public struct HighlightedCode {
        /// The original source code
        public let source: String

        /// The language used for highlighting
        public let language: Language

        /// HTML representation with span tags
        public var html: String {
            // Phase 0: Return escaped code without highlighting
            // TODO(#3): Implement actual syntax highlighting
            return "<code class=\"language-\(language.rawValue)\">\(escapeHTML(source))</code>"
        }

        /// AttributedString representation
        public var attributedString: AttributedString {
            // Phase 0: Return plain text
            // TODO(#4): Implement attributed string output
            return AttributedString(source)
        }

        private func escapeHTML(_ string: String) -> String {
            string
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
        }
    }

    /// Supported programming languages
    public enum Language: String, CaseIterable {
        case swift
        case javascript
        case typescript
        case python
        case rust
        case go
        case java
        case kotlin
        case ruby
        case php
        case csharp = "c#"
        case cpp = "c++"
        case c
        case html
        case css
        case json
        case yaml
        case markdown
        case shell
        case sql
        case plaintext

        /// Attempt to detect language from a string identifier
        public init?(identifier: String) {
            let normalized = identifier.lowercased().trimmingCharacters(in: .whitespaces)

            // Handle common aliases
            switch normalized {
            case "js":
                self = .javascript
            case "ts":
                self = .typescript
            case "py":
                self = .python
            case "rb":
                self = .ruby
            case "sh", "bash", "zsh":
                self = .shell
            case "yml":
                self = .yaml
            case "md":
                self = .markdown
            default:
                if let lang = Language(rawValue: normalized) {
                    self = lang
                } else {
                    return nil
                }
            }
        }
    }

    /// Color themes for syntax highlighting
    public enum Theme: String, CaseIterable {
        case defaultLight
        case defaultDark

        /// CSS for this theme
        public var css: String {
            // Phase 0: Basic CSS
            // TODO(#5): Implement full theme CSS
            switch self {
            case .defaultLight:
                return """
                .highlight-keyword { color: #9b2393; }
                .highlight-string { color: #c41a16; }
                .highlight-comment { color: #007400; }
                .highlight-number { color: #1c00cf; }
                """
            case .defaultDark:
                return """
                .highlight-keyword { color: #fc5fa3; }
                .highlight-string { color: #fc6a5d; }
                .highlight-comment { color: #6c7986; }
                .highlight-number { color: #d0bf69; }
                """
            }
        }
    }

    // MARK: - Highlighting

    /// Highlight source code
    ///
    /// - Parameters:
    ///   - code: The source code to highlight
    ///   - language: The programming language
    ///   - theme: The color theme to use
    /// - Returns: Highlighted code with HTML and AttributedString representations
    public static func highlight(
        code: String,
        language: Language,
        theme: Theme = .defaultDark
    ) -> HighlightedCode {
        return HighlightedCode(source: code, language: language)
    }

    /// Highlight source code, detecting language from identifier string
    ///
    /// - Parameters:
    ///   - code: The source code to highlight
    ///   - languageIdentifier: Language identifier string (e.g., "swift", "js")
    ///   - theme: The color theme to use
    /// - Returns: Highlighted code, or plaintext if language not recognized
    public static func highlight(
        code: String,
        languageIdentifier: String?,
        theme: Theme = .defaultDark
    ) -> HighlightedCode {
        let language = languageIdentifier.flatMap { Language(identifier: $0) } ?? .plaintext
        return highlight(code: code, language: language, theme: theme)
    }
}
