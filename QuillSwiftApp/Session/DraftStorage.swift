import Foundation

/// Manages draft storage for unsaved documents.
///
/// Drafts are stored in ~/Library/Application Support/QuillSwift/Drafts/
/// and are automatically cleaned up when documents are saved or discarded.
@MainActor
final class DraftStorage: ObservableObject {

    // MARK: - Singleton

    static let shared = DraftStorage()

    // MARK: - Properties

    /// Directory for storing drafts
    private let draftsDirectory: URL?

    /// Timer for auto-saving drafts
    private var autoSaveTimer: Timer?

    /// Active drafts keyed by document identifier
    @Published private(set) var activeDrafts: [UUID: DraftInfo] = [:]

    // MARK: - Initialization

    private init() {
        // Set up drafts directory
        if let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first {
            draftsDirectory = appSupport
                .appendingPathComponent("QuillSwift")
                .appendingPathComponent("Drafts")

            // Create directory if needed
            try? FileManager.default.createDirectory(
                at: draftsDirectory!,
                withIntermediateDirectories: true
            )
        } else {
            draftsDirectory = nil
        }

        // Load existing drafts
        loadDraftIndex()

        // Start auto-save timer
        startAutoSave()
    }

    deinit {
        autoSaveTimer?.invalidate()
    }

    // MARK: - Public Methods

    /// Register a document for draft tracking
    func register(documentID: UUID, text: String, title: String?) {
        let draft = DraftInfo(
            id: documentID,
            title: title ?? "Untitled",
            lastModified: Date(),
            characterCount: text.count
        )
        activeDrafts[documentID] = draft
        saveDraft(documentID: documentID, text: text)
    }

    /// Update draft content
    func updateDraft(documentID: UUID, text: String) {
        guard var draft = activeDrafts[documentID] else { return }
        draft.lastModified = Date()
        draft.characterCount = text.count
        activeDrafts[documentID] = draft
        saveDraft(documentID: documentID, text: text)
    }

    /// Remove a draft (called when document is saved or discarded)
    func removeDraft(documentID: UUID) {
        activeDrafts.removeValue(forKey: documentID)
        deleteDraftFile(documentID: documentID)
        saveDraftIndex()
    }

    /// Get draft content for a document
    func getDraftContent(documentID: UUID) -> String? {
        guard let url = draftFileURL(for: documentID),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    /// Get all unsaved drafts (for session restoration)
    func getUnsavedDrafts() -> [DraftInfo] {
        Array(activeDrafts.values).sorted { $0.lastModified > $1.lastModified }
    }

    /// Clean up old drafts (older than 7 days)
    func cleanupOldDrafts() {
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)

        for (id, draft) in activeDrafts {
            if draft.lastModified < cutoffDate {
                removeDraft(documentID: id)
            }
        }
    }

    // MARK: - Private Methods

    private func draftFileURL(for documentID: UUID) -> URL? {
        draftsDirectory?.appendingPathComponent("\(documentID.uuidString).md")
    }

    private func draftIndexURL() -> URL? {
        draftsDirectory?.appendingPathComponent("index.json")
    }

    private func saveDraft(documentID: UUID, text: String) {
        guard let url = draftFileURL(for: documentID) else { return }
        try? text.write(to: url, atomically: true, encoding: .utf8)
        saveDraftIndex()
    }

    private func deleteDraftFile(documentID: UUID) {
        guard let url = draftFileURL(for: documentID) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func saveDraftIndex() {
        guard let url = draftIndexURL() else { return }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(Array(activeDrafts.values)) {
            try? data.write(to: url)
        }
    }

    private func loadDraftIndex() {
        guard let url = draftIndexURL(),
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let drafts = try? JSONDecoder().decode([DraftInfo].self, from: data) else {
            return
        }

        activeDrafts = Dictionary(uniqueKeysWithValues: drafts.map { ($0.id, $0) })
    }

    private func startAutoSave() {
        // Auto-save every 30 seconds
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.saveDraftIndex()
            }
        }
    }
}

// MARK: - Draft Info

/// Information about a draft document
struct DraftInfo: Codable, Identifiable {
    let id: UUID
    var title: String
    var lastModified: Date
    var characterCount: Int
}
