import AppKit

/// Color theme for the source editor.
///
/// Provides colors for syntax highlighting of markdown elements.
/// Follows system appearance by default.
struct EditorTheme {

    // MARK: - Colors

    /// Editor background color
    let background: NSColor

    /// Default text color
    let text: NSColor

    /// Heading text color (#, ##, etc.)
    let heading: NSColor

    /// Bold/strong text color
    let bold: NSColor

    /// Italic/emphasis text color
    let italic: NSColor

    /// Inline code and code block text color
    let code: NSColor

    /// Code background color
    let codeBackground: NSColor

    /// Link text color
    let link: NSColor

    /// List marker color (-, *, 1.)
    let listMarker: NSColor

    /// Blockquote marker color (>)
    let blockquote: NSColor

    /// Horizontal rule color (---)
    let horizontalRule: NSColor

    // MARK: - Fonts

    /// Base font for the editor
    let font: NSFont

    /// Font for code elements
    let codeFont: NSFont

    // MARK: - Initialization

    init(
        background: NSColor,
        text: NSColor,
        heading: NSColor,
        bold: NSColor,
        italic: NSColor,
        code: NSColor,
        codeBackground: NSColor,
        link: NSColor,
        listMarker: NSColor,
        blockquote: NSColor,
        horizontalRule: NSColor,
        font: NSFont,
        codeFont: NSFont
    ) {
        self.background = background
        self.text = text
        self.heading = heading
        self.bold = bold
        self.italic = italic
        self.code = code
        self.codeBackground = codeBackground
        self.link = link
        self.listMarker = listMarker
        self.blockquote = blockquote
        self.horizontalRule = horizontalRule
        self.font = font
        self.codeFont = codeFont
    }

    // MARK: - Theme Instances

    /// Default theme that follows system appearance
    static var `default`: EditorTheme {
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        return isDark ? .dark : .light
    }

    /// Light theme
    static let light = EditorTheme(
        background: NSColor(calibratedWhite: 1.0, alpha: 1.0),
        text: NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.19, alpha: 1.0),         // #24292f
        heading: NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.15, alpha: 1.0),      // #1f2328
        bold: NSColor(calibratedRed: 0.12, green: 0.14, blue: 0.15, alpha: 1.0),         // #1f2328
        italic: NSColor(calibratedRed: 0.14, green: 0.16, blue: 0.19, alpha: 1.0),       // #24292f
        code: NSColor(calibratedRed: 0.81, green: 0.27, blue: 0.33, alpha: 1.0),         // #cf222e
        codeBackground: NSColor(calibratedRed: 0.96, green: 0.97, blue: 0.98, alpha: 1.0), // #f6f8fa
        link: NSColor(calibratedRed: 0.04, green: 0.41, blue: 0.85, alpha: 1.0),         // #0969da
        listMarker: NSColor(calibratedRed: 0.34, green: 0.38, blue: 0.42, alpha: 1.0),   // #57606a
        blockquote: NSColor(calibratedRed: 0.34, green: 0.38, blue: 0.42, alpha: 1.0),   // #57606a
        horizontalRule: NSColor(calibratedRed: 0.82, green: 0.84, blue: 0.87, alpha: 1.0), // #d0d7de
        font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
        codeFont: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    )

    /// Dark theme
    static let dark = EditorTheme(
        background: NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.09, alpha: 1.0),   // #0d1117
        text: NSColor(calibratedRed: 0.79, green: 0.82, blue: 0.85, alpha: 1.0),         // #c9d1d9
        heading: NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.95, alpha: 1.0),      // #e6edf3
        bold: NSColor(calibratedRed: 0.90, green: 0.93, blue: 0.95, alpha: 1.0),         // #e6edf3
        italic: NSColor(calibratedRed: 0.79, green: 0.82, blue: 0.85, alpha: 1.0),       // #c9d1d9
        code: NSColor(calibratedRed: 0.49, green: 0.74, blue: 0.94, alpha: 1.0),         // #79c0ff
        codeBackground: NSColor(calibratedRed: 0.09, green: 0.11, blue: 0.13, alpha: 1.0), // #161b22
        link: NSColor(calibratedRed: 0.35, green: 0.65, blue: 1.0, alpha: 1.0),          // #58a6ff
        listMarker: NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.62, alpha: 1.0),   // #8b949e
        blockquote: NSColor(calibratedRed: 0.55, green: 0.58, blue: 0.62, alpha: 1.0),   // #8b949e
        horizontalRule: NSColor(calibratedRed: 0.19, green: 0.21, blue: 0.24, alpha: 1.0), // #30363d
        font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
        codeFont: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
    )
}

// MARK: - Equatable

extension EditorTheme: Equatable {
    static func == (lhs: EditorTheme, rhs: EditorTheme) -> Bool {
        // Compare key colors to detect theme changes
        lhs.background == rhs.background &&
        lhs.text == rhs.text &&
        lhs.heading == rhs.heading
    }
}
