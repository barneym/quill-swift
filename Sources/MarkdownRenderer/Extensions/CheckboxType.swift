import Foundation

/// Represents a custom checkbox type with styling and display properties.
///
/// Checkbox types can be defined in:
/// - App bundle defaults
/// - User configuration (~/.../QuillSwift/checkboxes.json)
/// - Per-document frontmatter
///
/// The built-in set mirrors the user's Obsidian setup (AnuPpuccin theme's
/// alternate checkboxes plus a bullet-journal snippet), so a `- [b]` item looks
/// the same in QuillSwift's preview as it does in Obsidian.
public struct CheckboxType: Codable, Equatable, Hashable, Sendable {

    /// How the preview draws the checkbox (see `CheckboxRegistry.stylesheet`).
    public enum Presentation: String, Codable, Sendable {
        /// A box filled with the type's color, with `icon` (or a checkmark)
        /// knocked out in the page background color. Obsidian's `[x]`, `[!]`, `[-]`.
        case filled
        /// No box: `icon` drawn in the type's color. Most alternate checkboxes.
        case icon
        /// A translucent box with a solid border, no icon. Obsidian's `[/]`.
        case tinted
    }

    /// Text treatment applied to the item's content, mirroring Obsidian.
    public enum TextStyle: String, Codable, Sendable {
        case strike, italic, bold, faint
    }

    // MARK: - Properties

    /// Unique identifier used in markdown syntax (e.g., "x", "/", "?")
    public let id: String

    /// Best-match SF Symbol name, for native UI (e.g., "checkmark.square.fill")
    public let symbol: String

    /// Color for light mode (hex or system color name)
    public let colorLight: String

    /// Color for dark mode (hex or system color name)
    public let colorDark: String

    /// Human-readable name for tooltips/status bar
    public let name: String

    /// Preview presentation; `nil` means an empty (unchecked-looking) box
    public let presentation: Presentation?

    /// SVG markup used as the icon mask in the preview (single-quoted attributes)
    public let icon: String?

    /// CSS `mask-size` for the icon (default: `contain`, or 65% for the checkmark)
    public let iconSize: String?

    /// Text treatment for the item's content
    public let textStyle: TextStyle?

    // MARK: - Initialization

    public init(
        id: String,
        symbol: String,
        colorLight: String,
        colorDark: String,
        name: String,
        presentation: Presentation? = nil,
        icon: String? = nil,
        iconSize: String? = nil,
        textStyle: TextStyle? = nil
    ) {
        self.id = id
        self.symbol = symbol
        self.colorLight = colorLight
        self.colorDark = colorDark
        self.name = name
        self.presentation = presentation
        self.icon = icon
        self.iconSize = iconSize
        self.textStyle = textStyle
    }

