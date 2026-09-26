import SwiftUI
import AppKit

/// Watches a document's file for changes made by other apps.
///
/// Changes are detected by content, not timestamps: when the file changes on
/// disk, its bytes are compared with the last version known to match the
/// document (`baseline`). This makes QuillSwift's own saves invisible (the
/// disk then matches the editor), ignores touch-only / metadata changes, and
/// survives editors that save atomically by replacing the file.
@MainActor
final class FileChangeMonitor: ObservableObject {

    // MARK: - Types

    enum ExternalChange: Equatable {
        /// The file on disk now differs from the document
        case modified
        /// The file is gone from its location
        case deleted
    }

    // MARK: - Published State

    /// The pending external change to offer the user, if any
    @Published private(set) var change: ExternalChange?

    // MARK: - Properties

    private var url: URL?
    private var currentText: () -> String = { "" }
    private var source: DispatchSourceFileSystemObject?
    private var pendingCheck: DispatchWorkItem?
    private var activationObserver: NSObjectProtocol?

    /// Disk contents last known to match the document (open, save, or reload)
    private var baseline: Data?

    /// Disk contents the user chose to keep their own version over
    private var dismissedDiskContents: Data?

    // MARK: - Lifecycle

    /// Start (or restart) watching `url`. `currentText` reads the live document text.
    func start(url: URL, currentText: @escaping () -> String) {
        if url == self.url, source != nil { return }
        stop()
        self.url = url
        self.currentText = currentText
        baseline = try? Data(contentsOf: url)
        change = nil
        dismissedDiskContents = nil
        watch()

        // Safety net for missed events (network volumes, sleep): re-check on activation
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.scheduleCheck() }
        }
    }

    func stop() {
        source?.cancel()
        source = nil
        pendingCheck?.cancel()
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
        activationObserver = nil
        url = nil
    }

    // MARK: - User Actions

    /// Whether the document has edits that differ from the file as last read or saved
    var hasUnsavedEdits: Bool {
        Data(currentText().utf8) != baseline
    }

    /// Keep the in-app version; don't offer this disk version again.
    func dismiss() {
        if change == .modified, let url {
            dismissedDiskContents = try? Data(contentsOf: url)
        }
        change = nil
    }

    /// Record that the document now matches the file on disk (after a reload).
    func markInSync() {
        if let url { baseline = try? Data(contentsOf: url) }
        dismissedDiskContents = nil
        change = nil
    }

    // MARK: - Watching

    private func watch() {
        guard let url else { return }
        let descriptor = open(url.path, O_EVTONLY)
        guard descriptor >= 0 else {
            // File may be mid-replacement; try again shortly
            scheduleRewatch()
            return
        }
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename, .attrib],
            queue: .main
        )
        source.setEventHandler { [weak self, weak source] in
            guard let self, let source else { return }
            let events = source.data
            Task { @MainActor in
                if events.contains(.delete) || events.contains(.rename) {
                    // Atomic saves replace the file: our descriptor now points at the old one
                    self.source?.cancel()
                    self.source = nil
                    self.scheduleRewatch()
                }
                self.scheduleCheck()
            }
        }
        source.setCancelHandler {
            close(descriptor)
        }
        source.resume()
        self.source = source
    }

    private func scheduleRewatch(attempt: Int = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, let url = self.url, self.source == nil else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                self.watch()
                self.scheduleCheck()
            } else if attempt < 5 {
                self.scheduleRewatch(attempt: attempt + 1)
            } else {
                self.scheduleCheck()
            }
        }
    }

    /// Coalesce bursts of events (editors often write in several steps).
    private func scheduleCheck() {
        pendingCheck?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.check() }
        pendingCheck = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
    }

    private func check() {
        guard let url else { return }
        guard let disk = try? Data(contentsOf: url) else {
            if !FileManager.default.fileExists(atPath: url.path) {
                change = .deleted
            }
            return
        }
        if disk == baseline {
            // Unchanged content (or back to what we knew); a deleted file may have returned
            if change == .deleted { change = nil }
            return
        }
        if disk == Data(currentText().utf8) {
            // Our own save, or an external write identical to the editor
            baseline = disk
            dismissedDiskContents = nil
            change = nil
            return
        }
        if disk == dismissedDiskContents { return }
        change = .modified
    }
}

// MARK: - Banner

/// The "changed on disk" panel shown at the top of a document window.
struct FileChangedBanner: View {

    let change: FileChangeMonitor.ExternalChange
    let fileName: String
    let hasUnsavedEdits: Bool
    let onReload: () -> Void
    let onDismiss: () -> Void

    private var isWarning: Bool { change == .deleted || hasUnsavedEdits }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(isWarning ? .orange : .accentColor)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(hasUnsavedEdits && change == .modified ? .orange : .secondary)
            }
            .lineLimit(1)
            .truncationMode(.middle)

            Spacer(minLength: 8)

            switch change {
            case .modified:
                Button(hasUnsavedEdits ? "Keep My Changes" : "Ignore", action: onDismiss)
                    .controlSize(.small)
                Button(hasUnsavedEdits ? "Discard & Reload" : "Reload", action: onReload)
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    .tint(hasUnsavedEdits ? .orange : .accentColor)
            case .deleted:
                Button("Dismiss", action: onDismiss)
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(.bar)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isWarning ? Color.orange : Color.accentColor)
                .frame(width: 3)
        }
        .overlay(alignment: .bottom) { Divider() }
        .accessibilityElement(children: .contain)
    }

    private var iconName: String {
        switch change {
        case .modified: return hasUnsavedEdits ? "exclamationmark.triangle.fill" : "arrow.triangle.2.circlepath"
        case .deleted: return "trash"
        }
    }

    private var title: String {
        switch change {
        case .modified: return "“\(fileName)” was changed by another application."
        case .deleted: return "“\(fileName)” was moved or deleted."
        }
    }

    private var detail: String {
        switch change {
        case .modified:
            return hasUnsavedEdits
                ? "You have unsaved changes. Reloading will discard them."
                : "Reload to see the latest version from disk."
        case .deleted:
            return "Saving will create the file again at its original location."
        }
    }
}
