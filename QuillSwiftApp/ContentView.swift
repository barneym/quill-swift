import SwiftUI
import WebKit
import MarkdownRenderer

/// The main content view for a document window.
///
/// Displays either the source editor or preview, toggled via Cmd+E.
/// Phase 2: NSTextView source editor with syntax highlighting + WKWebView preview.
/// Phase 7: Scroll sync between source and preview on mode toggle.
/// Phase 8: ThemeManager integration for user customization.
/// Phase 12: Session management and draft storage integration.
struct ContentView: View {

    // MARK: - Properties

    /// Binding to the document being edited
    @Binding var document: MarkdownDocument

    /// The file URL of the document (nil for unsaved)
    let fileURL: URL?

    /// Unique identifier for this document instance
    @State private var documentID = UUID()

    /// Current view mode (source or preview)
    @State private var viewMode: ViewMode = .source

    /// System appearance for theme selection
    @Environment(\.colorScheme) private var colorScheme

    /// Theme manager for user customization
    @ObservedObject private var themeManager = ThemeManager.shared

    /// Session manager for window state tracking
    private let sessionManager = SessionManager.shared

    /// Draft storage for unsaved document recovery
    private let draftStorage = DraftStorage.shared

    // MARK: - Scroll Sync

    /// Scroll synchronization manager
    @State private var scrollSync = ScrollSync()

    /// Reference to source text view for scroll sync
    @State private var sourceTextView: MarkdownTextView?

    /// Reference to preview web view for scroll sync
    @State private var previewWebView: WKWebView?

    /// Current line text for status bar (checkbox detection)
    @State private var currentLine: String?

    /// Track the control active state to determine if this window is key
    @Environment(\.controlActiveState) private var controlActiveState

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Mode indicator bar
            modeIndicator

            // Content area
            switch viewMode {
            case .source:
                sourceEditor
            case .preview:
                previewView
            }

