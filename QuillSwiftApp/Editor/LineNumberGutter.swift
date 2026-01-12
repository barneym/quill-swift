import AppKit

/// A ruler view that displays line numbers for an NSTextView.
///
/// Attaches to an NSScrollView and draws line numbers aligned with text lines.
class LineNumberGutter: NSRulerView {

    // MARK: - Properties

    /// The text view this gutter is attached to
    weak var textView: NSTextView? {
        didSet {
            if let textView = textView {
                // Observe text changes
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(textDidChange(_:)),
                    name: NSText.didChangeNotification,
                    object: textView
                )

                // Observe selection changes (for highlighting current line)
                NotificationCenter.default.addObserver(
                    self,
                    selector: #selector(selectionDidChange(_:)),
                    name: NSTextView.didChangeSelectionNotification,
                    object: textView
                )
            }
        }
    }

    /// Font used for line numbers
    var lineNumberFont: NSFont = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular) {
        didSet { needsDisplay = true }
    }

    /// Color for line numbers
    var lineNumberColor: NSColor = .secondaryLabelColor {
        didSet { needsDisplay = true }
    }

    /// Color for current line number
    var currentLineColor: NSColor = .labelColor {
        didSet { needsDisplay = true }
    }

    /// Background color
    var gutterBackgroundColor: NSColor = .clear {
        didSet { needsDisplay = true }
    }

    /// Minimum width for the gutter
    private let minimumWidth: CGFloat = 32

    /// Padding from edge
    private let horizontalPadding: CGFloat = 8

    // MARK: - Initialization

    override init(scrollView: NSScrollView?, orientation: NSRulerView.Orientation) {
        super.init(scrollView: scrollView, orientation: orientation)
        commonInit()
    }

    required init(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        clientView = scrollView?.documentView
        ruleThickness = minimumWidth
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Drawing

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        // Draw background
        gutterBackgroundColor.setFill()
        rect.fill()

        // Get visible rect in text view coordinates
        let visibleRect = scrollView?.documentVisibleRect ?? textView.visibleRect

        // Calculate visible glyph range
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)
        let characterRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        // Get current line for highlighting
        let selectedRange = textView.selectedRange()
        let currentLineNumber = lineNumber(for: selectedRange.location, in: textView.string)

        // Count lines and draw
        let string = textView.string
        var lineNumber = lineNumber(for: characterRange.location, in: string)

        // Enumerate lines in visible range
        let nsString = string as NSString
        var index = characterRange.location

        while index < NSMaxRange(characterRange) && index < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: index, length: 0))

            // Get the rect for this line
            let glyphRange = layoutManager.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            var lineRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)

            // Adjust for text container inset and convert to gutter coordinates
            lineRect.origin.y += textView.textContainerInset.height
            lineRect.origin.y -= visibleRect.origin.y

            // Draw line number
            let isCurrentLine = lineNumber == currentLineNumber
            drawLineNumber(lineNumber, in: lineRect, isCurrentLine: isCurrentLine)

            lineNumber += 1
            index = NSMaxRange(lineRange)
        }
    }

    /// Draw a single line number
    private func drawLineNumber(_ number: Int, in lineRect: NSRect, isCurrentLine: Bool) {
        let text = "\(number)"
        let color = isCurrentLine ? currentLineColor : lineNumberColor
        let font = isCurrentLine ? NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium) : lineNumberFont

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]

        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()

        // Right-align the number with padding
        let x = ruleThickness - size.width - horizontalPadding
        let y = lineRect.origin.y + (lineRect.height - size.height) / 2

        attributedString.draw(at: NSPoint(x: x, y: y))
    }

    /// Calculate line number for a character index
    private func lineNumber(for characterIndex: Int, in string: String) -> Int {
        guard characterIndex > 0 else { return 1 }

        let nsString = string as NSString
        var lineCount = 1
        var index = 0

        while index < characterIndex && index < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: index, length: 0))
            lineCount += 1
            index = NSMaxRange(lineRange)
        }

        return lineCount
    }

    // MARK: - Width Calculation

    /// Update the ruler thickness based on line count
    func updateWidth() {
        guard let textView = textView else { return }

        let lineCount = countLines(in: textView.string)
        let maxLineNumberString = "\(lineCount)"
        let attributes: [NSAttributedString.Key: Any] = [.font: lineNumberFont]
        let size = (maxLineNumberString as NSString).size(withAttributes: attributes)

        let newWidth = max(minimumWidth, size.width + horizontalPadding * 2)
        if abs(ruleThickness - newWidth) > 1 {
            ruleThickness = newWidth
        }
    }

    /// Count lines in a string
    private func countLines(in string: String) -> Int {
        guard !string.isEmpty else { return 1 }

        var count = 1
        string.enumerateLines { _, _ in
            count += 1
        }
        return count - 1
    }

    // MARK: - Notifications

    @objc private func textDidChange(_ notification: Notification) {
        updateWidth()
        needsDisplay = true
    }

    @objc private func selectionDidChange(_ notification: Notification) {
        needsDisplay = true
    }
}

// MARK: - NSScrollView Extension

extension NSScrollView {
    /// Add a line number gutter to this scroll view
    func addLineNumberGutter(for textView: NSTextView) -> LineNumberGutter {
        let gutter = LineNumberGutter(scrollView: self, orientation: .verticalRuler)
        gutter.textView = textView

        hasVerticalRuler = true
        verticalRulerView = gutter
        rulersVisible = true

        return gutter
    }
}
