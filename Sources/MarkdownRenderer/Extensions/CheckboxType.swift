import Foundation

/// Represents a custom checkbox type with styling and display properties.
///
/// Checkbox types can be defined in:
/// - App bundle defaults
/// - User configuration (~/.../QuillSwift/checkboxes.json)
/// - Per-document frontmatter
public struct CheckboxType: Codable, Equatable, Hashable, Sendable {

    // MARK: - Properties

    /// Unique identifier used in markdown syntax (e.g., "x", "/", "?")
    public let id: String

    /// SF Symbol name for rendering (e.g., "checkmark.square.fill")
    public let symbol: String

    /// Color for light mode (hex or system color name)
    public let colorLight: String

    /// Color for dark mode (hex or system color name)
    public let colorDark: String

    /// Human-readable name for tooltips/status bar
    public let name: String

    // MARK: - Initialization

    public init(
        id: String,
        symbol: String,
        colorLight: String,
        colorDark: String,
        name: String
    ) {
        self.id = id
        self.symbol = symbol
        self.colorLight = colorLight
        self.colorDark = colorDark
        self.name = name
    }

    // MARK: - Color Helpers

    /// Get the appropriate color string for the current appearance
    public func colorForAppearance(isDark: Bool) -> String {
        isDark ? colorDark : colorLight
    }

    /// Convert color string to CSS color value
    public func cssColor(isDark: Bool) -> String {
        let color = colorForAppearance(isDark: isDark)

        // If already a hex color, return as-is
        if color.hasPrefix("#") {
            return color
        }

        // Convert system color names to hex
        return systemColorToHex(color, isDark: isDark)
    }

    /// Convert system color names to hex values
    private func systemColorToHex(_ name: String, isDark: Bool) -> String {
        // Map common system color names to hex values
        let lightColors: [String: String] = [
            "systemGreen": "#34C759",
            "systemBlue": "#007AFF",
            "systemRed": "#FF3B30",
            "systemOrange": "#FF9500",
            "systemYellow": "#FFCC00",
            "systemPurple": "#AF52DE",
            "systemPink": "#FF2D55",
            "systemGray": "#8E8E93",
            "systemTeal": "#5AC8FA",
            "systemIndigo": "#5856D6",
        ]

        let darkColors: [String: String] = [
            "systemGreen": "#30D158",
            "systemBlue": "#0A84FF",
            "systemRed": "#FF453A",
            "systemOrange": "#FF9F0A",
            "systemYellow": "#FFD60A",
            "systemPurple": "#BF5AF2",
            "systemPink": "#FF375F",
            "systemGray": "#8E8E93",
            "systemTeal": "#64D2FF",
            "systemIndigo": "#5E5CE6",
        ]

        let colors = isDark ? darkColors : lightColors
        return colors[name] ?? (isDark ? "#757575" : "#9E9E9E")
    }
}

// MARK: - Default Checkbox Types

extension CheckboxType {

    /// Standard completed checkbox [x]
    public static let complete = CheckboxType(
        id: "x",
        symbol: "checkmark.square.fill",
        colorLight: "#4CAF50",
        colorDark: "#81C784",
        name: "Complete"
    )

    /// Standard empty/pending checkbox [ ]
    public static let pending = CheckboxType(
        id: " ",
        symbol: "square",
        colorLight: "#9E9E9E",
        colorDark: "#757575",
        name: "Pending"
    )

    /// In progress checkbox [/]
    public static let inProgress = CheckboxType(
        id: "/",
        symbol: "circle.lefthalf.filled",
        colorLight: "#2196F3",
        colorDark: "#64B5F6",
        name: "In Progress"
    )

    /// Cancelled checkbox [-]
    public static let cancelled = CheckboxType(
        id: "-",
        symbol: "minus.square",
        colorLight: "#9E9E9E",
        colorDark: "#757575",
        name: "Cancelled"
    )

    /// Question/needs clarification [?]
    public static let question = CheckboxType(
        id: "?",
        symbol: "questionmark.circle",
        colorLight: "#FF9800",
        colorDark: "#FFB74D",
        name: "Question"
    )

    /// Important/urgent [!]
    public static let important = CheckboxType(
        id: "!",
        symbol: "exclamationmark.triangle",
        colorLight: "#F44336",
        colorDark: "#E57373",
        name: "Important"
    )

    /// All default checkbox types
    public static let defaults: [CheckboxType] = [
        .complete,
        .pending,
        .inProgress,
        .cancelled,
        .question,
        .important,
    ]
}
