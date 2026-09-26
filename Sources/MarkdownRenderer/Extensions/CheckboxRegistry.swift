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

    /// Resolve a marker character the way Obsidian does: `X` is `x`, a registered
    /// id gets its type, and any other single character is still a task, drawn
    /// with the neutral `CheckboxType.generic` style.
    public func resolvedType(forMarker id: String) -> CheckboxType {
        if id == "X" { return type(forId: "x") ?? .complete }
        return type(forId: id) ?? .generic(id: id)
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

// MARK: - Stylesheet

extension CheckboxRegistry {

    /// CSS that draws task-list checkboxes like Obsidian (AnuPpuccin theme).
    ///
    /// Covers the standard `<input class="task-checkbox">` items and the
    /// extended `<li class="extended-checkbox" data-task="…"><span class="checkbox-symbol">`
    /// items: one rule per registered type, plus a neutral fallback for
    /// unregistered markers. Icons are CSS masks over the type's color.
    ///
    /// - Parameters:
    ///   - isDark: Use each type's dark color.
    ///   - markerColor: Color of the checkmark knocked out of a filled box. Must be
    ///     a literal color (it is baked into an SVG); defaults to the preview's
    ///     page background.
    public func stylesheet(isDark: Bool, markerColor: String? = nil) -> String {
        let marker = markerColor ?? (isDark ? "#0d1117" : "#ffffff")
        let pending = type(forId: " ") ?? .pending
        let complete = type(forId: "x") ?? .complete
        let generic = CheckboxType.generic(id: "")
        let checkmarkURL = Self.svgURL(CheckboxType.Icons.checkmark)
        let markerCheckmarkURL = Self.svgURL(
            CheckboxType.Icons.checkmark.replacingOccurrences(of: "stroke='black'", with: "stroke='\(marker)'")
        )

        var css = """
        /* Task checkboxes (Obsidian/AnuPpuccin parity; generated by CheckboxRegistry) */
        .task-list-item input.task-checkbox,
        .task-list-item .checkbox-symbol {
            -webkit-appearance: none;
            appearance: none;
            font-size: inherit;
            position: relative;
            display: inline-block;
            box-sizing: border-box;
            width: var(--qs-checkbox-size, 1em);
            height: var(--qs-checkbox-size, 1em);
            margin: 0 0.45em 0 0;
            padding: 0;
            vertical-align: -0.14em;
            border: 1px solid \(pending.cssColor(isDark: isDark));
            border-radius: 4px;
            background: transparent no-repeat center / 65%;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }
        .task-list-item input.task-checkbox:checked {
            background-color: \(complete.cssColor(isDark: isDark));
            border-color: \(complete.cssColor(isDark: isDark));
            background-image: \(markerCheckmarkURL);
        }
        .task-list-item[data-checkbox-status="complete"] {
            text-decoration: line-through;
            color: var(--qs-color-secondary);
        }
        .task-list-item .checkbox-symbol::after {
            content: "";
            position: absolute;
            inset: -1px;
            background-color: var(--qs-color-background, \(marker));
            -webkit-mask: \(checkmarkURL) no-repeat center / 65%;
            mask: \(checkmarkURL) no-repeat center / 65%;
        }
        .task-list-item.extended-checkbox .checkbox-symbol {
            background-color: \(generic.cssColor(isDark: isDark));
            border-color: \(generic.cssColor(isDark: isDark));
        }

        """

        for checkbox in allTypes where checkbox.id != "x" && checkbox.id != " " {
            css += Self.rules(for: checkbox, isDark: isDark)
        }
        return css
    }

    /// CSS rules for one extended checkbox type
    private static func rules(for checkbox: CheckboxType, isDark: Bool) -> String {
        let item = ".task-list-item.extended-checkbox[data-task=\(cssString(checkbox.id))]"
        let color = checkbox.cssColor(isDark: isDark)
        var box: String
        var after: String

        switch checkbox.presentation {
        case .filled:
            box = "background-color: \(color); border-color: \(color);"
            if let icon = checkbox.icon {
                let url = svgURL(icon)
                let size = checkbox.iconSize ?? "contain"
                after = "-webkit-mask-image: \(url); mask-image: \(url); -webkit-mask-size: \(size); mask-size: \(size);"
            } else {
                after = ""
            }
        case .icon:
            box = "background-color: transparent; border-color: transparent;"
            let url = svgURL(checkbox.icon ?? CheckboxType.Icons.checkmark)
            let size = checkbox.iconSize ?? "contain"
            after = "background-color: \(color); -webkit-mask-image: \(url); mask-image: \(url); -webkit-mask-size: \(size); mask-size: \(size);"
        case .tinted:
            box = "background-color: \(rgba(color, alpha: 0.3)); border-color: \(color);"
            after = "display: none;"
        case nil:
            box = "background-color: transparent; border-color: \(color);"
            after = "display: none;"
        }

        // Child combinators: a nested item's symbol must not pick up its parent's type
        let symbol = "\(item) > .checkbox-symbol, \(item) > p:first-child > .checkbox-symbol"
        let symbolAfter = "\(item) > .checkbox-symbol::after, \(item) > p:first-child > .checkbox-symbol::after"
        var css = "\(symbol) { \(box) }\n"
        if !after.isEmpty {
            css += "\(symbolAfter) { \(after) }\n"
        }
        if let style = checkbox.textStyle {
            let declaration: String
            switch style {
            case .strike: declaration = "text-decoration: line-through; color: var(--qs-color-secondary);"
            case .italic: declaration = "font-style: italic;"
            case .bold: declaration = "font-weight: bold;"
            case .faint: declaration = "color: var(--qs-color-secondary);"
            }
            css += "\(item) { \(declaration) }\n"
        }
        return css
    }

    /// Quote a value for use in a CSS attribute selector
    static func cssString(_ value: String) -> String {
        let escaped = value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// `url("data:image/svg+xml,…")` for inline SVG markup
    static func svgURL(_ svg: String) -> String {
        var allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        allowed.insert(charactersIn: " -._~'=/:,()!*")
        let encoded = svg.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
        return "url(\"data:image/svg+xml,\(encoded)\")"
    }

    /// `rgba()` for a `#rrggbb` color (other formats are returned unchanged)
    static func rgba(_ hex: String, alpha: Double) -> String {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = Int(digits, radix: 16) else { return hex }
        return "rgba(\((value >> 16) & 0xFF), \((value >> 8) & 0xFF), \(value & 0xFF), \(alpha))"
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
