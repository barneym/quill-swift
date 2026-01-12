import AppKit

/// Applies syntax highlighting to markdown text in an NSTextStorage.
///
/// Uses regex patterns to identify markdown elements and apply
/// appropriate text attributes (colors, fonts, styles).
class MarkdownHighlighter {

    // MARK: - Properties

    /// The color theme to use for highlighting
    var theme: EditorTheme

    /// Cached regex patterns for performance
    private var patterns: [MarkdownPattern] = []

    // MARK: - Initialization

    init(theme: EditorTheme) {
        self.theme = theme
        self.patterns = Self.compilePatterns()
    }

    // MARK: - Highlighting

    /// Apply syntax highlighting to the entire text storage
    func highlight(_ textStorage: NSTextStorage) {
        let fullRange = NSRange(location: 0, length: textStorage.length)
        highlightRange(fullRange, in: textStorage)
    }

    /// Apply syntax highlighting to a specific range
    func highlightRange(_ range: NSRange, in textStorage: NSTextStorage) {
        guard range.length > 0 else { return }

        let string = textStorage.string
        guard let stringRange = Range(range, in: string) else { return }

        // Expand range to include full lines for proper highlighting
        let lineRange = string.lineRange(for: stringRange)
        let expandedNSRange = NSRange(lineRange, in: string)

        // Begin editing
        textStorage.beginEditing()

        // Reset to default attributes first
        let defaultAttributes: [NSAttributedString.Key: Any] = [
            .font: theme.font,
            .foregroundColor: theme.text,
            .backgroundColor: NSColor.clear
        ]
        textStorage.setAttributes(defaultAttributes, range: expandedNSRange)

        // Apply markdown patterns
        let substring = String(string[lineRange])

        // Find code block ranges in the substring
        let codeBlockRanges = findCodeBlockRanges(in: substring)

        // First, apply code block styling to the content
        for codeBlockRange in codeBlockRanges {
            let adjustedRange = NSRange(
                location: codeBlockRange.location + expandedNSRange.location,
                length: codeBlockRange.length
            )
            let codeAttributes: [NSAttributedString.Key: Any] = [
                .font: theme.codeFont,
                .foregroundColor: theme.code,
                .backgroundColor: theme.codeBackground
            ]
            textStorage.addAttributes(codeAttributes, range: adjustedRange)
        }

        // Then apply other patterns, excluding code block regions
        for pattern in patterns {
            applyPattern(pattern, to: textStorage, in: substring, offset: expandedNSRange.location, codeBlockRanges: codeBlockRanges)
        }

        textStorage.endEditing()
    }

    // MARK: - Pattern Application

    /// Find all fenced code block ranges in the string
    private func findCodeBlockRanges(in string: String) -> [NSRange] {
        var ranges: [NSRange] = []
        let nsString = string as NSString

        // Match fenced code blocks: ```...``` with content between
        // Using a simple state machine approach
        let lines = string.components(separatedBy: .newlines)
        var inCodeBlock = false
        var codeBlockStart = 0
        var currentPosition = 0

        for line in lines {
            let lineLength = (line as NSString).length

            if line.hasPrefix("```") {
                if !inCodeBlock {
                    // Opening fence
                    inCodeBlock = true
                    codeBlockStart = currentPosition
                } else {
                    // Closing fence
                    inCodeBlock = false
                    let codeBlockEnd = currentPosition + lineLength
                    ranges.append(NSRange(location: codeBlockStart, length: codeBlockEnd - codeBlockStart))
                }
            }

            // Move past this line plus newline
            currentPosition += lineLength + 1
        }

        // Handle unclosed code block (extends to end)
        if inCodeBlock {
            ranges.append(NSRange(location: codeBlockStart, length: nsString.length - codeBlockStart))
        }

        return ranges
    }

    /// Check if a range overlaps with any code block
    private func rangeOverlapsCodeBlock(_ range: NSRange, codeBlocks: [NSRange]) -> Bool {
        for codeBlock in codeBlocks {
            if NSIntersectionRange(range, codeBlock).length > 0 {
                return true
            }
        }
        return false
    }

