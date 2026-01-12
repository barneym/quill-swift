import AppKit

/// Provides smart list continuation and indentation for markdown editing.
///
/// Handles:
/// - Auto-continuing lists on Enter (-, *, +, 1.)
/// - Auto-continuing task lists with checkboxes
/// - Tab/Shift-Tab for indentation
/// - Backspace to remove empty list items
struct SmartLists {

    // MARK: - List Patterns

    /// Regex to match unordered list markers
    private static let unorderedListPattern = try! NSRegularExpression(
        pattern: "^(\\s*)([-*+])\\s(.*)$",
        options: []
    )

    /// Regex to match ordered list markers
    private static let orderedListPattern = try! NSRegularExpression(
        pattern: "^(\\s*)(\\d+)\\.\\s(.*)$",
        options: []
    )

    /// Regex to match task list items
    private static let taskListPattern = try! NSRegularExpression(
        pattern: "^(\\s*)([-*+])\\s\\[[ xX]\\]\\s(.*)$",
        options: []
    )

    /// Regex to match blockquote continuation
    private static let blockquotePattern = try! NSRegularExpression(
        pattern: "^(>+\\s?)(.*)$",
        options: []
    )

    // MARK: - Enter Key Handling

    /// Handle Enter key press for list continuation
    /// - Returns: true if handled, false to use default behavior
    static func handleEnter(in textView: NSTextView) -> Bool {
        guard let textStorage = textView.textStorage else { return false }

        let string = textStorage.string as NSString
        let selectedRange = textView.selectedRange()

        // Only handle if cursor is at a single point (no selection)
        guard selectedRange.length == 0 else { return false }

        // Get the current line
        let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
        let lineContent = string.substring(with: lineRange)

        // Try different list patterns
        if let result = handleTaskListContinuation(lineContent, lineRange: lineRange, in: textView) {
            return result
        }

        if let result = handleUnorderedListContinuation(lineContent, lineRange: lineRange, in: textView) {
            return result
        }

        if let result = handleOrderedListContinuation(lineContent, lineRange: lineRange, in: textView) {
            return result
        }

        if let result = handleBlockquoteContinuation(lineContent, lineRange: lineRange, in: textView) {
            return result
        }

        return false
    }

    // MARK: - Task List Continuation

    private static func handleTaskListContinuation(
        _ lineContent: String,
        lineRange: NSRange,
        in textView: NSTextView
    ) -> Bool? {
        let nsLine = lineContent as NSString
        let range = NSRange(location: 0, length: nsLine.length)

        guard let match = taskListPattern.firstMatch(in: lineContent, options: [], range: range) else {
            return nil
        }

        let indent = nsLine.substring(with: match.range(at: 1))
        let marker = nsLine.substring(with: match.range(at: 2))
        let content = nsLine.substring(with: match.range(at: 3))

        // If line is empty (just marker and checkbox), remove the list item
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            textView.insertText("\n", replacementRange: lineRange)
            return true
        }

