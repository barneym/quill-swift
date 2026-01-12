import AppKit

/// A hybrid WYSIWYG markdown editor that shows formatted preview while editing.
///
/// Key behaviors:
/// - Shows formatted text (bold, italic, headings, etc.) for lines not being edited
/// - Reveals raw markdown syntax when cursor enters a formatted region
/// - Format updates on completion (e.g., `**bold**` formats after closing **)
/// - Markdown source is always the primary representation
///
/// This is a "line-level" hybrid editor - formatting applies per-line/block,
/// not character-by-character, to minimize visual jitter.
class LivePreviewTextView: MarkdownTextView {

    // MARK: - Properties

    /// Whether live preview mode is enabled
    var livePreviewEnabled: Bool = true {
        didSet {
            if livePreviewEnabled {
                updateLivePreview()
            } else {
                // Fall back to standard highlighting
                highlightAllText()
            }
        }
    }

    /// Tracks which line(s) the cursor is currently on (raw syntax revealed)
    private var cursorLineRange: NSRange = NSRange(location: 0, length: 0)

    /// Debounce timer for preview updates
    private var previewUpdateTimer: Timer?

    /// Delay before applying formatting after cursor moves (ms)
    private let formattingDelay: TimeInterval = 0.15

    // MARK: - Cursor Tracking

    override func setSelectedRanges(
        _ ranges: [NSValue],
        affinity: NSSelectionAffinity,
        stillSelecting: Bool
    ) {
        let previousLineRange = cursorLineRange

        super.setSelectedRanges(ranges, affinity: affinity, stillSelecting: stillSelecting)

        // Update cursor line tracking
        if let range = ranges.first?.rangeValue {
            updateCursorLineRange(for: range)

            // If cursor moved to a different line, schedule preview update
            if !stillSelecting && !NSEqualRanges(previousLineRange, cursorLineRange) {
                schedulePreviewUpdate(previousLineRange: previousLineRange)
            }
        }
    }

    /// Update the tracked cursor line range
    private func updateCursorLineRange(for selection: NSRange) {
        guard let textStorage = textStorage else { return }

        let string = textStorage.string as NSString
        cursorLineRange = string.lineRange(for: selection)
    }

    // MARK: - Preview Updates

    /// Schedule a preview update after cursor moves
    private func schedulePreviewUpdate(previousLineRange: NSRange) {
        previewUpdateTimer?.invalidate()

        guard livePreviewEnabled else { return }

        previewUpdateTimer = Timer.scheduledTimer(
            withTimeInterval: formattingDelay,
            repeats: false
        ) { [weak self] _ in
            self?.applyLivePreview(previousLineRange: previousLineRange)
        }
    }

    /// Apply live preview formatting
    private func applyLivePreview(previousLineRange: NSRange) {
        guard let textStorage = textStorage else { return }

        textStorage.beginEditing()

        // Format the previous line (cursor just left)
        if previousLineRange.length > 0 {
            formatLineAsPreview(previousLineRange)
        }

        // Show raw syntax for current cursor line
        if cursorLineRange.length > 0 {
            revealSyntaxForLine(cursorLineRange)
        }

        textStorage.endEditing()
    }

    /// Update live preview for visible text
    func updateLivePreview() {
        guard let textStorage = textStorage,
              livePreviewEnabled else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)

        textStorage.beginEditing()

        // Format everything as preview
        formatLineAsPreview(fullRange)

        // Then reveal current cursor line
        if cursorLineRange.length > 0 {
            revealSyntaxForLine(cursorLineRange)
        }

