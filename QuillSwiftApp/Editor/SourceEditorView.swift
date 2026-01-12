import SwiftUI
import AppKit

/// A SwiftUI wrapper around MarkdownTextView for source editing.
///
/// Provides a native NSTextView-based editor with markdown syntax highlighting.
struct SourceEditorView: NSViewRepresentable {

    // MARK: - Properties

    /// Binding to the document text
    @Binding var text: String

    /// The editor theme to use
    let theme: EditorTheme

    /// Whether to show line numbers
    var showLineNumbers: Bool = false

    /// Optional callback to receive textView reference for scroll sync
    var onTextViewReady: ((MarkdownTextView) -> Void)?

    /// Optional callback when cursor line changes (for status bar)
    var onCursorLineChange: ((String) -> Void)?

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> NSScrollView {
        // Create scroll view
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = theme.background

        // Create the text view using the convenience initializer that sets up the text system
        let textView = MarkdownTextView()

        // Configure text view
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.usesInspectorBar = false
        textView.usesFindBar = true
        textView.isIncrementalSearchingEnabled = true

        // Configure for vertical scrolling with word wrap
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.autoresizingMask = [.width]
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.widthTracksTextView = true
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )

        // Set text view as document view
        scrollView.documentView = textView

        // Create highlighter
        let highlighter = MarkdownHighlighter(theme: theme)
        textView.highlighter = highlighter

        // Apply theme
        textView.applyTheme(theme)
        textView.font = theme.font

        // Set initial text
        textView.string = text

        // Set up text change callback
        textView.onTextChange = { [weak coordinator = context.coordinator] newText in
            coordinator?.textDidChange(newText)
        }

        // Store reference in coordinator
        context.coordinator.textView = textView
        context.coordinator.scrollView = scrollView

        // Notify parent of textView for scroll sync
        DispatchQueue.main.async {
            onTextViewReady?(textView)
        }

        // Add line numbers if enabled
        if showLineNumbers {
            let gutter = scrollView.addLineNumberGutter(for: textView)
            gutter.lineNumberColor = theme.listMarker
            gutter.currentLineColor = theme.text
            gutter.gutterBackgroundColor = theme.background.blended(
                withFraction: 0.05,
                of: theme.text
            ) ?? theme.background
            context.coordinator.lineNumberGutter = gutter
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = context.coordinator.textView else { return }

        // Update text if changed externally
        if textView.string != text {
            textView.setTextFromExternal(text)
        }

        // Update theme if changed
        if textView.highlighter?.theme != theme {
            textView.highlighter?.theme = theme
            textView.applyTheme(theme)
            scrollView.backgroundColor = theme.background
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onCursorLineChange: onCursorLineChange)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        weak var textView: MarkdownTextView?
        weak var scrollView: NSScrollView?
        weak var lineNumberGutter: LineNumberGutter?
        var onCursorLineChange: ((String) -> Void)?

        init(text: Binding<String>, onCursorLineChange: ((String) -> Void)? = nil) {
            _text = text
            self.onCursorLineChange = onCursorLineChange
        }

        func textDidChange(_ newText: String) {
            // Update binding when text changes in the text view
            DispatchQueue.main.async { [weak self] in
                self?.text = newText
            }
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            // This is also called but we use our custom callback for better control
        }

        func textView(_ textView: NSTextView, shouldChangeTextIn affectedCharRange: NSRange, replacementString: String?) -> Bool {
            // Allow all changes (could add validation here if needed)
            return true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            // Update current line for status bar
            guard let textView = notification.object as? NSTextView,
                  let onCursorLineChange = onCursorLineChange else {
                return
            }

            let string = textView.string as NSString
            let selectedRange = textView.selectedRange()

            // Get line range for cursor position
            let lineRange = string.lineRange(for: NSRange(location: selectedRange.location, length: 0))
            let currentLine = string.substring(with: lineRange)

            DispatchQueue.main.async {
                onCursorLineChange(currentLine)
            }
        }

        func undoManager(for view: NSTextView) -> UndoManager? {
            // Use the text view's own undo manager
            return view.undoManager
        }
    }
}

// MARK: - Preview

#Preview {
    SourceEditorView(
        text: .constant("""
        # Hello World

        This is a **bold** and *italic* test.

        ## Features

        - Item 1
        - Item 2
        - [ ] Task item

        ### Code

        Inline `code` example.

        ```swift
        let greeting = "Hello, World!"
        print(greeting)
        ```

        ### Links

        Visit [GitHub](https://github.com) for more.

        > This is a blockquote

        ---

        ~~Strikethrough text~~
        """),
        theme: .light
    )
    .frame(width: 600, height: 400)
}
