import AppKit

/// Provides auto-completion behaviors for markdown editing.
///
/// Handles:
/// - Auto-closing brackets: (), [], {}, ``
/// - Auto-closing quotes: "", ''
/// - Skip-over when typing closing character
/// - Backspace deletes both characters when empty
struct AutoCompletion {

    // MARK: - Character Pairs

    /// Map of opening characters to their closing counterparts
    static let pairs: [Character: Character] = [
        "(": ")",
        "[": "]",
        "{": "}",
        "\"": "\"",
        "'": "'",
        "`": "`",
    ]

    /// Characters that should auto-close
    static let openingChars: Set<Character> = Set(pairs.keys)

    /// Characters that can be skipped over
    static let closingChars: Set<Character> = Set(pairs.values)

    // MARK: - Character Insertion

    /// Handle character insertion for auto-completion
    /// - Returns: true if handled, false to use default behavior
    static func handleCharacterInsertion(
        _ character: Character,
        in textView: NSTextView
    ) -> Bool {
        guard let textStorage = textView.textStorage else { return false }

        let string = textStorage.string
        let selectedRange = textView.selectedRange()

        // Check if we should skip over a closing character
        if closingChars.contains(character) {
            let cursorPosition = selectedRange.location
            if cursorPosition < string.count {
                let index = string.index(string.startIndex, offsetBy: cursorPosition)
                let nextChar = string[index]

                if nextChar == character {
                    // Skip over the closing character
                    textView.setSelectedRange(NSRange(location: cursorPosition + 1, length: 0))
                    return true
                }
            }
        }

        // Check if we should auto-close
        if let closingChar = pairs[character] {
            // Don't auto-close if there's a selection (wrap instead)
            if selectedRange.length > 0 {
                return handleWrapSelection(
                    opening: character,
                    closing: closingChar,
                    in: textView
                )
            }

            // Check context for smart auto-closing
            if shouldAutoClose(character, in: textView) {
                let insertion = String(character) + String(closingChar)
                textView.insertText(insertion, replacementRange: selectedRange)

                // Position cursor between the pair
                textView.setSelectedRange(NSRange(location: selectedRange.location + 1, length: 0))
                return true
            }
        }

        return false
    }

    /// Wrap selection in opening/closing characters
    private static func handleWrapSelection(
        opening: Character,
        closing: Character,
        in textView: NSTextView
    ) -> Bool {
        guard let textStorage = textView.textStorage else { return false }

        let selectedRange = textView.selectedRange()
        let selectedText = (textStorage.string as NSString).substring(with: selectedRange)

        let wrapped = String(opening) + selectedText + String(closing)
        textView.insertText(wrapped, replacementRange: selectedRange)

        // Select the wrapped content (excluding characters)
        textView.setSelectedRange(NSRange(
            location: selectedRange.location + 1,
            length: selectedText.count
        ))

        return true
    }

    /// Determine if auto-closing should occur based on context
    private static func shouldAutoClose(_ character: Character, in textView: NSTextView) -> Bool {
        guard let textStorage = textView.textStorage else { return true }

        let string = textStorage.string
        let cursorPosition = textView.selectedRange().location

        // Get character after cursor
        if cursorPosition < string.count {
            let index = string.index(string.startIndex, offsetBy: cursorPosition)
            let nextChar = string[index]

            // Don't auto-close if next character is alphanumeric
            if nextChar.isLetter || nextChar.isNumber {
                return false
            }
        }

        // For quotes, check if we're inside a word
        if character == "\"" || character == "'" {
            if cursorPosition > 0 {
                let prevIndex = string.index(string.startIndex, offsetBy: cursorPosition - 1)
                let prevChar = string[prevIndex]

                // Don't auto-close after alphanumeric (likely mid-word apostrophe)
                if prevChar.isLetter || prevChar.isNumber {
                    return false
                }
            }
        }

        return true
    }

    // MARK: - Backspace Handling

    /// Handle backspace for auto-completion pairs
    /// - Returns: true if handled, false to use default behavior
    static func handleBackspace(in textView: NSTextView) -> Bool {
        guard let textStorage = textView.textStorage else { return false }

        let string = textStorage.string
        let selectedRange = textView.selectedRange()

        // Only handle single cursor position
        guard selectedRange.length == 0 && selectedRange.location > 0 else {
            return false
        }

        let cursorPosition = selectedRange.location

        // Get character before and after cursor
        guard cursorPosition < string.count else { return false }

        let prevIndex = string.index(string.startIndex, offsetBy: cursorPosition - 1)
        let nextIndex = string.index(string.startIndex, offsetBy: cursorPosition)

        let prevChar = string[prevIndex]
        let nextChar = string[nextIndex]

        // Check if we're between a pair
        if let expectedClosing = pairs[prevChar], expectedClosing == nextChar {
            // Delete both characters
            let deleteRange = NSRange(location: cursorPosition - 1, length: 2)
            textView.insertText("", replacementRange: deleteRange)
            return true
        }

        return false
    }

    // MARK: - Code Block Handling

    /// Handle triple backtick insertion for code blocks
    static func handleTripleBacktick(in textView: NSTextView) -> Bool {
        guard let textStorage = textView.textStorage else { return false }

        let string = textStorage.string as NSString
        let selectedRange = textView.selectedRange()

        // Check if we just typed the third backtick
        guard selectedRange.location >= 2 else { return false }

        let prevTwo = string.substring(with: NSRange(location: selectedRange.location - 2, length: 2))
        guard prevTwo == "``" else { return false }

        // Insert code block structure
        // The third backtick is about to be inserted, so we add the closing fence
        let codeBlock = "`\n\n```"
        textView.insertText(codeBlock, replacementRange: selectedRange)

        // Position cursor after the language identifier position
        textView.setSelectedRange(NSRange(location: selectedRange.location + 1, length: 0))

        return true
    }
}
