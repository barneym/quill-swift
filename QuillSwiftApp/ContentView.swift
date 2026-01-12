import SwiftUI
import MarkdownRenderer

/// The main content view for a document window.
///
/// Displays either the source editor or preview, toggled via Cmd+E.
/// Phase 2: NSTextView source editor with syntax highlighting + WKWebView preview.
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
            theme: colorScheme == .dark ? .dark : .light
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
            theme: theme
        )
    }

    // MARK: - Actions

    /// Toggle between source and preview modes
    private func toggleViewMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewMode = viewMode == .source ? .preview : .source
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
