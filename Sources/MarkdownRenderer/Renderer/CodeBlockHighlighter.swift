import Foundation
import Highlightr

#if os(macOS)
import AppKit
#endif

/// Provides syntax highlighting for code blocks using Highlightr.
///
/// This generates HTML with inline color styles for use in WebView preview.
///
/// Note: Highlightr uses highlight.js internally and provides robust
/// language detection and highlighting for 180+ languages.
public class CodeBlockHighlighter {

    // MARK: - Properties

    /// The Highlightr instance for light theme
    private var highlightrLight: Highlightr?

    /// The Highlightr instance for dark theme
    private var highlightrDark: Highlightr?

    /// Shared singleton instance
    public static let shared = CodeBlockHighlighter()

    // MARK: - Initialization

    private init() {
        // Initialize light theme highlighter
        if let instance = Highlightr() {
            _ = instance.setTheme(to: "github")
            highlightrLight = instance
        }

        // Initialize dark theme highlighter
        if let instance = Highlightr() {
            _ = instance.setTheme(to: "github-dark")
            highlightrDark = instance
        }
    }

    // MARK: - Highlighting

    /// Highlight code and return HTML with inline color styles
    ///
    /// - Parameters:
    ///   - code: The source code to highlight
    ///   - language: The language name (e.g., "swift", "python", "javascript")
    ///               If nil or empty, auto-detection is used
    ///   - isDark: Whether to use dark theme colors
    /// - Returns: HTML string with highlighted spans
    public func highlightToHTML(_ code: String, language: String?, isDark: Bool = false) -> String {
        let highlightr = isDark ? highlightrDark : highlightrLight

        guard let highlightr = highlightr else {
            return escapeHTML(code)
        }

        let lang = language?.lowercased().trimmingCharacters(in: .whitespaces)
        let languageToUse = (lang?.isEmpty ?? true) ? nil : lang

        guard let attributedResult = highlightr.highlight(code, as: languageToUse) else {
            return escapeHTML(code)
        }

        return attributedStringToHTML(attributedResult)
    }

    /// Get list of available themes
    public func availableThemes() -> [String] {
        highlightrLight?.availableThemes() ?? []
    }

    /// Get list of supported languages
    public func supportedLanguages() -> [String] {
        highlightrLight?.supportedLanguages() ?? []
    }

    // MARK: - Private Helpers

    private func escapeHTML(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Convert NSAttributedString with syntax highlighting to HTML with inline styles
    private func attributedStringToHTML(_ attributedString: NSAttributedString) -> String {
        var html = ""
        let fullRange = NSRange(location: 0, length: attributedString.length)

        attributedString.enumerateAttributes(in: fullRange, options: []) { attrs, range, _ in
            let substring = (attributedString.string as NSString).substring(with: range)
            let escapedText = escapeHTML(substring)

            #if os(macOS)
            // Build style attributes
            var styles: [String] = []

            if let color = attrs[.foregroundColor] as? NSColor {
                let hexColor = colorToHex(color)
                styles.append("color:\(hexColor)")
            }

            if let font = attrs[.font] as? NSFont {
                // Check for bold/italic
                let traits = NSFontManager.shared.traits(of: font)
                if traits.contains(.boldFontMask) {
                    styles.append("font-weight:bold")
                }
                if traits.contains(.italicFontMask) {
                    styles.append("font-style:italic")
                }
            }

            if !styles.isEmpty {
                html += "<span style=\"\(styles.joined(separator: ";"))\">\(escapedText)</span>"
            } else {
                html += escapedText
            }
            #else
            html += escapedText
            #endif
        }

        return html
    }

    #if os(macOS)
    /// Convert NSColor to hex string
    private func colorToHex(_ color: NSColor) -> String {
        // Convert to sRGB color space for consistent hex values
        guard let rgbColor = color.usingColorSpace(.sRGB) else {
            // Fallback for colors that can't be converted
            return "#000000"
        }

        let r = Int(rgbColor.redComponent * 255)
        let g = Int(rgbColor.greenComponent * 255)
        let b = Int(rgbColor.blueComponent * 255)

        return String(format: "#%02X%02X%02X", r, g, b)
    }
    #endif
}
