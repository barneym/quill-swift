import AppKit

/// App delegate for Safari-style window tabbing and macOS integration.
///
/// Mirrors Safari's tab behavior:
/// - ⌃⇥ / ⌃⇧⇥ and ⇧⌘] / ⇧⌘[ move to the next / previous tab (wrapping),
///   even while the editor has focus (NSTextView would otherwise take ⌃⇥)
/// - ⌘T opens a new tab in the current window; ⇧⌘T reopens the last closed tab
/// - Documents opened while a document window is frontmost join it as a tab
///   (Settings → "Open documents in tabs"), like Safari's "open in tabs"
/// - ⌥⌘1–6 / ⌥⌘0 set headings (Google Docs/Word convention), alongside ⌘1–6 / ⌘0
/// - ⌘` cycles windows (tab groups), which AppKit provides for every app
/// - Tabs can be dragged out into windows, merged, and shown in the tab
///   overview via the standard Window menu items AppKit adds
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Constants

    static let documentTabbingIdentifier = "com.quillswift.document"

    /// UserDefaults key for joining newly opened documents to the front window as tabs
    static let openDocumentsInTabsKey = "openDocumentsInTabs"

    /// Windows opened during launch belong to state restoration, which restores
    /// its own window/tab layout; don't regroup them.
    private static let launchSettleInterval: TimeInterval = 2

    // MARK: - State

    private var launchDate = Date()
    private var keyMonitor: Any?

    /// Windows already configured (and considered for tab joining)
    private var knownWindows = Set<ObjectIdentifier>()

    /// The most recent key document window, the host for new tabs
    private weak var lastDocumentWindow: NSWindow?

    /// Window that asked for a new tab (⌘T or the tab bar's + button)
    private weak var pendingTabHost: NSWindow?

    /// Files of recently closed document windows, most recent last (for ⇧⌘T)
    private var recentlyClosed: [URL] = []

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        launchDate = Date()
        UserDefaults.standard.register(defaults: [Self.openDocumentsInTabsKey: true])
        NSWindow.allowsAutomaticWindowTabbing = true

        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(windowDidBecomeKey(_:)),
                           name: NSWindow.didBecomeKeyNotification, object: nil)
        center.addObserver(self, selector: #selector(windowWillClose(_:)),
                           name: NSWindow.willCloseNotification, object: nil)

        installTabKeyMonitor()

        DispatchQueue.main.async {
            for window in NSApp.windows where self.isDocumentWindow(window) {
                self.configureWindow(window)
                self.knownWindows.insert(ObjectIdentifier(window))
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        NotificationCenter.default.removeObserver(self)
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
    }

    // MARK: - Window Configuration

    private func isDocumentWindow(_ window: NSWindow) -> Bool {
        NSDocumentController.shared.document(for: window) != nil
    }

    /// Configure a document window for tabbed editing
    private func configureWindow(_ window: NSWindow) {
        window.tabbingMode = .preferred
        window.tabbingIdentifier = Self.documentTabbingIdentifier
        window.titlebarAppearsTransparent = false
        window.toolbarStyle = .automatic
        window.titlebarSeparatorStyle = .automatic
    }

    // MARK: - Window Notifications

    @objc private func windowDidBecomeKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, isDocumentWindow(window) else { return }

        let isNew = knownWindows.insert(ObjectIdentifier(window)).inserted
        if isNew {
            configureWindow(window)
            joinTabGroupIfAppropriate(window)
        }
        lastDocumentWindow = window
    }

    /// Put a newly opened document window into the host window's tab group.
    private func joinTabGroupIfAppropriate(_ window: NSWindow) {
        let requestedTab = pendingTabHost != nil
        let host = pendingTabHost ?? lastDocumentWindow
        pendingTabHost = nil

        guard let host, host !== window, host.isVisible, !host.isMiniaturized,
              window.tabbedWindows == nil || window.tabbedWindows?.count == 1 else {
            return
        }
        guard requestedTab || shouldOpenDocumentsInTabs else { return }

        host.addTabbedWindow(window, ordered: .above)
        window.makeKeyAndOrderFront(nil)
    }

    private var shouldOpenDocumentsInTabs: Bool {
        UserDefaults.standard.bool(forKey: Self.openDocumentsInTabsKey)
            && Date().timeIntervalSince(launchDate) > Self.launchSettleInterval
    }

    @objc private func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        knownWindows.remove(ObjectIdentifier(window))
        if let url = NSDocumentController.shared.document(for: window)?.fileURL {
            recentlyClosed.removeAll { $0 == url }
            recentlyClosed.append(url)
            if recentlyClosed.count > 20 { recentlyClosed.removeFirst() }
        }
    }

    // MARK: - Tab Keys

    /// Handle tab-cycling keys, and the alternate heading shortcuts, before
    /// the text view sees them.
    private func installTabKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            if let command = Self.alternateHeadingCommand(for: event),
               let textView = NSApp.keyWindow?.firstResponder as? MarkdownTextView {
                textView.applyFormatting(command)
                return nil
            }
            guard let direction = Self.tabCycleDirection(for: event) else { return event }
            guard let window = NSApp.keyWindow, self.isDocumentWindow(window) else { return event }
            self.selectTab(offset: direction, in: window)
            return nil
        }
    }

    /// ⌥⌘1–6 / ⌥⌘0: the heading shortcuts used by Google Docs, Word and Notion,
    /// accepted alongside QuillSwift's ⌘1–6 / ⌘0 (a menu item shows only one).
    static func alternateHeadingCommand(for event: NSEvent) -> FormattingCommand? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        guard flags == [.command, .option] else { return nil }
        // Key codes for the top-row digits (layout-independent)
        let levels: [UInt16: Int] = [18: 1, 19: 2, 20: 3, 21: 4, 23: 5, 22: 6]
        if let level = levels[event.keyCode] { return .heading(level: level) }
        if event.keyCode == 29 { return .removeHeading }
        return nil
    }

    /// +1 / -1 for Safari's next/previous tab shortcuts, nil otherwise.
    static func tabCycleDirection(for event: NSEvent) -> Int? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad, .function])
        switch event.keyCode {
        case 48: // Tab
            if flags == [.control] { return 1 }
            if flags == [.control, .shift] { return -1 }
        case 30: // ]
            if flags == [.command, .shift] { return 1 }
        case 33: // [
            if flags == [.command, .shift] { return -1 }
        default:
            break
        }
        return nil
    }

    private func selectTab(offset: Int, in window: NSWindow) {
        guard let tabs = window.tabbedWindows, tabs.count > 1,
              let index = tabs.firstIndex(of: window) else {
            return
        }
        let next = tabs[(index + offset + tabs.count) % tabs.count]
        next.makeKeyAndOrderFront(nil)
    }

    // MARK: - Menu Actions

    /// New Tab (⌘T) and the tab bar's + button
    @objc func newWindowForTab(_ sender: Any?) {
        if let window = NSApp.keyWindow, isDocumentWindow(window) {
            pendingTabHost = window
        } else {
            pendingTabHost = lastDocumentWindow
        }
        NSDocumentController.shared.newDocument(sender)
    }

    /// Reopen Last Closed Tab (⇧⌘T)
    @objc func reopenLastClosedTab(_ sender: Any?) {
        guard let url = recentlyClosed.popLast() else {
            NSSound.beep()
            return
        }
        if let window = NSApp.keyWindow, isDocumentWindow(window) {
            pendingTabHost = window
        }
        // Prefer the History bookmark: the sandbox may no longer grant access by path
        if let entry = HistoryStore.shared.entries.first(where: { $0.path == url.path }) {
            HistoryStore.shared.open(entry)
        } else {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
        }
    }
}
