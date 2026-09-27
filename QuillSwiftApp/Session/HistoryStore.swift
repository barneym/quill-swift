import Foundation
import AppKit

// MARK: - Model

/// A single History record: one file visited on one calendar day.
///
/// Revisiting the same file on the same day updates `lastVisited` and bumps
/// `visitCount`; a visit on a later day creates a new entry, so the History
/// window can show the file under every day it was used (like Safari).
struct HistoryEntry: Codable, Identifiable, Equatable, Sendable {
    let id: UUID
    var path: String
    var displayName: String
    var lastVisited: Date
    var visitCount: Int
    /// Security-scoped bookmark (app scope). `nil` if creation failed.
    var bookmark: Data?

    var url: URL { URL(fileURLWithPath: path) }

    /// Folder containing the file.
    var folderPath: String { (path as NSString).deletingLastPathComponent }
}

/// A day's worth of History entries, newest first.
struct HistoryDaySection: Identifiable, Equatable {
    /// Start of the calendar day.
    let day: Date
    let title: String
    let entries: [HistoryEntry]

    var id: Date { day }
}

// MARK: - Pure Logic (testable)

/// Pure functions for recording, pruning, filtering and grouping History.
enum HistoryLogic {

    static let retentionDays = 365
    static let maxEntries = 5_000

    /// Split a search query into whitespace-separated tokens.
    static func tokens(for query: String) -> [String] {
        query
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    /// True if every token matches the file name or full path
    /// (case- and diacritic-insensitive). Empty token list matches everything.
    static func matches(_ entry: HistoryEntry, tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return true }
        let haystack = entry.displayName + "\n" + entry.path
        return tokens.allSatisfy { token in
            haystack.range(
                of: token,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }

    /// Filter by `query`, then group into day sections, newest day first and
    /// newest visit first within each day.
    static func groupedByDay(
        _ entries: [HistoryEntry],
        now: Date = Date(),
        calendar: Calendar = .current,
        query: String = "",
        locale: Locale = .current
    ) -> [HistoryDaySection] {
        let tokens = tokens(for: query)
        let filtered = entries.filter { matches($0, tokens: tokens) }

        let byDay = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.lastVisited) }

        let formatter = dayFormatter(calendar: calendar, locale: locale)
        return byDay.keys.sorted(by: >).map { day in
            HistoryDaySection(
                day: day,
                title: sectionTitle(for: day, now: now, calendar: calendar, formatter: formatter),
                entries: byDay[day, default: []].sorted { $0.lastVisited > $1.lastVisited }
            )
        }
    }

    /// "Today", "Yesterday", or e.g. "Tuesday, September 22, 2026".
    static func sectionTitle(
        for day: Date,
        now: Date,
        calendar: Calendar,
        formatter: DateFormatter? = nil
    ) -> String {
        if calendar.isDate(day, inSameDayAs: now) {
            return NSLocalizedString("Today", comment: "History section header")
        }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now)),
           calendar.isDate(day, inSameDayAs: yesterday) {
            return NSLocalizedString("Yesterday", comment: "History section header")
        }
        let formatter = formatter ?? dayFormatter(calendar: calendar, locale: .current)
        return formatter.string(from: day)
    }

    static func dayFormatter(calendar: Calendar, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEMMMMdy")
        return formatter
    }

    /// Record a visit to `path` at `date`, deduplicating per calendar day.
    /// Returns the updated list (newest first) and the id of the touched entry.
    static func recording(
        path: String,
        displayName: String,
        bookmark: @autoclosure () -> Data?,
        at date: Date,
        into entries: [HistoryEntry],
        calendar: Calendar
    ) -> (entries: [HistoryEntry], id: UUID) {
        var entries = entries
        if let index = entries.firstIndex(where: {
            $0.path == path && calendar.isDate($0.lastVisited, inSameDayAs: date)
        }) {
            entries[index].lastVisited = max(entries[index].lastVisited, date)
            entries[index].visitCount += 1
            entries[index].displayName = displayName
            if entries[index].bookmark == nil {
                entries[index].bookmark = bookmark()
            }
            let id = entries[index].id
            return (sortedNewestFirst(entries), id)
        }

        // New day (or new file): reuse a previous bookmark for the same path
        // if a fresh one can't be made.
        let previousBookmark = entries.first(where: { $0.path == path && $0.bookmark != nil })?.bookmark
        let entry = HistoryEntry(
            id: UUID(),
            path: path,
            displayName: displayName,
            lastVisited: date,
            visitCount: 1,
            bookmark: bookmark() ?? previousBookmark
        )
        entries.insert(entry, at: 0)
        return (sortedNewestFirst(entries), entry.id)
    }

    /// Drop entries older than the retention window and cap the total count.
    static func pruned(
        _ entries: [HistoryEntry],
        now: Date,
        calendar: Calendar,
        retentionDays: Int = retentionDays,
        maxEntries: Int = maxEntries
    ) -> [HistoryEntry] {
        let cutoff = calendar.date(
            byAdding: .day,
            value: -retentionDays,
            to: calendar.startOfDay(for: now)
        ) ?? .distantPast
        let kept = sortedNewestFirst(entries.filter { $0.lastVisited >= cutoff })
        return kept.count > maxEntries ? Array(kept.prefix(maxEntries)) : kept
    }

    static func sortedNewestFirst(_ entries: [HistoryEntry]) -> [HistoryEntry] {
        entries.sorted { $0.lastVisited > $1.lastVisited }
    }

    /// Abbreviate a folder path with `~` relative to the *real* home directory.
    /// (In the sandbox `NSHomeDirectory()` is the container, so
    /// `abbreviatingWithTildeInPath` can't be used.)
    static func abbreviated(_ path: String, home: String = realHomeDirectory) -> String {
        guard !home.isEmpty else { return path }
        if path == home { return "~" }
        let prefix = home.hasSuffix("/") ? home : home + "/"
        if path.hasPrefix(prefix) {
            return "~/" + path.dropFirst(prefix.count)
        }
        return path
    }

    static let realHomeDirectory: String = {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return String(cString: dir)
        }
        return NSHomeDirectory()
    }()
}

