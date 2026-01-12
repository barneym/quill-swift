import Foundation
import SwiftUI
import AppKit

/// Manages theme preferences and custom user themes.
///
/// Supports:
/// - System/light/dark appearance modes
/// - Custom editor fonts
/// - User CSS overrides for preview
/// - Theme import/export
@MainActor
class ThemeManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ThemeManager()

    // MARK: - Published Properties

    /// Current appearance mode preference
    @Published var appearanceMode: AppearanceMode {
        didSet {
            savePreferences()
        }
    }

    /// Editor font name
    @Published var editorFontName: String {
        didSet {
            savePreferences()
        }
    }

    /// Editor font size
    @Published var editorFontSize: CGFloat {
        didSet {
            savePreferences()
        }
    }

    /// Preview font size
    @Published var previewFontSize: CGFloat {
        didSet {
            savePreferences()
        }
    }

    /// Preview line height
    @Published var previewLineHeight: CGFloat {
        didSet {
            savePreferences()
        }
    }

    /// Custom user CSS for preview
    @Published var customCSS: String {
        didSet {
            savePreferences()
        }
    }

    /// Show line numbers in editor
    @Published var showLineNumbers: Bool {
        didSet {
            savePreferences()
        }
    }

    /// Enable live preview mode (hybrid WYSIWYG)
    @Published var livePreviewEnabled: Bool {
        didSet {
            savePreferences()
        }
    }

    /// Enable Mermaid diagram rendering (requires trusted mode)
    @Published var enableMermaid: Bool {
        didSet {
            savePreferences()
        }
    }

    /// Enable Math/LaTeX rendering with KaTeX (requires trusted mode)
    @Published var enableMath: Bool {
        didSet {
            savePreferences()
        }
    }

    // MARK: - Computed Properties

    /// Current effective appearance
    var effectiveAppearance: NSAppearance? {
        switch appearanceMode {
        case .system:
            return nil // Use system setting
        case .light:
            return NSAppearance(named: .aqua)
        case .dark:
            return NSAppearance(named: .darkAqua)
        }
    }

    /// Whether dark mode is active
    var isDarkMode: Bool {
        switch appearanceMode {
        case .system:
            return NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        case .light:
            return false
        case .dark:
            return true
        }
    }

    /// Editor font
    var editorFont: NSFont {
        NSFont(name: editorFontName, size: editorFontSize)
            ?? NSFont.monospacedSystemFont(ofSize: editorFontSize, weight: .regular)
    }

    // MARK: - File Paths

    private var preferencesURL: URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }

        return appSupport
            .appendingPathComponent("QuillSwift")
            .appendingPathComponent("preferences.json")
    }

    private var customCSSURL: URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }

        return appSupport
            .appendingPathComponent("QuillSwift")
            .appendingPathComponent("custom.css")
    }

    // MARK: - Initialization

    private init() {
        // Set defaults before loading
        self.appearanceMode = .system
        self.editorFontName = "SF Mono"
        self.editorFontSize = 14
        self.previewFontSize = 16
        self.previewLineHeight = 1.6
        self.customCSS = ""
        self.showLineNumbers = false
        self.livePreviewEnabled = false
        self.enableMermaid = false  // Disabled by default for security
        self.enableMath = false     // Disabled by default for security

        loadPreferences()
    }

    // MARK: - Persistence

    private func loadPreferences() {
        guard let url = preferencesURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let prefs = try JSONDecoder().decode(ThemePreferences.self, from: data)

            appearanceMode = prefs.appearanceMode
            editorFontName = prefs.editorFontName
            editorFontSize = prefs.editorFontSize
            previewFontSize = prefs.previewFontSize
            previewLineHeight = prefs.previewLineHeight
            showLineNumbers = prefs.showLineNumbers
            livePreviewEnabled = prefs.livePreviewEnabled ?? false
            enableMermaid = prefs.enableMermaid ?? false
            enableMath = prefs.enableMath ?? false
        } catch {
            print("Failed to load theme preferences: \(error)")
        }

        // Load custom CSS separately
        if let cssURL = customCSSURL,
           FileManager.default.fileExists(atPath: cssURL.path) {
            do {
                customCSS = try String(contentsOf: cssURL, encoding: .utf8)
            } catch {
                print("Failed to load custom CSS: \(error)")
            }
        }
    }

    private func savePreferences() {
        guard let url = preferencesURL else { return }

        let prefs = ThemePreferences(
            appearanceMode: appearanceMode,
            editorFontName: editorFontName,
            editorFontSize: editorFontSize,
            previewFontSize: previewFontSize,
            previewLineHeight: previewLineHeight,
            showLineNumbers: showLineNumbers,
            livePreviewEnabled: livePreviewEnabled,
            enableMermaid: enableMermaid,
            enableMath: enableMath
        )

        do {
            // Create directory if needed
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(prefs)
            try data.write(to: url)

            // Save custom CSS separately
            if let cssURL = customCSSURL, !customCSS.isEmpty {
                try customCSS.write(to: cssURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Failed to save theme preferences: \(error)")
        }
    }

    // MARK: - Theme Export/Import

    /// Export current theme as JSON
    func exportTheme() throws -> Data {
        let theme = ExportableTheme(
            appearanceMode: appearanceMode,
            editorFontName: editorFontName,
            editorFontSize: editorFontSize,
            previewFontSize: previewFontSize,
            previewLineHeight: previewLineHeight,
            showLineNumbers: showLineNumbers,
            livePreviewEnabled: livePreviewEnabled,
            enableMermaid: enableMermaid,
            enableMath: enableMath,
            customCSS: customCSS
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(theme)
    }

    /// Import theme from JSON data
    func importTheme(from data: Data) throws {
        let theme = try JSONDecoder().decode(ExportableTheme.self, from: data)

        appearanceMode = theme.appearanceMode
        editorFontName = theme.editorFontName
        editorFontSize = theme.editorFontSize
        previewFontSize = theme.previewFontSize
        previewLineHeight = theme.previewLineHeight
        showLineNumbers = theme.showLineNumbers
        livePreviewEnabled = theme.livePreviewEnabled ?? false
        enableMermaid = theme.enableMermaid ?? false
        enableMath = theme.enableMath ?? false
        customCSS = theme.customCSS
    }

    /// Reset to default settings
    func resetToDefaults() {
        appearanceMode = .system
        editorFontName = "SF Mono"
        editorFontSize = 14
        previewFontSize = 16
        previewLineHeight = 1.6
        customCSS = ""
        showLineNumbers = false
        livePreviewEnabled = false
        enableMermaid = false
        enableMath = false
    }
}

// MARK: - Appearance Mode

enum AppearanceMode: String, Codable, CaseIterable {
    case system = "System"
    case light = "Light"
    case dark = "Dark"
}

// MARK: - Persistence Models

private struct ThemePreferences: Codable {
    let appearanceMode: AppearanceMode
    let editorFontName: String
    let editorFontSize: CGFloat
    let previewFontSize: CGFloat
    let previewLineHeight: CGFloat
    let showLineNumbers: Bool
    let livePreviewEnabled: Bool?  // Optional for backward compatibility
    let enableMermaid: Bool?       // Optional for backward compatibility
    let enableMath: Bool?          // Optional for backward compatibility
}

private struct ExportableTheme: Codable {
    let appearanceMode: AppearanceMode
    let editorFontName: String
    let editorFontSize: CGFloat
    let previewFontSize: CGFloat
    let previewLineHeight: CGFloat
    let showLineNumbers: Bool
    let livePreviewEnabled: Bool?  // Optional for backward compatibility
    let enableMermaid: Bool?       // Optional for backward compatibility
    let enableMath: Bool?          // Optional for backward compatibility
    let customCSS: String
}