        // Continue with new unchecked checkbox
        let newLine = "\n\(indent)\(marker) [ ] "
        textView.insertText(newLine, replacementRange: textView.selectedRange())
        return true
    }

    // MARK: - Unordered List Continuation

    private static func handleUnorderedListContinuation(
        _ lineContent: String,
        lineRange: NSRange,
        in textView: NSTextView
    ) -> Bool? {
        let nsLine = lineContent as NSString
        let range = NSRange(location: 0, length: nsLine.length)

        guard let match = unorderedListPattern.firstMatch(in: lineContent, options: [], range: range) else {
            return nil
        }

        let indent = nsLine.substring(with: match.range(at: 1))
        let marker = nsLine.substring(with: match.range(at: 2))
        let content = nsLine.substring(with: match.range(at: 3))

        // If line is empty (just marker), remove the list item
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            textView.insertText("\n", replacementRange: lineRange)
            return true
        }

        // Continue with same marker
        let newLine = "\n\(indent)\(marker) "
        textView.insertText(newLine, replacementRange: textView.selectedRange())
        return true
    }

    // MARK: - Ordered List Continuation

    private static func handleOrderedListContinuation(
        _ lineContent: String,
        lineRange: NSRange,
        in textView: NSTextView
    ) -> Bool? {
        let nsLine = lineContent as NSString
        let range = NSRange(location: 0, length: nsLine.length)

        guard let match = orderedListPattern.firstMatch(in: lineContent, options: [], range: range) else {
            return nil
        }

        let indent = nsLine.substring(with: match.range(at: 1))
        let numberStr = nsLine.substring(with: match.range(at: 2))
        let content = nsLine.substring(with: match.range(at: 3))

        // If line is empty (just marker), remove the list item
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            textView.insertText("\n", replacementRange: lineRange)
            return true
        }

        // Continue with next number
        let nextNumber = (Int(numberStr) ?? 1) + 1
        let newLine = "\n\(indent)\(nextNumber). "
        textView.insertText(newLine, replacementRange: textView.selectedRange())
        return true
    }

    // MARK: - Blockquote Continuation

    private static func handleBlockquoteContinuation(
        _ lineContent: String,
        lineRange: NSRange,
        in textView: NSTextView
    ) -> Bool? {
        let nsLine = lineContent as NSString
        let range = NSRange(location: 0, length: nsLine.length)

        guard let match = blockquotePattern.firstMatch(in: lineContent, options: [], range: range) else {
            return nil
        }

        let prefix = nsLine.substring(with: match.range(at: 1))
        let content = nsLine.substring(with: match.range(at: 2))

        // If line is empty (just >), remove the blockquote marker
        if content.trimmingCharacters(in: .whitespaces).isEmpty {
            textView.insertText("\n", replacementRange: lineRange)
            return true
        }

        // Continue with same blockquote prefix
        let newLine = "\n\(prefix)"
        textView.insertText(newLine, replacementRange: textView.selectedRange())
        return true
    }

    // MARK: - Tab Indentation

    /// Handle Tab key for indentation
    static func handleTab(in textView: NSTextView, shift: Bool) -> Bool {
        guard let textStorage = textView.textStorage else { return false }

        let string = textStorage.string as NSString
        let selectedRange = textView.selectedRange()

        // Get lines affected by selection
        let lineRange = string.lineRange(for: selectedRange)
        let lineContent = string.substring(with: lineRange)

        // Check if this is a list line
        if isListLine(lineContent) {
            if shift {
                // Outdent
                return outdentLine(lineRange, in: textView)
            } else {
                // Indent
                return indentLine(lineRange, in: textView)
            }
        }

        return false
    }

    /// Check if a line is a list item
    private static func isListLine(_ line: String) -> Bool {
        let nsLine = line as NSString
        let range = NSRange(location: 0, length: nsLine.length)

        return unorderedListPattern.firstMatch(in: line, options: [], range: range) != nil
            || orderedListPattern.firstMatch(in: line, options: [], range: range) != nil
            || taskListPattern.firstMatch(in: line, options: [], range: range) != nil
    }

    /// Indent a line by adding spaces
    private static func indentLine(_ lineRange: NSRange, in textView: NSTextView) -> Bool {
        guard let textStorage = textView.textStorage else { return false }

        let string = textStorage.string as NSString
        let lineContent = string.substring(with: lineRange)

        // Add 4 spaces at the beginning
        let indentedLine = "    " + lineContent
        textView.insertText(indentedLine, replacementRange: lineRange)

        // Adjust cursor position
        let newCursorPos = textView.selectedRange().location + 4
        textView.setSelectedRange(NSRange(location: newCursorPos, length: 0))

        return true
    }

    /// Outdent a line by removing spaces
    private static func outdentLine(_ lineRange: NSRange, in textView: NSTextView) -> Bool {
        guard let textStorage = textView.textStorage else { return false }

        let string = textStorage.string as NSString
        let lineContent = string.substring(with: lineRange)

        // Remove up to 4 leading spaces
        var spacesToRemove = 0
        for char in lineContent {
            if char == " " && spacesToRemove < 4 {
                spacesToRemove += 1
            } else {
                break
            }
        }

        if spacesToRemove > 0 {
            let outdentedLine = String(lineContent.dropFirst(spacesToRemove))
            textView.insertText(outdentedLine, replacementRange: lineRange)

            // Adjust cursor position
            let currentPos = textView.selectedRange().location
            let newPos = max(lineRange.location, currentPos - spacesToRemove)
            textView.setSelectedRange(NSRange(location: newPos, length: 0))
        }

        return true
    }
}
