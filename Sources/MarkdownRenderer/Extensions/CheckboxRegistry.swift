import Foundation

/// Manages checkbox type definitions from multiple sources.
///
/// Sources are loaded in priority order (later sources override earlier):
/// 1. Built-in defaults
/// 2. App bundle checkboxes.json
/// 3. User configuration ~/.../QuillSwift/checkboxes.json
/// 4. Per-document overrides (frontmatter)
public final class CheckboxRegistry: @unchecked Sendable {

    // MARK: - Singleton

    /// Shared registry instance
    public static let shared = CheckboxRegistry()

    // MARK: - Properties

    /// All registered checkbox types keyed by their id
    private var types: [String: CheckboxType] = [:]

    /// Lock for thread-safe access
    private let lock = NSLock()

    /// User configuration file path
    private lazy var userConfigPath: URL? = {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }

        return appSupport
            .appendingPathComponent("QuillSwift")
            .appendingPathComponent("checkboxes.json")
    }()

    // MARK: - Initialization

    private init() {
        loadDefaults()
        loadUserConfig()
    }

    // MARK: - Loading

    /// Load built-in default checkbox types
    private func loadDefaults() {
        lock.lock()
        defer { lock.unlock() }

        for type in CheckboxType.defaults {
            types[type.id] = type
        }
    }

    /// Load user configuration from Application Support
    private func loadUserConfig() {
        guard let path = userConfigPath,
              FileManager.default.fileExists(atPath: path.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: path)
            let userTypes = try JSONDecoder().decode([CheckboxType].self, from: data)

            lock.lock()
            defer { lock.unlock() }

            for type in userTypes {
                types[type.id] = type
            }
        } catch {
            print("Warning: Failed to load user checkbox config: \(error)")
        }
    }

    /// Reload configuration from disk
    public func reload() {
        lock.lock()
        types.removeAll()
        lock.unlock()

        loadDefaults()
        loadUserConfig()
    }

    // MARK: - Access

    /// Get a checkbox type by its id
    public func type(forId id: String) -> CheckboxType? {
        lock.lock()
        defer { lock.unlock() }
        return types[id]
    }

    /// Get a checkbox type by id, with fallback to pending
    public func typeOrDefault(forId id: String) -> CheckboxType {
        type(forId: id) ?? .pending
    }

    /// Get all registered checkbox types
    public var allTypes: [CheckboxType] {
        lock.lock()
        defer { lock.unlock() }
        return Array(types.values).sorted { $0.id < $1.id }
    }

    /// Get all checkbox ids
    public var allIds: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(types.keys).sorted()
    }

    // MARK: - Registration

    /// Register a custom checkbox type
    public func register(_ type: CheckboxType) {
        lock.lock()
        defer { lock.unlock() }
        types[type.id] = type
    }

    /// Register multiple checkbox types
    public func register(_ checkboxTypes: [CheckboxType]) {
        lock.lock()
        defer { lock.unlock() }
        for type in checkboxTypes {
            types[type.id] = type
        }
    }

    /// Unregister a checkbox type by id
    public func unregister(id: String) {
        lock.lock()
        defer { lock.unlock() }
        types.removeValue(forKey: id)
    }

    // MARK: - Persistence

    /// Save current custom types to user configuration
    public func saveUserConfig() throws {
        guard let path = userConfigPath else {
            throw CheckboxRegistryError.noConfigPath
        }

        // Create directory if needed
        let directory = path.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        // Get non-default types
        let defaultIds = Set(CheckboxType.defaults.map { $0.id })
        let customTypes = allTypes.filter { !defaultIds.contains($0.id) }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(customTypes)
        try data.write(to: path)
    }

    // MARK: - Parsing

    /// Parse a checkbox marker from markdown (e.g., "[x]", "[ ]", "[/]")
    /// Returns the checkbox type if found
    public func parseCheckboxMarker(_ marker: String) -> CheckboxType? {
        // Expected format: [X] where X is a single character
        guard marker.count == 3,
              marker.hasPrefix("["),
              marker.hasSuffix("]") else {
            return nil
        }

        let idIndex = marker.index(after: marker.startIndex)
        let id = String(marker[idIndex])

        return type(forId: id)
    }
}

// MARK: - Errors

public enum CheckboxRegistryError: Error, LocalizedError {
    case noConfigPath

    public var errorDescription: String? {
        switch self {
        case .noConfigPath:
            return "Could not determine configuration file path"
        }
    }
}