// MARK: - Store

/// Persistent, Safari-style browsing history of opened files.
///
/// Persists to `~/Library/Application Support/QuillSwift/history.json`
/// (inside the sandbox container). Keeps 365 days / 5,000 entries.
@MainActor
final class HistoryStore: ObservableObject {

    static let shared = HistoryStore()

    /// All entries, newest first.
    @Published private(set) var entries: [HistoryEntry] = []

    private let storageURL: URL?
    private let calendar: Calendar
    private let now: () -> Date
    private let saveDelay: TimeInterval
    private let makeBookmark: (URL) -> Data?
    private var pendingSave: DispatchWorkItem?

    /// Serial queue so writes land in order and off the main thread.
    private static let ioQueue = DispatchQueue(label: "QuillSwift.HistoryStore.io", qos: .utility)

    private struct StoredHistory: Codable {
        var version: Int
        var entries: [HistoryEntry]
    }

    nonisolated static var defaultStorageURL: URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return appSupport
            .appendingPathComponent(AppPaths.supportFolderName, isDirectory: true)
            .appendingPathComponent("history.json")
    }

    // MARK: Init

    /// - Parameters:
    ///   - storageURL: JSON file to persist to (`nil` = in-memory only).
    ///   - saveDelay: debounce interval for saves; `0` saves synchronously.
    ///   - makeBookmark: bookmark factory (injectable for tests).
    init(
        storageURL: URL? = HistoryStore.defaultStorageURL,
        calendar: Calendar = .current,
        now: @escaping () -> Date = Date.init,
        saveDelay: TimeInterval = 1.0,
        makeBookmark: @escaping (URL) -> Data? = HistoryStore.securityScopedBookmark(for:)
    ) {
        self.storageURL = storageURL
        self.calendar = calendar
        self.now = now
        self.saveDelay = saveDelay
        self.makeBookmark = makeBookmark
        load()

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.flush()
            }
        }
    }

    // MARK: Public API

    /// Record that `url` was opened/viewed now.
    func recordVisit(_ url: URL) {
        guard url.isFileURL else { return }
        let fileURL = url.standardizedFileURL
        let result = HistoryLogic.recording(
            path: fileURL.path,
            displayName: fileURL.lastPathComponent,
            bookmark: makeBookmark(fileURL),
            at: now(),
            into: entries,
            calendar: calendar
        )
        entries = HistoryLogic.pruned(result.entries, now: now(), calendar: calendar)
        scheduleSave()
    }

    func remove(_ ids: Set<UUID>) {
        guard !ids.isEmpty else { return }
        entries.removeAll { ids.contains($0.id) }
        scheduleSave()
    }

    func clearAll() {
        entries.removeAll()
        scheduleSave()
    }

    /// Open the entry's file as a document, using its security-scoped bookmark.
    func open(_ entry: HistoryEntry) {
        var url = entry.url
        var didStartAccessing = false

        if let data = entry.bookmark {
            var isStale = false
            if let resolved = try? URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                url = resolved
                didStartAccessing = resolved.startAccessingSecurityScopedResource()
                if isStale || resolved.standardizedFileURL.path != entry.path {
                    refreshBookmark(oldPath: entry.path, resolvedURL: resolved)
                }
            }
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            if didStartAccessing { url.stopAccessingSecurityScopedResource() }
            presentMissingFileAlert(for: entry)
            return
        }

        let accessedURL = url
        NSDocumentController.shared.openDocument(withContentsOf: accessedURL, display: true) { _, _, error in
            if didStartAccessing {
                accessedURL.stopAccessingSecurityScopedResource()
            }
            if let error, !Self.isUserCancelled(error) {
                NSApp.presentError(error)
            }
        }
    }

    /// Whether the entry's file currently exists at its recorded path.
    func fileExists(_ entry: HistoryEntry) -> Bool {
        FileManager.default.fileExists(atPath: entry.path)
    }

    /// Write any pending changes immediately (synchronously).
    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        guard let storageURL else { return }
        let snapshot = StoredHistory(version: 1, entries: entries)
        // Sync on the IO queue so this lands after any queued async write.
        Self.ioQueue.sync {
            Self.write(snapshot, to: storageURL)
        }
    }

    // MARK: Bookmarks

    nonisolated static func securityScopedBookmark(for url: URL) -> Data? {
        try? url.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    /// After resolving a stale bookmark (or one that followed a moved file),
    /// update all entries for the old path with a fresh bookmark and new path.
    private func refreshBookmark(oldPath: String, resolvedURL: URL) {
        let newURL = resolvedURL.standardizedFileURL
        let fresh = makeBookmark(newURL)
        var changed = false
        for index in entries.indices where entries[index].path == oldPath {
            if let fresh { entries[index].bookmark = fresh }
            entries[index].path = newURL.path
            entries[index].displayName = newURL.lastPathComponent
            changed = true
        }
        if changed { scheduleSave() }
    }

    // MARK: Alerts

    private func presentMissingFileAlert(for entry: HistoryEntry) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = String(
            format: NSLocalizedString("The file “%@” can’t be found.", comment: "History missing file"),
            entry.displayName
        )
        alert.informativeText = NSLocalizedString(
            "It may have been moved or deleted.",
            comment: "History missing file"
        )
        alert.addButton(withTitle: NSLocalizedString("OK", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("Remove from History", comment: ""))
        if alert.runModal() == .alertSecondButtonReturn {
            let ids = Set(entries.filter { $0.path == entry.path }.map(\.id))
            remove(ids)
        }
    }

    private nonisolated static func isUserCancelled(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError
    }

    // MARK: Persistence

    private func load() {
        guard let storageURL,
              FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            let stored = try JSONDecoder().decode(StoredHistory.self, from: data)
            entries = HistoryLogic.pruned(stored.entries, now: now(), calendar: calendar)
        } catch {
            // Corrupt or unreadable: keep a copy for diagnosis and start empty.
            NSLog("HistoryStore: failed to load history (\(error)); starting empty")
            let backup = storageURL.deletingPathExtension().appendingPathExtension("corrupt.json")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: storageURL, to: backup)
            entries = []
        }
    }

    private func scheduleSave() {
        guard storageURL != nil else { return }
        if saveDelay <= 0 {
            flush()
            return
        }
        pendingSave?.cancel()
        let item = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                self?.saveAsync()
            }
        }
        pendingSave = item
        DispatchQueue.main.asyncAfter(deadline: .now() + saveDelay, execute: item)
    }

    private func saveAsync() {
        pendingSave = nil
        guard let storageURL else { return }
        entries = HistoryLogic.pruned(entries, now: now(), calendar: calendar)
        let snapshot = StoredHistory(version: 1, entries: entries)
        Self.ioQueue.async {
            Self.write(snapshot, to: storageURL)
        }
    }

    private nonisolated static func write(_ stored: StoredHistory, to url: URL) {
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try JSONEncoder().encode(stored)
            try data.write(to: url, options: .atomic)
        } catch {
            NSLog("HistoryStore: failed to save history: \(error)")
        }
    }
}
