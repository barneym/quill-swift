import AppKit

/// Provides markdown formatting operations for text editing.
///
/// Handles wrapping selected text in markdown syntax (bold, italic, etc.)
/// and applying line-based formatting like headings.
struct FormattingCommands {

    // MARK: - Text Wrapping

    /// Wrap selection with bold markers (**text**)
    static func toggleBold(in textView: NSTextView) {
        toggleWrapping(in: textView, prefix: "**", suffix: "**")
    }

    /// Wrap selection with italic markers (*text*)
    static func toggleItalic(in textView: NSTextView) {
        toggleWrapping(in: textView, prefix: "*", suffix: "*")
    }

    /// Wrap selection with strikethrough markers (~~text~~)
    static func toggleStrikethrough(in textView: NSTextView) {
        toggleWrapping(in: textView, prefix: "~~", suffix: "~~")
    }

    /// Wrap selection with inline code markers (`text`)
    static func toggleInlineCode(in textView: NSTextView) {
        toggleWrapping(in: textView, prefix: "`", suffix: "`")
    }

    /// Insert a link with selection as text ([text](url))
    static func insertLink(in textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()

        let selectedText: String
        if selectedRange.length > 0 {
            selectedText = (textStorage.string as NSString).substring(with: selectedRange)
        } else {
            selectedText = "link text"
        }

        let linkMarkdown = "[\(selectedText)](url)"

        // Calculate new cursor position (after the opening paren of url)
        let cursorOffset = selectedText.count + 3  // "[text](" = text.count + 3

        textView.insertText(linkMarkdown, replacementRange: selectedRange)

        // Select "url" so user can immediately type
        let urlStart = selectedRange.location + cursorOffset
        let urlRange = NSRange(location: urlStart, length: 3)  // "url".count
        textView.setSelectedRange(urlRange)
    }

    /// Insert an image (![alt](url))
    static func insertImage(in textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }
        let selectedRange = textView.selectedRange()

        let altText: String
        if selectedRange.length > 0 {
            altText = (textStorage.string as NSString).substring(with: selectedRange)
        } else {
            altText = "alt text"
        }

        let imageMarkdown = "![\(altText)](url)"

        // Calculate position for selecting "url"
        let cursorOffset = altText.count + 4  // "![text](" = text.count + 4

        textView.insertText(imageMarkdown, replacementRange: selectedRange)

