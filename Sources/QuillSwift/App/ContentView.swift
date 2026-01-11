import SwiftUI

/// The main content view for a document window.
///
/// Displays either the source editor or preview, toggled via Cmd+E.
/// Phase 0: Only source editing with basic TextEditor.
/// Future phases will add preview rendering and enhanced editing.
struct ContentView: View {

    // MARK: - Properties

    /// Binding to the document being edited
    @Binding var document: MarkdownDocument

    /// Current view mode (source or preview)
    @State private var viewMode: ViewMode = .source

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
                previewPlaceholder
            }
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

    /// Source text editor
    /// Phase 0: Basic SwiftUI TextEditor
    /// Future: Custom NSTextView with syntax highlighting
    private var sourceEditor: some View {
        TextEditor(text: $document.text)
            .font(.system(.body, design: .monospaced))
            .padding()
    }

    /// Preview placeholder
    /// Phase 0: Just a placeholder message
    /// Phase 1+: WKWebView with rendered markdown
    private var previewPlaceholder: some View {
        VStack {
            Spacer()
            Text("Preview not yet implemented")
                .foregroundColor(.secondary)
            Text("Press ⌘E to return to source")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
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
    ContentView(document: .constant(MarkdownDocument(text: "# Hello\n\nThis is a test.")))
}
