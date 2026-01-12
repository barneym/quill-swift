import Foundation
import AppKit

/// Manages session state for window restoration.
///
/// Tracks open documents and window positions for restoration
/// after app restart or system reboot.
@MainActor
final class SessionManager: ObservableObject {

    // MARK: - Singleton

    static let shared = SessionManager()

    // MARK: - Properties

    /// Current session state
    @Published private(set) var session: SessionState

    /// Draft storage reference
    private let draftStorage = DraftStorage.shared

    /// URL for session state file
    private var sessionURL: URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }

        return appSupport
            .appendingPathComponent("QuillSwift")
            .appendingPathComponent("session.json")
    }

    // MARK: - Initialization

    private init() {
        session = SessionState(windows: [], lastActiveDocumentID: nil)
        loadSession()

        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.saveSession()
            }
        }
    }

    // MARK: - Public Methods

    /// Register a document window
    func registerWindow(
        documentID: UUID,
        fileURL: URL?,
        frame: NSRect,
        isDirty: Bool
    ) {
        // Update or add window state
        let windowState = WindowState(
            documentID: documentID,
            fileURL: fileURL,
            frame: frame,
            isDirty: isDirty
        )

        if let index = session.windows.firstIndex(where: { $0.documentID == documentID }) {
            session.windows[index] = windowState
        } else {
            session.windows.append(windowState)
        }

        session.lastActiveDocumentID = documentID
        saveSession()
    }

    /// Update window position
    func updateWindowFrame(documentID: UUID, frame: NSRect) {
        guard let index = session.windows.firstIndex(where: { $0.documentID == documentID }) else {
            return
        }
        session.windows[index].frame = frame
        saveSession()
    }

    /// Remove a document window
    func removeWindow(documentID: UUID) {
        session.windows.removeAll { $0.documentID == documentID }
        saveSession()
    }

    /// Mark document as dirty
    func markDirty(documentID: UUID, isDirty: Bool) {
        guard let index = session.windows.firstIndex(where: { $0.documentID == documentID }) else {
            return
        }
        session.windows[index].isDirty = isDirty
    }

    /// Get windows to restore
    func getWindowsToRestore() -> [WindowState] {
        session.windows
    }

    /// Get drafts to offer for restoration
    func getDraftsToRestore() -> [DraftInfo] {
        draftStorage.getUnsavedDrafts()
    }

    /// Clear session (for testing)
    func clearSession() {
        session = SessionState(windows: [], lastActiveDocumentID: nil)
        saveSession()
    }

    // MARK: - Private Methods

    private func saveSession() {
        guard let url = sessionURL else { return }

        // Ensure directory exists
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        if let data = try? encoder.encode(session) {
            try? data.write(to: url)
        }
    }

    private func loadSession() {
        guard let url = sessionURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode(SessionState.self, from: data) else {
            return
        }
        session = loaded
    }
}

// MARK: - Session State

/// Complete session state for restoration
struct SessionState: Codable {
    var windows: [WindowState]
    var lastActiveDocumentID: UUID?
}

// MARK: - Window State

/// State of a single document window
struct WindowState: Codable, Identifiable {
    var id: UUID { documentID }
    let documentID: UUID
    var fileURL: URL?
    var frame: NSRect
    var isDirty: Bool
}

// Note: NSRect/CGRect already conforms to Codable via CoreGraphics