        // Select "url"
        let urlStart = selectedRange.location + cursorOffset
        let urlRange = NSRange(location: urlStart, length: 3)
        textView.setSelectedRange(urlRange)
    }

    // MARK: - Headings

    /// Set the current line to a heading of specified level (1-6)
    static func setHeading(level: Int, in textView: NSTextView) {
        guard level >= 1 && level <= 6 else { return }
        guard let textStorage = textView.textStorage else { return }

        let string = textStorage.string as NSString
        let selectedRange = textView.selectedRange()

        // Get the line range for the current cursor position
        let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let lineContent = string.substring(with: lineRange)

        // Remove existing heading prefix if any
        let trimmedLine = removeHeadingPrefix(from: lineContent)

        // Build new heading
        let headingPrefix = String(repeating: "#", count: level) + " "
        let newLine = headingPrefix + trimmedLine

        // Replace the line
        textView.insertText(newLine, replacementRange: lineRange)

        // Position cursor at end of heading prefix
        let newCursorPos = lineRange.location + headingPrefix.count
        textView.setSelectedRange(NSRange(location: newCursorPos, length: 0))
    }

    /// Remove heading formatting from the current line
    static func removeHeading(in textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let string = textStorage.string as NSString
        let selectedRange = textView.selectedRange()

        // Get the line range
        let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let lineContent = string.substring(with: lineRange)

        // Remove heading prefix
        let newLine = removeHeadingPrefix(from: lineContent)

        // Replace the line
        textView.insertText(newLine, replacementRange: lineRange)

        // Position cursor at start of line
        textView.setSelectedRange(NSRange(location: lineRange.location, length: 0))
    }

    // MARK: - Block Formatting

    /// Toggle blockquote on current line(s)
    static func toggleBlockquote(in textView: NSTextView) {
        toggleLinePrefix(in: textView, prefix: "> ")
    }

    /// Toggle unordered list marker on current line(s)
    static func toggleUnorderedList(in textView: NSTextView) {
        toggleLinePrefix(in: textView, prefix: "- ")
    }

    /// Toggle checkbox on current line(s)
    static func toggleCheckbox(in textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let string = textStorage.string as NSString
        let selectedRange = textView.selectedRange()
        let lineRange = string.lineRange(for: selectedRange)
        let lineContent = string.substring(with: lineRange)

        let newLine: String

        if lineContent.hasPrefix("- [x] ") || lineContent.hasPrefix("- [X] ") {
            // Checked -> unchecked
            newLine = "- [ ] " + String(lineContent.dropFirst(6))
        } else if lineContent.hasPrefix("- [ ] ") {
            // Unchecked -> remove checkbox
            newLine = String(lineContent.dropFirst(6))
        } else if lineContent.hasPrefix("- ") {
            // List item -> add checkbox
            newLine = "- [ ] " + String(lineContent.dropFirst(2))
        } else {
            // Plain line -> add checkbox
            newLine = "- [ ] " + lineContent.trimmingCharacters(in: .whitespaces) + "\n"
        }

        textView.insertText(newLine, replacementRange: lineRange)
    }

    // MARK: - Code Blocks

    /// Insert a fenced code block
    static func insertCodeBlock(in textView: NSTextView) {
        let selectedRange = textView.selectedRange()

        let codeBlock = "```\n\n```"
        textView.insertText(codeBlock, replacementRange: selectedRange)

        // Position cursor after opening fence for language input
        let cursorPos = selectedRange.location + 3  // After "```"
        textView.setSelectedRange(NSRange(location: cursorPos, length: 0))
    }

    // MARK: - Private Helpers

    /// Toggle wrapping around selection with prefix/suffix
    private static func toggleWrapping(in textView: NSTextView, prefix: String, suffix: String) {
        guard let textStorage = textView.textStorage else { return }

        let selectedRange = textView.selectedRange()
        let string = textStorage.string as NSString

        // Check if selection is already wrapped
        let beforeStart = selectedRange.location - prefix.count
        let afterEnd = selectedRange.location + selectedRange.length

        var isWrapped = false
        if beforeStart >= 0 && afterEnd + suffix.count <= string.length {
            let beforeText = string.substring(with: NSRange(location: beforeStart, length: prefix.count))
            let afterText = string.substring(with: NSRange(location: afterEnd, length: suffix.count))
            isWrapped = (beforeText == prefix && afterText == suffix)
        }

        if isWrapped {
            // Remove wrapping
            let fullRange = NSRange(location: beforeStart, length: selectedRange.length + prefix.count + suffix.count)
            let unwrapped = string.substring(with: selectedRange)
            textView.insertText(unwrapped, replacementRange: fullRange)
            textView.setSelectedRange(NSRange(location: beforeStart, length: selectedRange.length))
        } else {
            // Add wrapping
            let selectedText: String
            if selectedRange.length > 0 {
                selectedText = string.substring(with: selectedRange)
            } else {
                selectedText = "text"
            }

            let wrapped = prefix + selectedText + suffix
            textView.insertText(wrapped, replacementRange: selectedRange)

            // Select the wrapped content (excluding markers)
            let newSelectionStart = selectedRange.location + prefix.count
            let newSelectionLength = selectedText.count
            textView.setSelectedRange(NSRange(location: newSelectionStart, length: newSelectionLength))
        }
    }

    /// Toggle a line prefix on current line(s)
    private static func toggleLinePrefix(in textView: NSTextView, prefix: String) {
        guard let textStorage = textView.textStorage else { return }

        let string = textStorage.string as NSString
        let selectedRange = textView.selectedRange()
        let lineRange = string.lineRange(for: selectedRange)
        let lineContent = string.substring(with: lineRange)

        let newLine: String
        if lineContent.hasPrefix(prefix) {
            // Remove prefix
            newLine = String(lineContent.dropFirst(prefix.count))
        } else {
            // Add prefix
            newLine = prefix + lineContent
        }

        textView.insertText(newLine, replacementRange: lineRange)
    }

    /// Remove heading prefix (#...) from a line
    private static func removeHeadingPrefix(from line: String) -> String {
        var result = line

        // Remove leading #s and space
        while result.hasPrefix("#") {
            result = String(result.dropFirst())
        }
        if result.hasPrefix(" ") {
            result = String(result.dropFirst())
        }

        return result
    }
}

// MARK: - NSTextView Extension

extension NSTextView {
    /// Apply a formatting command
    func applyFormatting(_ command: FormattingCommand) {
        switch command {
        case .bold:
            FormattingCommands.toggleBold(in: self)
        case .italic:
            FormattingCommands.toggleItalic(in: self)
        case .strikethrough:
            FormattingCommands.toggleStrikethrough(in: self)
        case .inlineCode:
            FormattingCommands.toggleInlineCode(in: self)
        case .link:
            FormattingCommands.insertLink(in: self)
        case .image:
            FormattingCommands.insertImage(in: self)
        case .heading(let level):
            FormattingCommands.setHeading(level: level, in: self)
        case .removeHeading:
            FormattingCommands.removeHeading(in: self)
        case .blockquote:
            FormattingCommands.toggleBlockquote(in: self)
        case .unorderedList:
            FormattingCommands.toggleUnorderedList(in: self)
        case .checkbox:
            FormattingCommands.toggleCheckbox(in: self)
        case .codeBlock:
            FormattingCommands.insertCodeBlock(in: self)
        }
    }
}

/// Available formatting commands
enum FormattingCommand {
    case bold
    case italic
    case strikethrough
    case inlineCode
    case link
    case image
    case heading(level: Int)
    case removeHeading
    case blockquote
    case unorderedList
    case checkbox
    case codeBlock
}
