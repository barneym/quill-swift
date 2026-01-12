import AppKit

/// A custom NSTextView optimized for markdown editing.
///
/// Integrates with MarkdownHighlighter for syntax coloring and
/// provides markdown-specific editing behaviors.
class MarkdownTextView: NSTextView {

    // MARK: - Properties

    /// The syntax highlighter for this text view
    var highlighter: MarkdownHighlighter? {
        didSet {
            if highlighter != nil {
                highlightVisibleText()
            }
        }
    }

    /// Callback when text changes
    var onTextChange: ((String) -> Void)?

    /// Debounce timer for highlighting
    private var highlightDebounceTimer: Timer?

    /// Whether we're currently updating from external source (to prevent loops)
    private var isUpdatingFromExternal = false

    // MARK: - Initialization

    /// Convenience initializer that creates a properly configured text system
    convenience init() {
        // Create the text system components
        let textStorage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        let textContainer = NSTextContainer(containerSize: NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        ))
        textContainer.widthTracksTextView = true
        layoutManager.addTextContainer(textContainer)

        self.init(frame: .zero, textContainer: textContainer)
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Basic text view setup
        isRichText = false
        allowsUndo = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false

        // Use insertion point color matching theme
        insertionPointColor = .labelColor

        // Enable automatic link detection but don't make them clickable in source
        isAutomaticLinkDetectionEnabled = false