    private func applyPattern(
        _ pattern: MarkdownPattern,
        to textStorage: NSTextStorage,
        in string: String,
        offset: Int,
        codeBlockRanges: [NSRange]
    ) {
        let nsString = string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        pattern.regex.enumerateMatches(in: string, options: [], range: fullRange) { match, _, _ in
            guard let match = match else { return }

            // Determine which range to style (full match or capture group)
            let rangeToStyle: NSRange
            if pattern.captureGroup > 0 && match.numberOfRanges > pattern.captureGroup {
                rangeToStyle = match.range(at: pattern.captureGroup)
            } else {
                rangeToStyle = match.range
            }

            guard rangeToStyle.location != NSNotFound else { return }

            // Skip if this pattern is not code-related and the range is inside a code block
            let isCodePattern = pattern.type == .codeFence || pattern.type == .codeBlock || pattern.type == .inlineCode
            if !isCodePattern && self.rangeOverlapsCodeBlock(rangeToStyle, codeBlocks: codeBlockRanges) {
                return
            }

            // For inline code, skip if it's inside a fenced code block
            if pattern.type == .inlineCode && self.rangeOverlapsCodeBlock(rangeToStyle, codeBlocks: codeBlockRanges) {
                return
            }

            // Apply attributes based on pattern type
            let attributes = self.attributes(for: pattern.type)

            // Adjust range for offset in original text storage
            let adjustedRange = NSRange(
                location: rangeToStyle.location + offset,
                length: rangeToStyle.length
            )

            // Apply the attributes
            textStorage.addAttributes(attributes, range: adjustedRange)
        }
    }

