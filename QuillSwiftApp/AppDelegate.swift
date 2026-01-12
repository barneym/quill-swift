import AppKit

/// App delegate for managing window tabbing and macOS integration.
///
/// This delegate enables Safari/Finder-style tabbed windows:
/// - Multiple documents can open as tabs in a single window
/// - Tabs can be dragged out to create new windows
/// - Tabs can be dragged between windows to dock
/// - Cmd+T creates a new tab
/// - Standard macOS tab bar appearance
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Enable automatic window tabbing (default on macOS, but ensure it's on)
        NSWindow.allowsAutomaticWindowTabbing = true

        // Configure any existing windows
        configureAllWindows()

        // Listen for new windows being created
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidBecomeKey(_:)),
            name: NSWindow.didBecomeKeyNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Window Configuration

    /// Configure all current windows for tabbing
    private func configureAllWindows() {
        DispatchQueue.main.async {
            for window in NSApp.windows {
                self.configureWindow(window)
            }
        }
    }

    /// Configure a single window for tabbed document editing
    private func configureWindow(_ window: NSWindow) {
        // Skip non-document windows (sheets, panels, etc.)
        guard window.isDocumentEdited || window.representedURL != nil || window.title.contains("Untitled") || !window.title.isEmpty else {
            return
        }

        // Enable tabbing - .preferred ensures tab bar is always visible
        window.tabbingMode = .preferred

        // Set tabbing identifier so all document windows can group together
        window.tabbingIdentifier = "com.quillswift.document"

        // Configure title bar appearance for modern look
        window.titlebarAppearsTransparent = false

        if #available(macOS 11, *) {
            // Use unified toolbar style for clean appearance
            window.toolbarStyle = .automatic
        }

        if #available(macOS 12, *) {
            // Automatic separator adapts to content
            window.titlebarSeparatorStyle = .automatic
        }
    }

    // MARK: - Window Notifications

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }

        // Configure new windows as they become key
        if window.tabbingMode != .preferred {
            configureWindow(window)
        }
    }

    // MARK: - Menu Actions

    /// Handle New Tab menu item (Cmd+T)
    /// This is called by the standard macOS menu
    @objc func newWindowForTab(_ sender: Any?) {
        // The system handles this automatically via DocumentGroup
        // but we ensure the window is configured for tabbing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApp.keyWindow {
                self.configureWindow(window)
            }
        }
    }
}
