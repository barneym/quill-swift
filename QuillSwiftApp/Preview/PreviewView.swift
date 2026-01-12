import SwiftUI
import WebKit

/// A SwiftUI wrapper around WKWebView for displaying rendered markdown preview.
///
/// The preview is read-only and supports:
/// - Rendered HTML content
/// - Light/dark theme following system appearance
/// - Clickable links that open in the default browser
/// - Security: JavaScript disabled by default
struct PreviewView: NSViewRepresentable {

    // MARK: - Properties

    /// The HTML content to display
    let html: String

    /// The base URL for resolving relative links (typically document directory)
    let baseURL: URL?

    /// The CSS theme to apply
    let theme: PreviewTheme

    // MARK: - NSViewRepresentable

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()

        // Security: Disable JavaScript by default
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false

        // Prevent arbitrary network requests
        configuration.websiteDataStore = .nonPersistent()

        let webView = WKWebView(frame: .zero, configuration: configuration)

        // Set up navigation delegate for link handling
        webView.navigationDelegate = context.coordinator

        // Disable scrolling bounce for cleaner feel
        webView.enclosingScrollView?.hasVerticalScroller = true

        // Allow inspector for debugging during development
        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let fullHTML = theme.wrapHTML(html)
        webView.loadHTMLString(fullHTML, baseURL: baseURL)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    // MARK: - Coordinator

    /// Handles navigation events and link clicks
    class Coordinator: NSObject, WKNavigationDelegate {

        /// Handle link clicks - open external links in default browser
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            // Allow initial page load
            guard navigationAction.navigationType == .linkActivated else {
                decisionHandler(.allow)
                return
            }

            // Get the URL being navigated to
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            // Handle different URL schemes
            switch url.scheme?.lowercased() {
            case "http", "https":
                // Open external links in default browser
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)

            case "mailto":
                // Open mail links in default mail client
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)

            case "file":
                // Handle local file links
                handleLocalFileLink(url, webView: webView)
                decisionHandler(.cancel)

            case nil:
                // Fragment-only links (anchors) - allow navigation
                if url.absoluteString.hasPrefix("#") {
                    decisionHandler(.allow)
                } else {
                    decisionHandler(.cancel)
                }

            default:
                // Block other schemes for security
                decisionHandler(.cancel)
            }
        }

        /// Handle clicks on local file links
        private func handleLocalFileLink(_ url: URL, webView: WKWebView) {
            let path = url.path

            // Check file extension
            let ext = url.pathExtension.lowercased()

            if ["md", "markdown", "mdown", "mkd", "mkdn"].contains(ext) {
                // Markdown file - open in QuillSwift
                // Post notification for app to handle
                NotificationCenter.default.post(
                    name: .openMarkdownFile,
                    object: nil,
                    userInfo: ["url": url]
                )
            } else if FileManager.default.fileExists(atPath: path) {
                // Other file - reveal in Finder
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when a markdown file link is clicked in preview
    static let openMarkdownFile = Notification.Name("openMarkdownFile")
}

// MARK: - Preview

#Preview {
    PreviewView(
        html: """
        <h1>Hello World</h1>
        <p>This is a <strong>test</strong> preview with <em>formatting</em>.</p>
        <ul>
            <li>Item 1</li>
            <li>Item 2</li>
        </ul>
        <pre><code>let x = 5</code></pre>
        """,
        baseURL: nil,
        theme: PreviewTheme.default
    )
    .frame(width: 600, height: 400)
}
