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

    /// Batch replacement tracking for Find & Replace optimization
    private var batchReplacementCount = 0
    private var batchReplacementTimer: Timer?
    private let batchReplacementThreshold = 5  // Trigger batch mode after 5 rapid replacements
    private var isInBatchMode = false

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

        // Skip highlighting during batch replacements (it will be done after batch ends)
        guard !isInBatchMode else {
            // Still notify about text change but don't highlight yet
            onTextChange?(string)
            return
        }

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

    // MARK: - Find & Replace Optimization

    /// Override to batch rapid replacements (e.g., from Find & Replace All)
    override func replaceCharacters(in range: NSRange, with string: String) {
        // Track rapid replacements to detect batch operations
        batchReplacementCount += 1

        // Enter batch mode if we've hit the threshold
        if batchReplacementCount >= batchReplacementThreshold && !isInBatchMode {
            isInBatchMode = true
            textStorage?.beginEditing()
        }

        // Reset the batch timer
        batchReplacementTimer?.invalidate()
        batchReplacementTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.endBatchReplacementMode()
        }

        // Perform the actual replacement
        super.replaceCharacters(in: range, with: string)
    }

    /// End batch replacement mode and finalize edits
    private func endBatchReplacementMode() {
        if isInBatchMode {
            textStorage?.endEditing()
            isInBatchMode = false

            // Re-highlight after batch operation
            DispatchQueue.main.async { [weak self] in
                self?.highlightAllText()
            }
        }

        batchReplacementCount = 0
        batchReplacementTimer = nil
    }

    /// Override to intercept Replace All for optimized handling
    override func performFindPanelAction(_ sender: Any?) {
        // Check if this is Replace All action
        guard let action = (sender as? NSMenuItem)?.tag else {
            super.performFindPanelAction(sender)
            return
        }

        // NSTextFinder.Action.replaceAll.rawValue == 12
        if action == 12 {
            performOptimizedReplaceAllFromFinder()
        } else {
            super.performFindPanelAction(sender)
        }
    }

    /// Get current Find panel search and replacement strings and perform optimized replace
    private func performOptimizedReplaceAllFromFinder() {
        // Get find/replace strings from the shared find pasteboard
        guard let findPasteboard = NSPasteboard(name: .find).string(forType: .string),
              !findPasteboard.isEmpty else {
            // Fall back to system behavior if we can't get find string
            super.performFindPanelAction(NSTextFinder.Action.replaceAll.rawValue as AnyObject)
            return
        }

        // Get replacement string from the find panel's text field
        // Unfortunately there's no standard way to get this, so we use the Replace pasteboard
        let replacePasteboard = NSPasteboard(name: NSPasteboard.Name("Replace"))
        let replaceString = replacePasteboard.string(forType: .string) ?? ""

        // Check if case-insensitive search is enabled (stored in user defaults)
        var options: NSString.CompareOptions = []
        if !UserDefaults.standard.bool(forKey: "NSFindPanelCaseInsensitiveSearch") {
            options = []
        } else {
            options = [.caseInsensitive]
        }

        // Perform optimized replacement
        let count = performOptimizedReplaceAll(find: findPasteboard, replaceWith: replaceString, options: options)

        // Show result in a subtle way (optional: could use notification)
        if count > 0 {
            print("Replaced \(count) occurrences")
        }
    }

    /// Perform optimized Replace All to avoid UI freeze on large files
    /// Uses single batch edit operation instead of individual replacements
    func performOptimizedReplaceAll(find searchString: String, replaceWith replacement: String, options: NSString.CompareOptions = []) -> Int {
        guard let textStorage = textStorage else { return 0 }
        guard !searchString.isEmpty else { return 0 }

        let content = textStorage.string

        // Find all match ranges first (working backwards to maintain range validity)
        var matches: [NSRange] = []
        var searchRange = NSRange(location: 0, length: content.count)
        let nsContent = content as NSString

        while searchRange.location < nsContent.length {
            let foundRange = nsContent.range(of: searchString, options: options, range: searchRange)
            if foundRange.location == NSNotFound {
                break
            }
            matches.append(foundRange)
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = nsContent.length - searchRange.location
        }

        guard !matches.isEmpty else { return 0 }

        // Batch all changes in a single undo group
        undoManager?.beginUndoGrouping()
        textStorage.beginEditing()

        // Replace from end to start to maintain range validity
        for range in matches.reversed() {
            textStorage.replaceCharacters(in: range, with: replacement)
        }

        textStorage.endEditing()
        undoManager?.endUndoGrouping()

        // Re-highlight after replacement
        DispatchQueue.main.async { [weak self] in
            self?.highlightAllText()
        }

        // Notify about text change
        onTextChange?(string)

        return matches.count
    }

    // MARK: - Cmd-Click Link Handling

    override func mouseDown(with event: NSEvent) {
        // Check for Cmd-Click (command modifier)
        if event.modifierFlags.contains(.command) {
            let point = convert(event.locationInWindow, from: nil)
            if handleCmdClickAtPoint(point) {
                return // Link was opened, don't pass to super
            }
        }

        super.mouseDown(with: event)
    }

    /// Handle Cmd-Click at a specific point, returning true if a link was opened
    private func handleCmdClickAtPoint(_ point: NSPoint) -> Bool {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else {
            return false
        }

        // Convert point to character index
        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

        // Get the line containing this character
        let nsString = string as NSString
        guard charIndex < nsString.length else { return false }

        let lineRange = nsString.lineRange(for: NSRange(location: charIndex, length: 0))
        let lineText = nsString.substring(with: lineRange)

        // Try to find a URL at this position
        if let url = findURLAtIndex(charIndex, inLine: lineText, lineStart: lineRange.location) {
            NSWorkspace.shared.open(url)
            return true
        }

        return false
    }

    /// Find a URL at the given character index within a line
    private func findURLAtIndex(_ charIndex: Int, inLine lineText: String, lineStart: Int) -> URL? {
        let localIndex = charIndex - lineStart

        // Pattern 1: Markdown link syntax [text](url)
        if let url = findMarkdownLinkAtIndex(localIndex, in: lineText) {
            return url
        }

        // Pattern 2: Raw URL (http://, https://, file://)
        if let url = findRawURLAtIndex(localIndex, in: lineText) {
            return url
        }

        // Pattern 3: Autolink syntax <url>
        if let url = findAutolinkAtIndex(localIndex, in: lineText) {
            return url
        }

        return nil
    }

    /// Find markdown link [text](url) at index
    private func findMarkdownLinkAtIndex(_ localIndex: Int, in lineText: String) -> URL? {
        // Match [text](url) pattern
        let pattern = #"\[([^\]]+)\]\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let nsLine = lineText as NSString
        let matches = regex.matches(in: lineText, range: NSRange(location: 0, length: nsLine.length))

        for match in matches {
            // Check if localIndex falls within the entire match
            if localIndex >= match.range.location && localIndex < NSMaxRange(match.range) {
                // Extract the URL part (group 2)
                if match.numberOfRanges >= 3 {
                    let urlRange = match.range(at: 2)
                    let urlString = nsLine.substring(with: urlRange)
                    return URL(string: urlString)
                }
            }
        }

        return nil
    }

    /// Find raw URL at index (http://, https://, file://)
    private func findRawURLAtIndex(_ localIndex: Int, in lineText: String) -> URL? {
        // Match URLs starting with http://, https://, or file://
        let pattern = #"(https?://|file://)[^\s<>\[\]()\"'`]+"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

        let nsLine = lineText as NSString
        let matches = regex.matches(in: lineText, range: NSRange(location: 0, length: nsLine.length))

        for match in matches {
            if localIndex >= match.range.location && localIndex < NSMaxRange(match.range) {
                let urlString = nsLine.substring(with: match.range)
                return URL(string: urlString)
            }
        }

        return nil
    }

    /// Find autolink <url> at index
    private func findAutolinkAtIndex(_ localIndex: Int, in lineText: String) -> URL? {
        // Match <url> pattern (autolinks)
        let pattern = #"<(https?://[^>]+)>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }

        let nsLine = lineText as NSString
        let matches = regex.matches(in: lineText, range: NSRange(location: 0, length: nsLine.length))

        for match in matches {
            if localIndex >= match.range.location && localIndex < NSMaxRange(match.range) {
                if match.numberOfRanges >= 2 {
                    let urlRange = match.range(at: 1)
                    let urlString = nsLine.substring(with: urlRange)
                    return URL(string: urlString)
                }
            }
        }

        return nil
    }

    // MARK: - Cursor Feedback for Links

    override func resetCursorRects() {
        super.resetCursorRects()

        // When command is held, we could change cursor over links
        // This is complex to implement correctly, so for now we rely on
        // the visual feedback of the syntax highlighting showing links
    }

    // MARK: - Cleanup

    deinit {
        highlightDebounceTimer?.invalidate()
        batchReplacementTimer?.invalidate()
    }
}