        // Text container setup for proper margins
        textContainerInset = NSSize(width: 8, height: 8)
    }

    // MARK: - Theme Application

    /// Apply a theme to this text view
    func applyTheme(_ theme: EditorTheme) {
        backgroundColor = theme.background
        insertionPointColor = theme.text

        // Update highlighter theme
        highlighter?.theme = theme

        // Re-highlight with new theme
        highlightVisibleText()
    }

    // MARK: - Text Updates

    /// Set text content from external source (document binding)
    func setTextFromExternal(_ newText: String) {
        guard !isUpdatingFromExternal else { return }
        guard string != newText else { return }

        isUpdatingFromExternal = true
        defer { isUpdatingFromExternal = false }

        // Preserve selection if possible
        let selectedRanges = self.selectedRanges

        // Update text
        string = newText

        // Restore selection if still valid
        if let firstRange = selectedRanges.first?.rangeValue {
            let maxLocation = (string as NSString).length
            if firstRange.location <= maxLocation {
                let adjustedRange = NSRange(
                    location: min(firstRange.location, maxLocation),
                    length: min(firstRange.length, maxLocation - min(firstRange.location, maxLocation))
                )
                setSelectedRange(adjustedRange)
            }
        }

        // Highlight the new content
        highlightAllText()
    }

    // MARK: - Text Change Handling

    override func didChangeText() {
        super.didChangeText()

        // Don't process if updating from external source
        guard !isUpdatingFromExternal else { return }

        // Notify about text change
        onTextChange?(string)

        // Schedule highlighting with debounce
        scheduleHighlighting()
    }

    /// Schedule highlighting with a short debounce to avoid excessive processing
    private func scheduleHighlighting() {
        highlightDebounceTimer?.invalidate()
        highlightDebounceTimer = Timer.scheduledTimer(
            withTimeInterval: 0.05, // 50ms debounce
            repeats: false
        ) { [weak self] _ in
            self?.highlightVisibleText()
        }
    }

    // MARK: - Highlighting

    /// Highlight all text in the document
    func highlightAllText() {
        guard let textStorage = textStorage,
              let highlighter = highlighter else { return }

        highlighter.highlight(textStorage)
    }

    /// Highlight only the visible text for performance
    func highlightVisibleText() {
        guard let textStorage = textStorage,
              let highlighter = highlighter,
              let layoutManager = layoutManager,
              let textContainer = textContainer else { return }

        // Get visible rect
        let visibleRect = enclosingScrollView?.documentVisibleRect ?? bounds

        // Get glyph range for visible rect
        let glyphRange = layoutManager.glyphRange(forBoundingRect: visibleRect, in: textContainer)

        // Convert to character range
        let charRange = layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)

        // Expand to full lines and add some buffer
        let string = textStorage.string
        guard let stringRange = Range(charRange, in: string) else { return }

        let lineRange = string.lineRange(for: stringRange)
        var expandedNSRange = NSRange(lineRange, in: string)

        // Add buffer lines before and after for smoother scrolling
        let bufferLines = 10
        let nsString = string as NSString

        // Expand backwards
        var startLine = expandedNSRange.location
        for _ in 0..<bufferLines {
            if startLine == 0 { break }
            let prevLineRange = nsString.lineRange(for: NSRange(location: startLine - 1, length: 0))
            startLine = prevLineRange.location
        }

        // Expand forwards
        var endLocation = NSMaxRange(expandedNSRange)
        for _ in 0..<bufferLines {
            if endLocation >= nsString.length { break }
            let nextLineRange = nsString.lineRange(for: NSRange(location: endLocation, length: 0))
            endLocation = NSMaxRange(nextLineRange)
        }

        expandedNSRange = NSRange(location: startLine, length: endLocation - startLine)

        // Highlight the expanded range
        highlighter.highlightRange(expandedNSRange, in: textStorage)
    }

    // MARK: - Scroll Handling

    override func scrollRangeToVisible(_ range: NSRange) {
        super.scrollRangeToVisible(range)

        // Re-highlight when scrolling
        DispatchQueue.main.async { [weak self] in
            self?.highlightVisibleText()
        }
    }

    // MARK: - View Lifecycle

    override func viewDidMoveToSuperview() {
        super.viewDidMoveToSuperview()

        if superview != nil {
            // Initial highlighting when added to view hierarchy
            DispatchQueue.main.async { [weak self] in
                self?.highlightAllText()
            }
        }
    }

    override func layout() {
        super.layout()

        // Re-highlight when layout changes (window resize, etc.)
        highlightVisibleText()
    }

    // MARK: - Smart Editing

    /// Enable or disable smart list continuation
    var smartListsEnabled: Bool = true

    /// Enable or disable auto-completion (brackets, quotes)
    var autoCompletionEnabled: Bool = true

    // MARK: - Key Event Handling

    override func insertNewline(_ sender: Any?) {
        // Try smart list continuation first
        if smartListsEnabled && SmartLists.handleEnter(in: self) {
            return
        }

        // Default behavior
        super.insertNewline(sender)
    }

    override func insertTab(_ sender: Any?) {
        // Try smart list indentation first
        if smartListsEnabled && SmartLists.handleTab(in: self, shift: false) {
            return
        }

        // Default: insert spaces instead of tab
        insertText("    ", replacementRange: selectedRange())
    }

    override func insertBacktab(_ sender: Any?) {
        // Try smart list outdentation
        if smartListsEnabled && SmartLists.handleTab(in: self, shift: true) {
            return
        }

        // Default behavior
        super.insertBacktab(sender)
    }

    override func deleteBackward(_ sender: Any?) {
        // Try auto-completion pair deletion first
        if autoCompletionEnabled && AutoCompletion.handleBackspace(in: self) {
            return
        }

        // Default behavior
        super.deleteBackward(sender)
    }

    override func insertText(_ string: Any, replacementRange: NSRange) {
        // Handle character insertion for auto-completion
        if autoCompletionEnabled,
           let text = string as? String,
           text.count == 1,
           let character = text.first {

            // Special handling for backtick (potential code block)
            if character == "`" {
                if AutoCompletion.handleTripleBacktick(in: self) {
                    return
                }
            }

            // General auto-completion
            if AutoCompletion.handleCharacterInsertion(character, in: self) {
                return
            }
        }

        // Default behavior
        super.insertText(string, replacementRange: replacementRange)
    }

    // MARK: - Cleanup

    deinit {
        highlightDebounceTimer?.invalidate()
    }
}
