import SwiftUI
import WebKit
import MarkdownRenderer

/// The main content view for a document window.
///
/// Displays either the source editor or preview, toggled via Cmd+E.
/// Phase 2: NSTextView source editor with syntax highlighting + WKWebView preview.
/// Phase 7: Scroll sync between source and preview on mode toggle.
struct ContentView: View {

    // MARK: - Properties

    /// Binding to the document being edited
    @Binding var document: MarkdownDocument

    /// The file URL of the document (nil for unsaved)
    let fileURL: URL?

    /// Current view mode (source or preview)
    @State private var viewMode: ViewMode = .source

    /// System appearance for theme selection
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Scroll Sync

    /// Scroll synchronization manager
    @State private var scrollSync = ScrollSync()

    /// Reference to source text view for scroll sync
    @State private var sourceTextView: MarkdownTextView?

    /// Reference to preview web view for scroll sync
    @State private var previewWebView: WKWebView?

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
            StatusBarView(text: document.text, fileURL: fileURL)
        }
        .frame(minWidth: 600, minHeight: 400)
        .onReceive(NotificationCenter.default.publisher(for: .togglePreview)) { _ in
            toggleViewMode()
        }
    }

    // MARK: - Views

    /// Mode indicator showing current view state
    private var modeIndicator: some View {
        HStack {
            Spacer()

            Text(viewMode == .source ? "Source" : "Preview")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Capsule()
                        .fill(Color.secondary.opacity(0.1))
                )

            Spacer()
        }
        .padding(.vertical, 4)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    /// Source text editor with markdown syntax highlighting
    /// Phase 2: Custom NSTextView with syntax highlighting
    private var sourceEditor: some View {
        SourceEditorView(
            text: $document.text,
            theme: colorScheme == .dark ? .dark : .light,
            onTextViewReady: { textView in
                sourceTextView = textView
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
