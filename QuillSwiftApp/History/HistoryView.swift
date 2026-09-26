import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - History Window

/// Safari-style History window (⌘Y): searchable list of previously opened
/// files, grouped by day, newest first.
struct HistoryView: View {
    @ObservedObject private var store = HistoryStore.shared

    @State private var query = ""
    @State private var selection = Set<UUID>()

    var body: some View {
        let sections = HistoryLogic.groupedByDay(store.entries, now: Date(), query: query)

        Group {
            if store.entries.isEmpty {
                emptyState(
                    title: "No History",
                    message: "Files you open will appear here.",
                    systemImage: "clock"
                )
            } else if sections.isEmpty {
                emptyState(
                    title: "No Results",
                    message: "No files match “\(query)”.",
                    systemImage: "magnifyingglass"
                )
            } else {
                historyList(sections)
            }
        }
        .frame(minWidth: 480, minHeight: 320)
        .searchable(text: $query, placement: .toolbar, prompt: "Search History")
    }

    // MARK: List

    private func historyList(_ sections: [HistoryDaySection]) -> some View {
        List(selection: $selection) {
            ForEach(sections) { section in
                Section(section.title) {
                    ForEach(section.entries) { entry in
                        HistoryRow(entry: entry, isMissing: !store.fileExists(entry))
                            .tag(entry.id)
                    }
                }
            }
        }
        .listStyle(.inset)
        .contextMenu(forSelectionType: UUID.self) { ids in
            contextMenu(for: ids)
        } primaryAction: { ids in
            // Double-click or Return
            open(ids)
        }
        .onDeleteCommand {
            remove(selection)
        }
    }

    @ViewBuilder
    private func contextMenu(for ids: Set<UUID>) -> some View {
        if !ids.isEmpty {
            Button("Open") { open(ids) }
            Button("Show in Finder") { showInFinder(ids) }
            Button(ids.count > 1 ? "Copy Paths" : "Copy Path") { copyPaths(ids) }
            Divider()
            Button("Remove from History") { remove(ids) }
        }
    }

    // MARK: Empty State

    /// Simple centered empty state (`ContentUnavailableView` is macOS 14+).
    private func emptyState(title: String, message: String, systemImage: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 36, weight: .light))
                .foregroundStyle(.tertiary)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text(message)
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Actions

    private func entries(for ids: Set<UUID>) -> [HistoryEntry] {
        store.entries.filter { ids.contains($0.id) }
    }

    private func open(_ ids: Set<UUID>) {
        for entry in entries(for: ids) {
            store.open(entry)
        }
    }

    private func showInFinder(_ ids: Set<UUID>) {
        let urls = entries(for: ids).map(\.url)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    private func copyPaths(_ ids: Set<UUID>) {
        let paths = entries(for: ids).map(\.path)
        guard !paths.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(paths.joined(separator: "\n"), forType: .string)
    }

    private func remove(_ ids: Set<UUID>) {
        store.remove(ids)
        selection.subtract(ids)
    }
}

// MARK: - Row

private struct HistoryRow: View {
    let entry: HistoryEntry
    let isMissing: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: FileIconCache.icon(forPath: entry.path))
                .resizable()
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(entry.displayName)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Text(HistoryLogic.abbreviated(entry.folderPath))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 8)

            if isMissing {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .help("This file can’t be found. It may have been moved or deleted.")
            }

            Text(HistoryTimeFormatter.shared.string(from: entry.lastVisited))
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
        .opacity(isMissing ? 0.5 : 1)
        .help(entry.path)
    }
}

/// Short time format in the user's locale, e.g. "11:42 PM".
private enum HistoryTimeFormatter {
    static let shared: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
}

/// Caches document icons per file extension (cheap; avoids hitting disk per row).
@MainActor
private enum FileIconCache {
    private static var cache: [String: NSImage] = [:]

    static func icon(forPath path: String) -> NSImage {
        let ext = (path as NSString).pathExtension.lowercased()
        if let cached = cache[ext] { return cached }
        let type = UTType(filenameExtension: ext) ?? .plainText
        let image = NSWorkspace.shared.icon(for: type)
        cache[ext] = image
        return image
    }
}

// MARK: - Menu Commands

/// "History" menu: Show All History (⌘Y) and Clear History…
struct HistoryCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandMenu("History") {
            Button("Show All History") {
                openWindow(id: "history")
            }
            .keyboardShortcut("y", modifiers: .command)

            Divider()

            Button("Clear History…") {
                Self.confirmClearHistory()
            }
        }
    }

    @MainActor
    static func confirmClearHistory() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Are you sure you want to clear all history?"
        alert.informativeText = "This removes the record of every file you’ve opened. It doesn’t delete any files."
        alert.addButton(withTitle: "Clear History")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            HistoryStore.shared.clearAll()
        }
    }
}