    /// Get text attributes for a markdown element type
    private func attributes(for type: MarkdownElementType) -> [NSAttributedString.Key: Any] {
        switch type {
        case .heading1:
            return [
                .foregroundColor: theme.heading,
                .font: NSFont.monospacedSystemFont(ofSize: 20, weight: .bold)
            ]
        case .heading2:
            return [
                .foregroundColor: theme.heading,
                .font: NSFont.monospacedSystemFont(ofSize: 18, weight: .bold)
            ]
        case .heading3:
            return [
                .foregroundColor: theme.heading,
                .font: NSFont.monospacedSystemFont(ofSize: 16, weight: .bold)
            ]
        case .heading4, .heading5, .heading6:
            return [
                .foregroundColor: theme.heading,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
            ]
        case .bold:
            return [
                .foregroundColor: theme.bold,
                .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .bold)
            ]
        case .italic:
            let font = NSFontManager.shared.convert(theme.font, toHaveTrait: .italicFontMask)
            return [
                .foregroundColor: theme.italic,
                .font: font
            ]
        case .boldItalic:
            var font = NSFontManager.shared.convert(theme.font, toHaveTrait: .boldFontMask)
            font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            return [
                .foregroundColor: theme.bold,
                .font: font
            ]
        case .inlineCode:
            return [
                .foregroundColor: theme.code,
                .font: theme.codeFont,
                .backgroundColor: theme.codeBackground
            ]
        case .codeBlock:
            return [
                .foregroundColor: theme.code,
                .font: theme.codeFont,
                .backgroundColor: theme.codeBackground
            ]
        case .codeFence:
            return [
                .foregroundColor: theme.listMarker,
                .font: theme.codeFont
            ]
        case .link:
            return [
                .foregroundColor: theme.link,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]
        case .linkURL:
            return [
                .foregroundColor: theme.listMarker
            ]
        case .image:
            return [
                .foregroundColor: theme.link
            ]
        case .listMarker:
            return [
                .foregroundColor: theme.listMarker
            ]
        case .blockquote:
            return [
                .foregroundColor: theme.blockquote
            ]
        case .horizontalRule:
            return [
                .foregroundColor: theme.horizontalRule
            ]
        case .strikethrough:
            return [
                .foregroundColor: theme.text,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue
            ]
        }
    }

    // MARK: - Pattern Compilation

    /// Compile all regex patterns (called once at init)
    private static func compilePatterns() -> [MarkdownPattern] {
        var patterns: [MarkdownPattern] = []

        // Order matters! More specific patterns should come first

        // Code blocks (fenced) - must come before other patterns to avoid conflicts
        // Match the fence markers
        if let regex = try? NSRegularExpression(pattern: "^```.*$", options: [.anchorsMatchLines]) {
            patterns.append(MarkdownPattern(regex: regex, type: .codeFence, captureGroup: 0))
        }

        // Headings (ATX style)
        if let regex = try? NSRegularExpression(pattern: "^(#{1})\\s+.+$", options: [.anchorsMatchLines]) {
            patterns.append(MarkdownPattern(regex: regex, type: .heading1, captureGroup: 0))
        }
        if let regex = try? NSRegularExpression(pattern: "^(#{2})\\s+.+$", options: [.anchorsMatchLines]) {
            patterns.append(MarkdownPattern(regex: regex, type: .heading2, captureGroup: 0))
        }
        if let regex = try? NSRegularExpression(pattern: "^(#{3})\\s+.+$", options: [.anchorsMatchLines]) {
            patterns.append(MarkdownPattern(regex: regex, type: .heading3, captureGroup: 0))
        }
        if let regex = try? NSRegularExpression(pattern: "^(#{4,6})\\s+.+$", options: [.anchorsMatchLines]) {
            patterns.append(MarkdownPattern(regex: regex, type: .heading4, captureGroup: 0))
        }

        // Horizontal rule
        if let regex = try? NSRegularExpression(pattern: "^([-*_]){3,}\\s*$", options: [.anchorsMatchLines]) {
            patterns.append(MarkdownPattern(regex: regex, type: .horizontalRule, captureGroup: 0))
        }

        // Blockquote
        if let regex = try? NSRegularExpression(pattern: "^(>+)\\s?", options: [.anchorsMatchLines]) {
            patterns.append(MarkdownPattern(regex: regex, type: .blockquote, captureGroup: 1))
        }

        // List markers (unordered)
        if let regex = try? NSRegularExpression(pattern: "^(\\s*)([-*+])\\s", options: [.anchorsMatchLines]) {
            patterns.append(MarkdownPattern(regex: regex, type: .listMarker, captureGroup: 2))
        }

        // List markers (ordered)
        if let regex = try? NSRegularExpression(pattern: "^(\\s*)(\\d+\\.)\\s", options: [.anchorsMatchLines]) {
            patterns.append(MarkdownPattern(regex: regex, type: .listMarker, captureGroup: 2))
        }

        // Task list checkboxes
        if let regex = try? NSRegularExpression(pattern: "^(\\s*[-*+]\\s)(\\[[ xX]\\])", options: [.anchorsMatchLines]) {
            patterns.append(MarkdownPattern(regex: regex, type: .listMarker, captureGroup: 2))
        }

        // Inline code (must come before bold/italic to avoid conflicts)
        if let regex = try? NSRegularExpression(pattern: "`([^`]+)`", options: []) {
            patterns.append(MarkdownPattern(regex: regex, type: .inlineCode, captureGroup: 0))
        }

        // Bold + Italic (***text*** or ___text___)
        if let regex = try? NSRegularExpression(pattern: "(\\*{3}|_{3})(?=\\S)(.+?)(?<=\\S)\\1", options: []) {
            patterns.append(MarkdownPattern(regex: regex, type: .boldItalic, captureGroup: 0))
        }

        // Bold (**text** or __text__)
        if let regex = try? NSRegularExpression(pattern: "(\\*{2}|_{2})(?=\\S)(.+?)(?<=\\S)\\1", options: []) {
            patterns.append(MarkdownPattern(regex: regex, type: .bold, captureGroup: 0))
        }

        // Italic (*text* or _text_)
        if let regex = try? NSRegularExpression(pattern: "(?<![*_])(\\*|_)(?=\\S)(.+?)(?<=\\S)\\1(?![*_])", options: []) {
            patterns.append(MarkdownPattern(regex: regex, type: .italic, captureGroup: 0))
        }

        // Strikethrough (~~text~~)
        if let regex = try? NSRegularExpression(pattern: "~~(.+?)~~", options: []) {
            patterns.append(MarkdownPattern(regex: regex, type: .strikethrough, captureGroup: 0))
        }

        // Images ![alt](url)
        if let regex = try? NSRegularExpression(pattern: "!\\[([^\\]]*)\\]\\(([^)]+)\\)", options: []) {
            patterns.append(MarkdownPattern(regex: regex, type: .image, captureGroup: 0))
        }

        // Links [text](url)
        if let regex = try? NSRegularExpression(pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)", options: []) {
            patterns.append(MarkdownPattern(regex: regex, type: .link, captureGroup: 1))
        }
        // URL part of links
        if let regex = try? NSRegularExpression(pattern: "\\[[^\\]]+\\](\\([^)]+\\))", options: []) {
            patterns.append(MarkdownPattern(regex: regex, type: .linkURL, captureGroup: 1))
        }

        return patterns
    }
}

// MARK: - Supporting Types

/// A compiled regex pattern for a markdown element
private struct MarkdownPattern {
    let regex: NSRegularExpression
    let type: MarkdownElementType
    let captureGroup: Int
}

/// Types of markdown elements we can highlight
private enum MarkdownElementType {
    case heading1
    case heading2
    case heading3
    case heading4
    case heading5
    case heading6
    case bold
    case italic
    case boldItalic
    case inlineCode
    case codeBlock
    case codeFence
    case link
    case linkURL
    case image
    case listMarker
    case blockquote
    case horizontalRule
    case strikethrough
}