            // Status bar
            StatusBarView(text: document.text, fileURL: fileURL, currentLine: currentLine)
        }
        .frame(minWidth: 600, minHeight: 400)
        .onReceive(NotificationCenter.default.publisher(for: .togglePreview)) { _ in
            // Only respond if this window is the key/active window
            // This prevents all windows from toggling when menu/shortcut is used
            if controlActiveState == .key {
                toggleViewMode()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportHTML)) { _ in
            if controlActiveState == .key {
                exportAsHTML()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .exportPDF)) { _ in
            if controlActiveState == .key {
                exportAsPDF()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyAsHTML)) { _ in
            if controlActiveState == .key {
                copyAsHTML()
            }
        }
        .onAppear {
            registerDocument()
        }
        .onDisappear {
            cleanupDocument()
        }
        .onChange(of: document.text) { _ in
            handleTextChange()
        }
    }

    // MARK: - Views

    /// Mode indicator showing current view state - clickable to toggle modes
    private var modeIndicator: some View {
        HStack {
            Spacer()

            Button(action: toggleViewMode) {
                HStack(spacing: 4) {
                    Image(systemName: viewMode == .source ? "doc.text" : "eye")
                        .font(.caption)
                    Text(viewMode == .source ? "Source" : "Preview")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )
            }
            .buttonStyle(.plain)
            .help("Toggle between Source and Preview (⌘⇧P)")

            Spacer()
        }
        .padding(.vertical, 2)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// Source text editor with markdown syntax highlighting
    /// Phase 2: Custom NSTextView with syntax highlighting
    /// Phase 8: ThemeManager font customization
    private var sourceEditor: some View {
        let baseTheme: EditorTheme = colorScheme == .dark ? .dark : .light
        let customTheme = baseTheme.withFont(
            name: themeManager.editorFontName,
            size: themeManager.editorFontSize
        )

        return SourceEditorView(
            text: $document.text,
            theme: customTheme,
            showLineNumbers: themeManager.showLineNumbers,
            livePreviewEnabled: themeManager.livePreviewEnabled,
            onTextViewReady: { textView in
                sourceTextView = textView
            },
            onCursorLineChange: { line in
                currentLine = line
            }
        )
    }

    /// Preview view showing rendered markdown
    private var previewView: some View {
        let isDark = colorScheme == .dark

        // Configure rendering options with theme-aware code highlighting
        var options = MarkdownRenderer.Options()
        options.isDarkTheme = isDark

        let html = MarkdownRenderer.renderHTML(from: document.text, options: options)
        let theme = isDark ? PreviewTheme.dark : PreviewTheme.light

        return PreviewView(
            html: html,
            baseURL: fileURL?.deletingLastPathComponent(),
            theme: theme,
            fontSize: themeManager.previewFontSize,
            lineHeight: themeManager.previewLineHeight,
            customCSS: themeManager.customCSS.isEmpty ? nil : themeManager.customCSS,
            onWebViewReady: { webView in
                previewWebView = webView
            }
        )
    }

    // MARK: - Actions

    /// Toggle between source and preview modes
    private func toggleViewMode() {
        let previousMode = viewMode

        // Capture position before switching
        capturePosition(from: previousMode)

        withAnimation(.easeInOut(duration: 0.2)) {
            viewMode = viewMode == .source ? .preview : .source
        }

        // Restore position after switching (with delay for view to appear)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            restorePosition(to: viewMode)
        }
    }

    /// Capture scroll position from current mode
    private func capturePosition(from mode: ViewMode) {
        switch mode {
        case .source:
            // Capture source position before switching to preview
            if let textView = sourceTextView {
                _ = scrollSync.captureSourcePosition(from: textView)
            }
        case .preview:
            // Capture preview position before switching to source
            if let webView = previewWebView {
                scrollSync.capturePreviewPosition(from: webView) { _ in }
            }
        }
    }

    /// Restore scroll position after switching to new mode
    private func restorePosition(to mode: ViewMode) {
        switch mode {
        case .preview:
            // Scroll preview to match source position
            if let webView = previewWebView,
               let sourcePosition = scrollSync.lastSourcePosition {
                scrollSync.scrollPreviewToLine(sourcePosition.line, in: webView)
            }
        case .source:
            // Scroll source to match preview position
            if let textView = sourceTextView,
               let previewPosition = scrollSync.lastPreviewPosition {
                scrollSync.scrollSourceToLine(previewPosition.sourceLine, in: textView)
            }
        }
    }

    // MARK: - Export Actions

    /// Document title for export
    private var documentTitle: String {
        fileURL?.deletingPathExtension().lastPathComponent ?? "Untitled"
    }

    /// Export document as HTML file
    private func exportAsHTML() {
        HTMLExporter.showExportPanel(
            markdown: document.text,
            title: documentTitle,
            isDark: colorScheme == .dark
        ) { success in
            if !success {
                print("HTML export cancelled or failed")
            }
        }
    }

    /// Export document as PDF file
    private func exportAsPDF() {
        PDFExporter.showExportPanel(
            markdown: document.text,
            title: documentTitle,
            isDark: colorScheme == .dark
        ) { success in
            if !success {
                print("PDF export cancelled or failed")
            }
        }
    }

    /// Copy document as HTML to clipboard
    private func copyAsHTML() {
        let exporter = HTMLExporter(
            markdown: document.text,
            title: documentTitle,
            isDark: colorScheme == .dark
        )
        exporter.copyToClipboard()
    }

    // MARK: - Session Management

    /// Register document with session manager on appear
    private func registerDocument() {
        // Get window frame if available
        let frame = NSApp.keyWindow?.frame ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        // Register with session manager
        sessionManager.registerWindow(
            documentID: documentID,
            fileURL: fileURL,
            frame: frame,
            isDirty: false
        )

        // Register with draft storage for unsaved documents
        if fileURL == nil {
            draftStorage.register(
                documentID: documentID,
                text: document.text,
                title: documentTitle
            )
        }
    }

    /// Clean up document registration on disappear
    private func cleanupDocument() {
        // Remove from session manager
        sessionManager.removeWindow(documentID: documentID)

        // Remove draft if document was saved (has fileURL) or explicitly closed
        if fileURL != nil {
            draftStorage.removeDraft(documentID: documentID)
        }
    }

    /// Handle text changes for draft storage
    private func handleTextChange() {
        // Mark document as dirty
        sessionManager.markDirty(documentID: documentID, isDirty: true)

        // Update draft for unsaved documents
        if fileURL == nil {
            draftStorage.updateDraft(documentID: documentID, text: document.text)
        }
    }
}

// MARK: - View Mode

/// The current editing/viewing mode
enum ViewMode {
    case source
    case preview
}

// MARK: - Preview

#Preview {
    ContentView(
        document: .constant(MarkdownDocument(text: """
        # Hello World

        This is a **test** with _formatting_.

        ## Features

        - Item 1
        - Item 2
        - Item 3

        ### Code

        ```swift
        let greeting = "Hello, World!"
        print(greeting)
        ```

        ### Table

        | Name | Age | City |
        |------|-----|------|
        | Alice | 30 | NYC |
        | Bob | 25 | LA |

        ### Links

        Visit [GitHub](https://github.com) for more.
        """)),
        fileURL: URL(fileURLWithPath: "/Users/demo/Documents/Example.md")
    )
}