    /// Generic style for a marker with no registered type. Obsidian treats any
    /// single character in `- [c]` as a (checked) task; we draw a neutral
    /// filled checkbox.
    public static func generic(id: String) -> CheckboxType {
        CheckboxType(
            id: id,
            symbol: "checkmark.square",
            colorLight: "#6c6f85",
            colorDark: "#a1a8c9",
            name: "Custom [\(id)]",
            presentation: .filled
        )
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
//
// Colors are the Catppuccin values as defined by the AnuPpuccin Obsidian theme
// (light: Latte, dark: Mocha — the theme defaults, which the vault uses).
// Names follow AnuPpuccin's checkbox labels where it has them (IMP, QUE,
// RSCH, SCH, BKMK, ...) and the Obsidian-community conventions otherwise;
// W/D/R/M/s/E/P/F/H come from the vault's custom-bullet-checkboxes snippet.

extension CheckboxType {

    /// [x] Complete (theme; Catppuccin green)
    public static let complete = CheckboxType(
        id: "x",
        symbol: "checkmark.square.fill",
        colorLight: "#40a02b",
        colorDark: "#a6e3a1",
        name: "Complete",
        presentation: .filled,
        textStyle: .strike
    )

    /// [ ] To Do (default; Catppuccin subtext0)
    public static let pending = CheckboxType(
        id: " ",
        symbol: "square",
        colorLight: "#6c6f85",
        colorDark: "#a1a8c9",
        name: "To Do"
    )

    /// [/] In Progress (theme; Catppuccin subtext0)
    public static let inProgress = CheckboxType(
        id: "/",
        symbol: "square.lefthalf.filled",
        colorLight: "#6c6f85",
        colorDark: "#a1a8c9",
        name: "In Progress",
        presentation: .tinted
    )

    /// [-] Cancelled (theme; Catppuccin red)
    public static let cancelled = CheckboxType(
        id: "-",
        symbol: "xmark.square.fill",
        colorLight: "#d20f39",
        colorDark: "#f38ba8",
        name: "Cancelled",
        presentation: .filled,
        icon: Icons.xmark,
        iconSize: "50%",
        textStyle: .strike
    )

    /// [?] Question (theme; Catppuccin peach)
    public static let question = CheckboxType(
        id: "?",
        symbol: "questionmark.circle.fill",
        colorLight: "#fe640b",
        colorDark: "#fab387",
        name: "Question",
        presentation: .icon,
        icon: Icons.circleQuestion
    )

    /// [!] Important (theme; Catppuccin yellow)
    public static let important = CheckboxType(
        id: "!",
        symbol: "exclamationmark.square.fill",
        colorLight: "#e49320",
        colorDark: "#f9e2af",
        name: "Important",
        presentation: .filled,
        icon: Icons.exclamation,
        iconSize: "20%"
    )

    /// The remaining Obsidian alternate checkboxes (AnuPpuccin + custom snippet)
    public static let obsidianAlternates: [CheckboxType] = [
        // [>] Rescheduled (theme; Catppuccin sapphire)
        CheckboxType(
            id: ">",
            symbol: "arrowshape.turn.up.right.fill",
            colorLight: "#209fb5",
            colorDark: "#74c7ec",
            name: "Rescheduled",
            presentation: .icon,
            icon: Icons.share
        ),
        // [<] Scheduled (theme; Catppuccin teal)
        CheckboxType(
            id: "<",
            symbol: "calendar",
            colorLight: "#179299",
            colorDark: "#94e2d5",
            name: "Scheduled",
            presentation: .icon,
            icon: Icons.calendar
        ),
        // [*] Star (theme; Catppuccin yellow)
        CheckboxType(
            id: "*",
            symbol: "star.fill",
            colorLight: "#e49320",
            colorDark: "#f9e2af",
            name: "Star",
            presentation: .icon,
            icon: Icons.star
        ),
        // ["] Quote (theme; Catppuccin subtext0)
        CheckboxType(
            id: "\"",
            symbol: "quote.opening",
            colorLight: "#6c6f85",
            colorDark: "#a1a8c9",
            name: "Quote",
            presentation: .icon,
            icon: Icons.quoteLeft
        ),
        // [b] Bookmark (theme; Catppuccin red)
        CheckboxType(
            id: "b",
            symbol: "bookmark.fill",
            colorLight: "#d20f39",
            colorDark: "#f38ba8",
            name: "Bookmark",
            presentation: .icon,
            icon: Icons.bookmark
        ),
        // [c] Con (theme; Catppuccin red)
        CheckboxType(
            id: "c",
            symbol: "hand.thumbsdown.fill",
            colorLight: "#d20f39",
            colorDark: "#f38ba8",
            name: "Con",
            presentation: .icon,
            icon: Icons.thumbsDown
        ),
        // [d] Down (theme; Catppuccin red)
        CheckboxType(
            id: "d",
            symbol: "chart.line.downtrend.xyaxis",
            colorLight: "#d20f39",
            colorDark: "#f38ba8",
            name: "Down",
            presentation: .icon,
            icon: Icons.trendingDown
        ),
        // [f] Fire (theme; Catppuccin red)
        CheckboxType(
            id: "f",
            symbol: "flame",
            colorLight: "#d20f39",
            colorDark: "#f38ba8",
            name: "Fire",
            presentation: .icon,
            icon: Icons.flame
        ),
        // [i] Information (theme; Catppuccin blue)
        CheckboxType(
            id: "i",
            symbol: "info.circle.fill",
            colorLight: "#2a6ef5",
            colorDark: "#87b0f9",
            name: "Information",
            presentation: .icon,
            icon: Icons.circleInfo
        ),
        // [I] Idea (theme; Catppuccin yellow)
        CheckboxType(
            id: "I",
            symbol: "lightbulb.fill",
            colorLight: "#e49320",
            colorDark: "#f9e2af",
            name: "Idea",
            presentation: .icon,
            icon: Icons.lightbulb
        ),
        // [k] Key (theme; Catppuccin yellow)
        CheckboxType(
            id: "k",
            symbol: "key.fill",
            colorLight: "#e49320",
            colorDark: "#f9e2af",
            name: "Key",
            presentation: .icon,
            icon: Icons.keyRound
        ),
        // [l] Location (theme; Catppuccin mauve)
        CheckboxType(
            id: "l",
            symbol: "mappin.and.ellipse",
            colorLight: "#8839ef",
            colorDark: "#cba6f7",
            name: "Location",
            presentation: .icon,
            icon: Icons.locationDot
        ),
        // [n] Note (theme; Catppuccin maroon)
        CheckboxType(
            id: "n",
            symbol: "pin.fill",
            colorLight: "#e64553",
            colorDark: "#eba0ac",
            name: "Note",
            presentation: .icon,
            icon: Icons.thumbtack
        ),
        // [p] Pro (theme; Catppuccin green)
        CheckboxType(
            id: "p",
            symbol: "hand.thumbsup.fill",
            colorLight: "#40a02b",
            colorDark: "#a6e3a1",
            name: "Pro",
            presentation: .icon,
            icon: Icons.thumbsUp
        ),
        // [S] Savings (theme; Catppuccin green)
        CheckboxType(
            id: "S",
            symbol: "dollarsign.circle.fill",
            colorLight: "#40a02b",
            colorDark: "#a6e3a1",
            name: "Savings",
            presentation: .icon,
            icon: Icons.sackDollar
        ),
        // [u] Up (theme; Catppuccin green)
        CheckboxType(
            id: "u",
            symbol: "chart.line.uptrend.xyaxis",
            colorLight: "#40a02b",
            colorDark: "#a6e3a1",
            name: "Up",
            presentation: .icon,
            icon: Icons.trendingUp
        ),
        // [w] Win (theme; Catppuccin mauve)
        CheckboxType(
            id: "w",
            symbol: "birthday.cake.fill",
            colorLight: "#8839ef",
            colorDark: "#cba6f7",
            name: "Win",
            presentation: .icon,
            icon: Icons.cake
        ),
        // [W] Waiting (snippet; Catppuccin red)
        CheckboxType(
            id: "W",
            symbol: "hand.raised.fill",
            colorLight: "#d20f39",
            colorDark: "#f38ba8",
            name: "Waiting",
            presentation: .icon,
            icon: Icons.hand,
            textStyle: .italic
        ),
        // [D] Delegated (snippet; Catppuccin blue)
        CheckboxType(
            id: "D",
            symbol: "paperplane.fill",
            colorLight: "#2a6ef5",
            colorDark: "#87b0f9",
            name: "Delegated",
            presentation: .icon,
            icon: Icons.paperPlane
        ),
        // [R] Research (snippet; Catppuccin sky)
        CheckboxType(
            id: "R",
            symbol: "magnifyingglass",
            colorLight: "#04a5e5",
            colorDark: "#89dceb",
            name: "Research",
            presentation: .icon,
            icon: Icons.magnifyingGlass
        ),
        // [M] Meeting (snippet; Catppuccin teal)
        CheckboxType(
            id: "M",
            symbol: "person.2.fill",
            colorLight: "#179299",
            colorDark: "#94e2d5",
            name: "Meeting",
            presentation: .icon,
            icon: Icons.userGroup
        ),
        // [s] Someday/Maybe (snippet; Catppuccin mauve)
        CheckboxType(
            id: "s",
            symbol: "clock.fill",
            colorLight: "#8839ef",
            colorDark: "#cba6f7",
            name: "Someday/Maybe",
            presentation: .icon,
            icon: Icons.clock,
            textStyle: .faint
        ),
        // [E] Energy Required (snippet; Catppuccin yellow)
        CheckboxType(
            id: "E",
            symbol: "flame.fill",
            colorLight: "#e49320",
            colorDark: "#f9e2af",
            name: "Energy Required",
            presentation: .icon,
            icon: Icons.fire,
            textStyle: .bold
        ),
        // [P] Paused (snippet; Catppuccin peach)
        CheckboxType(
            id: "P",
            symbol: "pause.rectangle.fill",
            colorLight: "#fe640b",
            colorDark: "#fab387",
            name: "Paused",
            presentation: .filled,
            icon: Icons.pause,
            iconSize: "20%",
            textStyle: .bold
        ),
        // [F] Focused (snippet; Catppuccin green)
        CheckboxType(
            id: "F",
            symbol: "scope",
            colorLight: "#40a02b",
            colorDark: "#a6e3a1",
            name: "Focused",
            presentation: .icon,
            icon: Icons.bullseye
        ),
        // [H] Habit (snippet; Catppuccin pink)
        CheckboxType(
            id: "H",
            symbol: "arrow.clockwise",
            colorLight: "#ec83d0",
            colorDark: "#f5c2e7",
            name: "Habit",
            presentation: .icon,
            icon: Icons.arrowRotateRight
        ),    ]

    /// All default checkbox types
    public static let defaults: [CheckboxType] = [
        .complete,
        .pending,
        .inProgress,
        .cancelled,
        .question,
        .important,
    ] + obsidianAlternates
}

// MARK: - Icons
//
// Icon artwork, used as CSS masks in the preview:
// - Font Awesome Free 6 icons by Fonticons, Inc. — https://fontawesome.com
//   License: CC BY 4.0 (https://creativecommons.org/licenses/by/4.0/).
//   Only the SVG path data is used, unmodified.
// - Lucide icons (trending-up/down, flame, key-round, cake) — https://lucide.dev
//   License: ISC. Copyright (c) Lucide Contributors.
// The icon choices follow the AnuPpuccin Obsidian theme's custom checkboxes.

extension CheckboxType {
    enum Icons {
        /// QuillSwift's own checkmark (for [x] and unregistered markers)
        static let checkmark = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 12 10'><polyline points='1.5 5.2 4.6 8.2 10.5 1.8' fill='none' stroke='black' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'/></svg>"

        /// Font Awesome Free (CC BY 4.0)
        static let xmark = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 320 512'><path d='M310.6 150.6c12.5-12.5 12.5-32.8 0-45.3s-32.8-12.5-45.3 0L160 210.7 54.6 105.4c-12.5-12.5-32.8-12.5-45.3 0s-12.5 32.8 0 45.3L114.7 256 9.4 361.4c-12.5 12.5-12.5 32.8 0 45.3s32.8 12.5 45.3 0L160 301.3 265.4 406.6c12.5 12.5 32.8 12.5 45.3 0s12.5-32.8 0-45.3L205.3 256 310.6 150.6z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let circleQuestion = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M256 512c141.4 0 256-114.6 256-256S397.4 0 256 0S0 114.6 0 256S114.6 512 256 512zM169.8 165.3c7.9-22.3 29.1-37.3 52.8-37.3h58.3c34.9 0 63.1 28.3 63.1 63.1c0 22.6-12.1 43.5-31.7 54.8L280 264.4c-.2 13-10.9 23.6-24 23.6c-13.3 0-24-10.7-24-24V250.5c0-8.6 4.6-16.5 12.1-20.8l44.3-25.4c4.7-2.7 7.6-7.7 7.6-13.1c0-8.4-6.8-15.1-15.1-15.1H222.6c-3.4 0-6.4 2.1-7.5 5.3l-.4 1.2c-4.4 12.5-18.2 19-30.6 14.6s-19-18.2-14.6-30.6l.4-1.2zM288 352c0 17.7-14.3 32-32 32s-32-14.3-32-32s14.3-32 32-32s32 14.3 32 32z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let exclamation = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 128 512'><path d='M96 64c0-17.7-14.3-32-32-32S32 46.3 32 64V320c0 17.7 14.3 32 32 32s32-14.3 32-32V64zM64 480c22.1 0 40-17.9 40-40s-17.9-40-40-40s-40 17.9-40 40s17.9 40 40 40z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let share = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M307 34.8c-11.5 5.1-19 16.6-19 29.2v64H176C78.8 128 0 206.8 0 304C0 417.3 81.5 467.9 100.2 478.1c2.5 1.4 5.3 1.9 8.1 1.9c10.9 0 19.7-8.9 19.7-19.7c0-7.5-4.3-14.4-9.8-19.5C108.8 431.9 96 414.4 96 384c0-53 43-96 96-96h96v64c0 12.6 7.4 24.1 19 29.2s25 3 34.4-5.4l160-144c6.7-6.1 10.6-14.7 10.6-23.8s-3.8-17.7-10.6-23.8l-160-144c-9.4-8.5-22.9-10.6-34.4-5.4z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let calendar = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 448 512'><path d='M96 32V64H48C21.5 64 0 85.5 0 112v48H448V112c0-26.5-21.5-48-48-48H352V32c0-17.7-14.3-32-32-32s-32 14.3-32 32V64H160V32c0-17.7-14.3-32-32-32S96 14.3 96 32zM448 192H0V464c0 26.5 21.5 48 48 48H400c26.5 0 48-21.5 48-48V192z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let star = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 576 512'><path d='M316.9 18C311.6 7 300.4 0 288.1 0s-23.4 7-28.8 18L195 150.3 51.4 171.5c-12 1.8-22 10.2-25.7 21.7s-.7 24.2 7.9 32.7L137.8 329 113.2 474.7c-2 12 3 24.2 12.9 31.3s23 8 33.8 2.3l128.3-68.5 128.3 68.5c10.8 5.7 23.9 4.9 33.8-2.3s14.9-19.3 12.9-31.3L438.5 329 542.7 225.9c8.6-8.5 11.7-21.2 7.9-32.7s-13.7-19.9-25.7-21.7L381.2 150.3 316.9 18z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let quoteLeft = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 448 512'><path d='M0 216C0 149.7 53.7 96 120 96h8c17.7 0 32 14.3 32 32s-14.3 32-32 32h-8c-30.9 0-56 25.1-56 56v8h64c35.3 0 64 28.7 64 64v64c0 35.3-28.7 64-64 64H64c-35.3 0-64-28.7-64-64V320 288 216zm256 0c0-66.3 53.7-120 120-120h8c17.7 0 32 14.3 32 32s-14.3 32-32 32h-8c-30.9 0-56 25.1-56 56v8h64c35.3 0 64 28.7 64 64v64c0 35.3-28.7 64-64 64H320c-35.3 0-64-28.7-64-64V320 288 216z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let bookmark = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 384 512'><path d='M0 48V487.7C0 501.1 10.9 512 24.3 512c5 0 9.9-1.5 14-4.4L192 400 345.7 507.6c4.1 2.9 9 4.4 14 4.4c13.4 0 24.3-10.9 24.3-24.3V48c0-26.5-21.5-48-48-48H48C21.5 0 0 21.5 0 48z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let thumbsDown = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M313.4 479.1c26-5.2 42.9-30.5 37.7-56.5l-2.3-11.4c-5.3-26.7-15.1-52.1-28.8-75.2H464c26.5 0 48-21.5 48-48c0-25.3-19.5-46-44.3-47.9c7.7-8.5 12.3-19.8 12.3-32.1c0-23.4-16.8-42.9-38.9-47.1c4.4-7.3 6.9-15.8 6.9-24.9c0-21.3-13.9-39.4-33.1-45.6c.7-3.3 1.1-6.8 1.1-10.4c0-26.5-21.5-48-48-48H294.5c-19 0-37.5 5.6-53.3 16.1L202.7 73.8C176 91.6 160 121.6 160 153.7V192v48 24.9c0 29.2 13.3 56.7 36 75l7.4 5.9c26.5 21.2 44.6 51 51.2 84.2l2.3 11.4c5.2 26 30.5 42.9 56.5 37.7zM32 320H96c17.7 0 32-14.3 32-32V64c0-17.7-14.3-32-32-32H32C14.3 32 0 46.3 0 64V288c0 17.7 14.3 32 32 32z'/></svg>"
        /// Lucide (ISC)
        static let trendingDown = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><polyline points='22 17 13.5 8.5 8.5 13.5 2 7'/><polyline points='16 17 22 17 22 11'/></svg>"
        /// Lucide (ISC)
        static let flame = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.072-2.143-.224-4.054 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.153.433-2.294 1-3a2.5 2.5 0 0 0 2.5 2.5z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let circleInfo = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M256 512c141.4 0 256-114.6 256-256S397.4 0 256 0S0 114.6 0 256S114.6 512 256 512zM216 336h24V272H216c-13.3 0-24-10.7-24-24s10.7-24 24-24h48c13.3 0 24 10.7 24 24v88h8c13.3 0 24 10.7 24 24s-10.7 24-24 24H216c-13.3 0-24-10.7-24-24s10.7-24 24-24zm40-144c-17.7 0-32-14.3-32-32s14.3-32 32-32s32 14.3 32 32s-14.3 32-32 32z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let lightbulb = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 384 512'><path d='M272 384c9.6-31.9 29.5-59.1 49.2-86.2l0 0c5.2-7.1 10.4-14.2 15.4-21.4c19.8-28.5 31.4-63 31.4-100.3C368 78.8 289.2 0 192 0S16 78.8 16 176c0 37.3 11.6 71.9 31.4 100.3c5 7.2 10.2 14.3 15.4 21.4l0 0c19.8 27.1 39.7 54.4 49.2 86.2H272zM192 512c44.2 0 80-35.8 80-80V416H112v16c0 44.2 35.8 80 80 80zM112 176c0 8.8-7.2 16-16 16s-16-7.2-16-16c0-61.9 50.1-112 112-112c8.8 0 16 7.2 16 16s-7.2 16-16 16c-44.2 0-80 35.8-80 80z'/></svg>"
        /// Lucide (ISC)
        static let keyRound = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M2 18v3c0 .6.4 1 1 1h4v-3h3v-3h2l1.4-1.4a6.5 6.5 0 1 0-4-4Z'/><circle cx='16.5' cy='7.5' r='.5'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let locationDot = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 384 512'><path d='M215.7 499.2C267 435 384 279.4 384 192C384 86 298 0 192 0S0 86 0 192c0 87.4 117 243 168.3 307.2c12.3 15.3 35.1 15.3 47.4 0zM192 256c-35.3 0-64-28.7-64-64s28.7-64 64-64s64 28.7 64 64s-28.7 64-64 64z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let thumbtack = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 384 512'><path d='M32 32C32 14.3 46.3 0 64 0H320c17.7 0 32 14.3 32 32s-14.3 32-32 32H290.5l11.4 148.2c36.7 19.9 65.7 53.2 79.5 94.7l1 3c3.3 9.8 1.6 20.5-4.4 28.8s-15.7 13.3-26 13.3H32c-10.3 0-19.9-4.9-26-13.3s-7.7-19.1-4.4-28.8l1-3c13.8-41.5 42.8-74.8 79.5-94.7L93.5 64H64C46.3 64 32 49.7 32 32zM160 384h64v96c0 17.7-14.3 32-32 32s-32-14.3-32-32V384z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let thumbsUp = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M313.4 32.9c26 5.2 42.9 30.5 37.7 56.5l-2.3 11.4c-5.3 26.7-15.1 52.1-28.8 75.2H464c26.5 0 48 21.5 48 48c0 25.3-19.5 46-44.3 47.9c7.7 8.5 12.3 19.8 12.3 32.1c0 23.4-16.8 42.9-38.9 47.1c4.4 7.2 6.9 15.8 6.9 24.9c0 21.3-13.9 39.4-33.1 45.6c.7 3.3 1.1 6.8 1.1 10.4c0 26.5-21.5 48-48 48H294.5c-19 0-37.5-5.6-53.3-16.1l-38.5-25.7C176 420.4 160 390.4 160 358.3V320 272 247.1c0-29.2 13.3-56.7 36-75l7.4-5.9c26.5-21.2 44.6-51 51.2-84.2l2.3-11.4c5.2-26 30.5-42.9 56.5-37.7zM32 192H96c17.7 0 32 14.3 32 32V448c0 17.7-14.3 32-32 32H32c-17.7 0-32-14.3-32-32V224c0-17.7 14.3-32 32-32z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let sackDollar = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M320 96H192L144.6 24.9C137.5 14.2 145.1 0 157.9 0H354.1c12.8 0 20.4 14.2 13.3 24.9L320 96zM192 128H320c3.8 2.5 8.1 5.3 13 8.4C389.7 172.7 512 250.9 512 416c0 53-43 96-96 96H96c-53 0-96-43-96-96C0 250.9 122.3 172.7 179 136.4l0 0 0 0c4.8-3.1 9.2-5.9 13-8.4zm84.1 96c0-11.1-9-20.1-20.1-20.1s-20.1 9-20.1 20.1v6c-5.6 1.2-10.9 2.9-15.9 5.1c-15 6.8-27.9 19.4-31.1 37.7c-1.8 10.2-.8 20 3.4 29c4.2 8.8 10.7 15 17.3 19.5c11.6 7.9 26.9 12.5 38.6 16l2.2 .7c13.9 4.2 23.4 7.4 29.3 11.7c2.5 1.8 3.4 3.2 3.8 4.1c.3 .8 .9 2.6 .2 6.7c-.6 3.5-2.5 6.4-8 8.8c-6.1 2.6-16 3.9-28.8 1.9c-6-1-16.7-4.6-26.2-7.9l0 0 0 0 0 0 0 0c-2.2-.8-4.3-1.5-6.3-2.1c-10.5-3.5-21.8 2.2-25.3 12.7s2.2 21.8 12.7 25.3c1.2 .4 2.7 .9 4.4 1.5c7.9 2.7 20.3 6.9 29.8 9.1V416c0 11.1 9 20.1 20.1 20.1s20.1-9 20.1-20.1v-5.5c5.4-1 10.5-2.5 15.4-4.6c15.7-6.7 28.4-19.7 31.6-38.7c1.8-10.4 1-20.3-3-29.4c-3.9-9-10.2-15.6-16.9-20.5c-12.2-8.8-28.3-13.7-40.4-17.4l-.8-.2c-14.2-4.3-23.8-7.3-29.9-11.4c-2.6-1.8-3.4-3-3.6-3.5c-.2-.3-.7-1.6-.1-5c.3-1.9 1.9-5.2 8.2-8.1c6.4-2.9 16.4-4.5 28.6-2.6c4.3 .7 17.9 3.3 21.7 4.3c10.7 2.8 21.6-3.5 24.5-14.2s-3.5-21.6-14.2-24.5c-4.4-1.2-14.4-3.2-21-4.4V224z'/></svg>"
        /// Lucide (ISC)
        static let trendingUp = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><polyline points='22 7 13.5 15.5 8.5 10.5 2 17'/><polyline points='16 7 22 7 22 13'/></svg>"
        /// Lucide (ISC)
        static let cake = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='none' stroke='currentColor' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'><path d='M20 21v-8a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8'/><path d='M4 16s.5-1 2-1 2.5 2 4 2 2.5-2 4-2 2.5 2 4 2 2-1 2-1'/><path d='M2 21h20'/><path d='M7 8v3'/><path d='M12 8v3'/><path d='M17 8v3'/><path d='M7 4h0.01'/><path d='M12 4h0.01'/><path d='M17 4h0.01'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let hand = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M408.781 128.007C386.356 127.578 368 146.36 368 168.79V256h-8V79.792c0-23.644-19.136-42.78-42.78-42.78-23.644 0-42.78 19.136-42.78 42.78V256h-8V40.792C266.44 17.148 247.304-2 223.66-2c-23.644 0-42.78 19.148-42.78 42.792V256h-8V80.792C172.88 57.148 153.744 38 130.1 38c-23.644 0-42.78 19.148-42.78 42.792V256H78.73c-23.644 0-42.791 19.148-42.791 42.792 0 9.363 2.97 18.048 8.016 25.136l90.727 127.052c11.795 16.512 31.283 26.02 52.013 26.02h130.56c17.01 0 33.292-6.812 45.254-18.896L472.121 346.667C494.185 324.282 494.022 286 471.637 263.937l-62.856-62.93z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let paperPlane = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M498.1 5.6c10.1 7 15.4 19.1 13.5 31.2l-64 416c-1.5 9.7-7.4 18.2-16 23s-18.9 5.4-28 1.6L284 427.7l-68.5 74.1c-8.9 9.7-22.9 12.9-35.2 8.1S160 493.2 160 480V396.4c0-4 1.5-7.8 4.2-10.7L331.8 202.8c5.8-6.3 5.6-16-.4-22s-15.7-6.4-22-.7L106 360.8 17.7 316.6C7.1 311.3 .3 300.7 0 288.9s5.9-22.8 16.1-28.7l448-256c10.7-6.1 23.9-5.5 34 1.4z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let magnifyingGlass = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M416 208c0 45.9-14.9 88.3-40 122.7L502.6 457.4c12.5 12.5 12.5 32.8 0 45.3s-32.8 12.5-45.3 0L330.7 376c-34.4 25.2-76.8 40-122.7 40C93.1 416 0 322.9 0 208S93.1 0 208 0S416 93.1 416 208zM208 352a144 144 0 1 0 0-288 144 144 0 1 0 0 288z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let userGroup = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 640 512'><path d='M144 0a80 80 0 1 1 0 160A80 80 0 1 1 144 0zM512 0a80 80 0 1 1 0 160A80 80 0 1 1 512 0zM0 298.7C0 239.8 47.8 192 106.7 192h42.7c15.9 0 31 3.5 44.6 9.7c-1.3 7.2-1.9 14.7-1.9 22.3c0 38.2 16.8 72.5 43.3 96c-.2 0-.4 0-.7 0H21.3C9.6 320 0 310.4 0 298.7zM405.3 320c-.2 0-.4 0-.7 0c26.6-23.5 43.3-57.8 43.3-96c0-7.6-.7-15-1.9-22.3c13.6-6.3 28.7-9.7 44.6-9.7h42.7C592.2 192 640 239.8 640 298.7c0 11.8-9.6 21.3-21.3 21.3H405.3zM224 224a96 96 0 1 1 192 0 96 96 0 1 1 -192 0zM128 485.3C128 411.7 187.7 352 261.3 352H378.7C452.3 352 512 411.7 512 485.3c0 14.7-11.9 26.7-26.7 26.7H154.7c-14.7 0-26.7-11.9-26.7-26.7z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let clock = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M256 0a256 256 0 1 1 0 512A256 256 0 1 1 256 0zM232 120V256c0 8 4 15.5 10.7 20l96 64c11 7.4 25.9 4.4 33.3-6.7s4.4-25.9-6.7-33.3L280 243.2V120c0-13.3-10.7-24-24-24s-24 10.7-24 24z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let fire = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 448 512'><path d='M159.3 5.4c7.8-7.3 19.9-7.2 27.7 .1c27.6 25.9 53.5 53.8 77.7 84c11-14.4 23.5-30.1 37-42.9c7.9-7.4 20.1-7.4 28 .1c34.6 33 63.9 76.6 84.5 118c20.3 40.8 33.8 82.5 33.8 111.9C448 404.2 348.2 512 224 512C99.8 512 0 404.2 0 276.5c0-38.4 17.8-85.3 45.4-131.7C73.3 97.7 112.7 48.6 159.3 5.4zM225.7 416c25.3 0 47.7-7 68.8-21c42.1-29.4 53.4-88.2 28.1-134.4c-4.5-9-16-9.6-22.5-2l-25.2 29.3c-6.6 7.6-18.5 7.4-24.8-.5c-15.8-20.3-35.8-42.5-59.3-52.4c-12.7-5.4-27.4-.2-33.5 11.9c-8.1 16.1-8.4 34.3-5 51.7c7.8 40 23.1 71.6 47.4 95.2c13.3 12.9 31.3 21.2 51.4 21.2c13.4 0 18.1-17.6 8.2-25.9c-7.9-6.6-10.9-21.8-2.4-30.5c10.6-10.8 35.5 3.3 42.5 14.6c7.7 12.4 11.4 27.2 11.4 42.7c0 34.4-21.4 63.9-51.7 76.2C306.6 409 266.7 416 225.7 416z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let pause = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 320 512'><path d='M48 64C21.5 64 0 85.5 0 112V400c0 26.5 21.5 48 48 48H80c26.5 0 48-21.5 48-48V112c0-26.5-21.5-48-48-48H48zm192 0c-26.5 0-48 21.5-48 48V400c0 26.5 21.5 48 48 48h32c26.5 0 48-21.5 48-48V112c0-26.5-21.5-48-48-48H240z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let bullseye = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M464 256A208 208 0 1 0 48 256a208 208 0 1 0 416 0zM0 256a256 256 0 1 1 512 0A256 256 0 1 1 0 256zm256-96a96 96 0 1 1 0 192 96 96 0 1 1 0-192z'/></svg>"
        /// Font Awesome Free (CC BY 4.0)
        static let arrowRotateRight = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 512 512'><path d='M142.9 142.9c62.2-62.2 162.7-62.5 225.3-1L327 183c-6.9 6.9-8.9 17.2-5.2 26.2s12.5 14.8 22.2 14.8H463.5c0 0 0 0 0 0H472c13.3 0 24-10.7 24-24V72c0-9.7-5.8-18.5-14.8-22.2s-19.3-1.7-26.2 5.2L413.4 96.6c-87.6-86.5-228.7-86.2-315.8 1C73.2 122 55.6 150.7 44.8 181.4c-5.9 16.7 2.9 34.9 19.5 40.8s34.9-2.9 40.8-19.5c7.7-21.8 20.2-42.3 37.8-59.8zM16 312v7.6 .7V440c0 9.7 5.8 18.5 14.8 22.2s19.3 1.7 26.2-5.2L98.6 415.4c87.6 86.5 228.7 86.2 315.8-1C438.8 390 456.4 361.3 467.2 330.6c5.9-16.7-2.9-34.9-19.5-40.8s-34.9 2.9-40.8 19.5c-7.7 21.8-20.2 42.3-37.8 59.8c-62.2 62.2-162.7 62.5-225.3 1L185 328c6.9-6.9 8.9-17.2 5.2-26.2s-12.5-14.8-22.2-14.8H48.4h-.7H40c-13.3 0-24 10.7-24 24z'/></svg>"
    }
}
