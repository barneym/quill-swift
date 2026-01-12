import AppKit
import WebKit
import MarkdownRenderer

/// Exports markdown documents to PDF via print dialog or direct export.
///
/// Uses WKWebView to render HTML then prints to PDF.
/// Supports both interactive print dialog and direct PDF export.
@MainActor
final class PDFExporter: NSObject {

    // MARK: - Properties

    /// The markdown text to export
    private let markdown: String

    /// The document title
    private let title: String

    /// Whether to use dark theme
    private let isDark: Bool

    /// WebView for rendering
    private var webView: WKWebView?

    /// Completion handler for export
    private var completion: ((Bool) -> Void)?

    /// Whether to show print dialog (vs direct export)
    private var showPrintDialog: Bool = true

    /// Target URL for direct export
    private var targetURL: URL?

    // MARK: - Initialization

    init(markdown: String, title: String, isDark: Bool = false) {
        self.markdown = markdown
        self.title = title
        self.isDark = isDark
        super.init()
    }

    // MARK: - Export Methods

    /// Show the print dialog for PDF export
    func showPrintPanel(from window: NSWindow?, completion: @escaping (Bool) -> Void) {
        self.completion = completion
        self.showPrintDialog = true
        setupWebViewAndRender()
    }

    /// Export directly to PDF file
    func exportToPDF(url: URL, completion: @escaping (Bool) -> Void) {
        self.completion = completion
        self.showPrintDialog = false
        self.targetURL = url
        setupWebViewAndRender()
    }

    /// Show save panel and export PDF
    static func showExportPanel(
        markdown: String,
        title: String,
        isDark: Bool,
        completion: @escaping (Bool) -> Void
    ) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(title).pdf"
        panel.allowedContentTypes = [.pdf]
        panel.canCreateDirectories = true
        panel.message = "Export document as PDF"

        panel.begin { response in
            guard response == .OK, let url = panel.url else {
                completion(false)
                return
            }

            let exporter = PDFExporter(markdown: markdown, title: title, isDark: isDark)
            exporter.exportToPDF(url: url, completion: completion)
        }
    }

    // MARK: - Private Methods

    private func setupWebViewAndRender() {
        // Create off-screen webview for rendering
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 800, height: 1000), configuration: configuration)
        webView.navigationDelegate = self
        self.webView = webView

        // Generate HTML using HTMLExporter for consistent styling
        let exporter = HTMLExporter(markdown: markdown, title: title, isDark: isDark)
        let html = exporter.generateHTML()

        // Load HTML
        webView.loadHTMLString(html, baseURL: nil)
    }

    private func printToPDF() {
        guard let webView = webView else {
            completion?(false)
            return
        }

        if showPrintDialog {
            // Interactive print dialog
            let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
            printInfo.topMargin = 36
            printInfo.bottomMargin = 36
            printInfo.leftMargin = 36
            printInfo.rightMargin = 36
            printInfo.isHorizontallyCentered = true
            printInfo.isVerticallyCentered = false
            printInfo.scalingFactor = 1.0
            printInfo.jobDisposition = .spool

            let printOperation = webView.printOperation(with: printInfo)
            printOperation.showsPrintPanel = true
            printOperation.showsProgressPanel = true
            printOperation.jobTitle = title

            printOperation.runModal(
                for: NSApp.keyWindow ?? NSWindow(),
                delegate: self,
                didRun: #selector(printOperationDidRun(_:success:contextInfo:)),
                contextInfo: nil
            )
        } else if let targetURL = targetURL {
            // Direct PDF export
            let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
            printInfo.topMargin = 36
            printInfo.bottomMargin = 36
            printInfo.leftMargin = 36
            printInfo.rightMargin = 36
            printInfo.jobDisposition = .save
            printInfo.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = targetURL

            let printOperation = webView.printOperation(with: printInfo)
            printOperation.showsPrintPanel = false
            printOperation.showsProgressPanel = false

            printOperation.run()
            completion?(true)
        }
    }

    @objc private func printOperationDidRun(
        _ printOperation: NSPrintOperation,
        success: Bool,
        contextInfo: UnsafeMutableRawPointer?
    ) {
        completion?(success)
        cleanup()
    }

    private func cleanup() {
        webView = nil
        completion = nil
    }
}

// MARK: - WKNavigationDelegate

extension PDFExporter: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Wait a moment for rendering to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.printToPDF()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("PDF export failed: \(error)")
        completion?(false)
        cleanup()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        print("PDF export failed: \(error)")
        completion?(false)
        cleanup()
    }
}