        textStorage.endEditing()
    }

    // MARK: - Line Formatting

    /// Format a line range as rendered preview (hide syntax, show styling)
    private func formatLineAsPreview(_ range: NSRange) {
        guard let textStorage = textStorage,
              let theme = highlighter?.theme else { return }

        let string = textStorage.string
        guard let stringRange = Range(range, in: string) else { return }

        let lineContent = String(string[stringRange])

        // Apply formatted preview for different element types
        applyHeadingPreview(lineContent, range: range, theme: theme)
        applyEmphasisPreview(lineContent, range: range, theme: theme)
        applyLinkPreview(lineContent, range: range, theme: theme)
        applyCheckboxPreview(lineContent, range: range, theme: theme)
    }

    /// Reveal raw markdown syntax for a line (cursor is on this line)
    private func revealSyntaxForLine(_ range: NSRange) {
        guard let textStorage = textStorage else { return }

        // Use standard highlighting for cursor line (shows raw syntax)
        highlighter?.highlightRange(range, in: textStorage)
    }

    // MARK: - Preview Formatters

    /// Apply heading preview - larger font, hide # markers
    private func applyHeadingPreview(_ line: String, range: NSRange, theme: EditorTheme) {
        guard let textStorage = textStorage else { return }

        // Match heading patterns: # Heading, ## Heading, etc.
        let headingPattern = try! NSRegularExpression(
            pattern: "^(#{1,6})\\s+(.+)$",
            options: []
        )

        let nsLine = line as NSString
        let lineRange = NSRange(location: 0, length: nsLine.length)

        guard let match = headingPattern.firstMatch(in: line, options: [], range: lineRange) else {
            return
        }

        let hashCount = match.range(at: 1).length
        let contentRange = match.range(at: 2)

        // Calculate absolute range for content
        let absoluteContentRange = NSRange(
            location: range.location + contentRange.location,
            length: contentRange.length
        )

        // Determine font size based on heading level
        let fontSize: CGFloat
        switch hashCount {
        case 1: fontSize = 24
        case 2: fontSize = 20
        case 3: fontSize = 18
        case 4: fontSize = 16
        case 5: fontSize = 14
        default: fontSize = 13
        }

        let headingFont = NSFont.systemFont(ofSize: fontSize, weight: .bold)

        // Hide the hash markers by making them very small/transparent
        let hashRange = NSRange(
            location: range.location + match.range(at: 1).location,
            length: match.range(at: 1).length + 1 // Include space
        )

        let hiddenAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 1),
            .foregroundColor: NSColor.clear
        ]

        let contentAttrs: [NSAttributedString.Key: Any] = [
            .font: headingFont,
            .foregroundColor: theme.heading
        ]

        // Apply attributes
        if hashRange.location + hashRange.length <= textStorage.length {
            textStorage.addAttributes(hiddenAttrs, range: hashRange)
        }
        if absoluteContentRange.location + absoluteContentRange.length <= textStorage.length {
            textStorage.addAttributes(contentAttrs, range: absoluteContentRange)
        }
    }

    /// Apply emphasis preview - bold/italic styling, hide markers
    private func applyEmphasisPreview(_ line: String, range: NSRange, theme: EditorTheme) {
        guard let textStorage = textStorage else { return }

        // Bold: **text** or __text__
        let boldPattern = try! NSRegularExpression(
            pattern: "(\\*{2}|_{2})([^*_]+)\\1",
            options: []
        )

        // Italic: *text* or _text_
        let italicPattern = try! NSRegularExpression(
            pattern: "(?<![*_])(\\*|_)([^*_]+)\\1(?![*_])",
            options: []
        )

        let nsLine = line as NSString
        let lineRange = NSRange(location: 0, length: nsLine.length)

        // Process bold
        for match in boldPattern.matches(in: line, options: [], range: lineRange) {
            applyEmphasisMatch(match, range: range, isBold: true, theme: theme)
        }

        // Process italic
        for match in italicPattern.matches(in: line, options: [], range: lineRange) {
            applyEmphasisMatch(match, range: range, isBold: false, theme: theme)
        }
    }

    /// Apply emphasis formatting for a regex match
    private func applyEmphasisMatch(
        _ match: NSTextCheckingResult,
        range: NSRange,
        isBold: Bool,
        theme: EditorTheme
    ) {
        guard let textStorage = textStorage else { return }

        // Group 1: opening markers
        // Group 2: content
        // (closing markers are same as group 1 due to backreference)

        let openMarkerRange = match.range(at: 1)
        let contentRange = match.range(at: 2)

        // Calculate absolute ranges
        let absOpenRange = NSRange(
            location: range.location + openMarkerRange.location,
            length: openMarkerRange.length
        )
        let absCloseRange = NSRange(
            location: range.location + contentRange.location + contentRange.length,
            length: openMarkerRange.length
        )
        let absContentRange = NSRange(
            location: range.location + contentRange.location,
            length: contentRange.length
        )

        // Hidden attributes for markers
        let hiddenAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 1),
            .foregroundColor: NSColor.clear
        ]

        // Content attributes
        let font: NSFont
        if isBold {
            font = NSFont.boldSystemFont(ofSize: 14)
        } else {
            font = NSFontManager.shared.convert(
                NSFont.systemFont(ofSize: 14),
                toHaveTrait: .italicFontMask
            )
        }

        let contentAttrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: isBold ? theme.bold : theme.italic
        ]

        // Apply attributes
        if absOpenRange.location + absOpenRange.length <= textStorage.length {
            textStorage.addAttributes(hiddenAttrs, range: absOpenRange)
        }
        if absCloseRange.location + absCloseRange.length <= textStorage.length {
            textStorage.addAttributes(hiddenAttrs, range: absCloseRange)
        }
        if absContentRange.location + absContentRange.length <= textStorage.length {
            textStorage.addAttributes(contentAttrs, range: absContentRange)
        }
    }

    /// Apply link preview - show text, hide URL
    private func applyLinkPreview(_ line: String, range: NSRange, theme: EditorTheme) {
        guard let textStorage = textStorage else { return }

        // Match [text](url)
        let linkPattern = try! NSRegularExpression(
            pattern: "\\[([^\\]]+)\\]\\(([^)]+)\\)",
            options: []
        )

        let nsLine = line as NSString
        let lineRange = NSRange(location: 0, length: nsLine.length)

        for match in linkPattern.matches(in: line, options: [], range: lineRange) {
            let fullMatchRange = match.range
            let textRange = match.range(at: 1)

            // Show just the link text with link styling
            let absFullRange = NSRange(
                location: range.location + fullMatchRange.location,
                length: fullMatchRange.length
            )
            let absTextRange = NSRange(
                location: range.location + textRange.location,
                length: textRange.length
            )

            // Hide the brackets and URL
            let openBracketRange = NSRange(location: absFullRange.location, length: 1)
            let closeBracketToEnd = NSRange(
                location: absTextRange.location + absTextRange.length,
                length: absFullRange.length - textRange.length - 1
            )

            let hiddenAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 1),
                .foregroundColor: NSColor.clear
            ]

            let linkAttrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: theme.link,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ]

            // Apply attributes
            if openBracketRange.location + openBracketRange.length <= textStorage.length {
                textStorage.addAttributes(hiddenAttrs, range: openBracketRange)
            }
            if closeBracketToEnd.location + closeBracketToEnd.length <= textStorage.length {
                textStorage.addAttributes(hiddenAttrs, range: closeBracketToEnd)
            }
            if absTextRange.location + absTextRange.length <= textStorage.length {
                textStorage.addAttributes(linkAttrs, range: absTextRange)
            }
        }
    }

    /// Apply checkbox preview - show checkbox symbol instead of [ ]
    private func applyCheckboxPreview(_ line: String, range: NSRange, theme: EditorTheme) {
        guard let textStorage = textStorage else { return }

        // Match task list items: - [ ] or - [x]
        let checkboxPattern = try! NSRegularExpression(
            pattern: "^(\\s*[-*+]\\s)(\\[[ xX]\\])(\\s)",
            options: []
        )

        let nsLine = line as NSString
        let lineRange = NSRange(location: 0, length: nsLine.length)

        guard let match = checkboxPattern.firstMatch(in: line, options: [], range: lineRange) else {
            return
        }

        let checkboxRange = match.range(at: 2)
        let checkbox = nsLine.substring(with: checkboxRange)

        let absCheckboxRange = NSRange(
            location: range.location + checkboxRange.location,
            length: checkboxRange.length
        )

        // Determine checkbox state
        let isChecked = checkbox.contains("x") || checkbox.contains("X")

        // Use SF Symbol attachment for checkbox (requires macOS 11+)
        let symbolName = isChecked ? "checkmark.square.fill" : "square"
        let symbolColor = isChecked ? NSColor.systemGreen : theme.listMarker

        // For now, just style the checkbox differently
        // Full SF Symbol replacement would require NSTextAttachment
        let checkboxAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: symbolColor,
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        ]

        if absCheckboxRange.location + absCheckboxRange.length <= textStorage.length {
            textStorage.addAttributes(checkboxAttrs, range: absCheckboxRange)
        }
    }

    // MARK: - Cleanup

    deinit {
        previewUpdateTimer?.invalidate()
    }
}
