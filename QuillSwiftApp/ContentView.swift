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

    /// Open the source find bar once the source editor appears (search carried over from preview)
    @State private var carryFindToSource = false

    /// Track the control active state to determine if this window is key
    @Environment(\.controlActiveState) private var controlActiveState

    /// Watches the file for changes made by other applications
    @StateObject private var fileMonitor = FileChangeMonitor()

    /// Find bar state for preview mode
    @StateObject private var previewFind = PreviewFindModel()

    /// Settings → Preview → "Render HTML in Markdown"
    @AppStorage(PreviewSecurity.renderRawHTMLKey) private var renderRawHTML = true

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // External change panel
            if let change = fileMonitor.change {
                FileChangedBanner(
                    change: change,
                    fileName: fileURL?.lastPathComponent ?? documentTitle,
                    hasUnsavedEdits: fileMonitor.hasUnsavedEdits,
                    onReload: reloadFromDisk,
                    onDismiss: fileMonitor.dismiss
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Mode indicator bar
            modeIndicator

            if viewMode == .preview && previewFind.isVisible {
                PreviewFindBar(model: previewFind)
            }

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
        .animation(.easeInOut(duration: 0.2), value: fileMonitor.change)
        .onReceive(NotificationCenter.default.publisher(for: .reloadFromDisk)) { _ in
            if controlActiveState == .key {
                confirmAndReloadFromDisk()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .findAction)) { notification in
            if controlActiveState == .key,
               let raw = notification.userInfo?["action"] as? Int,
               let action = NSTextFinder.Action(rawValue: raw) {
                performFind(action)
            }
        }
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
            startFileMonitor()
        }
        .onDisappear {
            cleanupDocument()
            fileMonitor.stop()
        }
        .onChange(of: document.text) { _ in
            handleTextChange()
        }
        .onChange(of: fileURL) { newURL in
            if let newURL { HistoryStore.shared.recordVisit(newURL) }
            startFileMonitor()
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
                scrollSync.applyPending(to: textView)
                if carryFindToSource {
                    carryFindToSource = false
                    DispatchQueue.main.async {
                        textView.window?.makeFirstResponder(textView)
                        textView.performFindAction(.showFindInterface)
                    }
                }
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
        options.includeSourceLines = true
        options.rawHTMLPolicy = renderRawHTML ? .safe : .escape

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
                previewFind.webView = webView
            },
            onCheckboxToggle: { index, isChecked in
                toggleCheckboxInSource(at: index, checked: isChecked)
            },
            enableMermaid: themeManager.enableMermaid,
            enableMath: themeManager.enableMath,
            onLoadFinished: { webView in
                scrollSync.applyPending(to: webView)
                previewFind.search()
            }
        )
    }

    /// Toggle a checkbox in the source markdown at the given index
    private func toggleCheckboxInSource(at index: Int, checked: Bool) {
        var text = document.text

        // Pattern to match checkbox lines: - [ ] or - [x] or * [ ] etc.
        let pattern = #"^(\s*[-*+]|\s*\d+\.)\s+\[[ xX]\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .anchorsMatchLines) else {
            return
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))

        // Find the match at the specified index
        guard index < matches.count else { return }
        let match = matches[index]

        // Find the checkbox character position (the character inside [ ])
        let matchedString = nsText.substring(with: match.range)
        if let bracketRange = matchedString.range(of: "[") {
            let bracketOffset = matchedString.distance(from: matchedString.startIndex, to: bracketRange.lowerBound)
            let checkboxCharLocation = match.range.location + bracketOffset + 1

            // Replace the checkbox character
            let newChar = checked ? "x" : " "
            let replaceRange = NSRange(location: checkboxCharLocation, length: 1)

            if let range = Range(replaceRange, in: text) {
                text.replaceSubrange(range, with: newChar)
                document.text = text
            }
        }
    }

    // MARK: - Actions

    /// Toggle between source and preview modes, keeping the reading position
    /// (see ScrollSync) and any active search.
    private func toggleViewMode() {
        switch viewMode {
        case .source:
            if let textView = sourceTextView {
                scrollSync.captureSource(from: textView)
            }
            let sourceFindVisible = sourceTextView?.enclosingScrollView?.isFindBarVisible ?? false
            switchMode(to: .preview)
            currentLine = nil
            if sourceFindVisible {
                previewFind.show()
            }
        case .preview:
            let finish = {
                carryFindToSource = previewFind.isVisible
                if previewFind.isVisible { previewFind.close() }
                switchMode(to: .source)
            }
            if let webView = previewWebView {
                scrollSync.capturePreview(from: webView, completion: finish)
            } else {
                finish()
            }
        }
    }

    private func switchMode(to mode: ViewMode) {
        withAnimation(.easeInOut(duration: 0.2)) {
            viewMode = mode
        }
    }

    // MARK: - Find

    /// Route a Find menu command to the source find bar or the preview find bar.
    private func performFind(_ action: NSTextFinder.Action) {
        switch viewMode {
        case .source:
            guard let textView = sourceTextView else { return }
            textView.window?.makeFirstResponder(textView)
            textView.performFindAction(action)
        case .preview:
            switch action {
            case .showFindInterface, .showReplaceInterface:
                previewFind.show()
            case .nextMatch:
                previewFind.next()
            case .previousMatch:
                previewFind.previous()
            case .setSearchString:
                previewFind.useSelection()
            case .hideFindInterface:
                previewFind.close()
            default:
                break
            }
        }
    }

    // MARK: - External Changes

    private func startFileMonitor() {
        guard let fileURL else {
            fileMonitor.stop()
            return
        }
        fileMonitor.start(
            url: fileURL,
            currentText: { document.text },
            savedModificationDate: { NSDocumentController.shared.document(for: fileURL)?.fileModificationDate }
        )
    }

    /// File > Reload from Disk: confirm first if there are unsaved edits.
    private func confirmAndReloadFromDisk() {
        guard let fileURL else {
            NSSound.beep()
            return
        }
        guard fileMonitor.hasUnsavedEdits else {
            reloadFromDisk()
            return
        }
        let alert = NSAlert()
        alert.messageText = "Reload “\(fileURL.lastPathComponent)” from disk?"
        alert.informativeText = "You have unsaved changes. Reloading will discard them."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Discard & Reload")
        alert.addButton(withTitle: "Cancel")
        let handler: (NSApplication.ModalResponse) -> Void = { response in
            if response == .alertFirstButtonReturn { reloadFromDisk() }
        }
        if let window = sourceTextView?.window ?? previewWebView?.window ?? NSApp.keyWindow {
            alert.beginSheetModal(for: window, completionHandler: handler)
        } else {
            handler(alert.runModal())
        }
    }

    /// Replace the document with the file's current contents.
    ///
    /// Goes through NSDocument's revert so the window's edited state and undo
    /// history reset exactly as with File > Revert To > Last Saved Version.
    private func reloadFromDisk() {
        guard let fileURL else { return }
        if let nsDocument = NSDocumentController.shared.document(for: fileURL), let type = nsDocument.fileType {
            do {
                try nsDocument.revert(toContentsOf: fileURL, ofType: type)
                fileMonitor.markInSync()
                return
            } catch {
                print("Revert failed, falling back to direct read: \(error)")
            }
        }
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            NSSound.beep()
            return
        }
        document.text = text
        fileMonitor.markInSync()
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

    /// Copy as clean HTML: the source selection if there is one, else the whole document
    private func copyAsHTML() {
        var markdown = document.text
        if viewMode == .source, let textView = sourceTextView {
            let selected = textView.selectedRange()
            if selected.length > 0 {
                markdown = (textView.string as NSString).substring(with: selected)
            }
        }
        HTMLExporter.copyCleanHTML(markdown: markdown)
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
        if let fileURL { HistoryStore.shared.recordVisit(fileURL) }

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
        fileMonitor.documentTextDidChange()

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
