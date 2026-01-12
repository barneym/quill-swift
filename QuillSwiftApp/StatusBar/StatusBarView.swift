import SwiftUI
import AppKit
import MarkdownRenderer

/// A status bar displaying document statistics and file path.
///
/// Shows word count, character count, and a clickable path bar similar to Finder.
/// When cursor is on a checkbox line, shows the checkbox type name.
struct StatusBarView: View {

    // MARK: - Properties

    /// The document text for statistics
    let text: String

    /// The file URL of the document (nil for unsaved)
    let fileURL: URL?

    /// Current line text (for checkbox detection)
    var currentLine: String?

    /// Computed word count
    private var wordCount: Int {
        let words = text.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }

    /// Computed character count (excluding whitespace)
    private var characterCount: Int {
        text.filter { !$0.isWhitespace }.count
    }

    /// Computed line count
    private var lineCount: Int {
        guard !text.isEmpty else { return 1 }
        return text.components(separatedBy: .newlines).count
    }

    /// Detect checkbox type on current line
    private var currentCheckboxType: CheckboxType? {
        guard let line = currentLine else { return nil }
        return parseCheckboxFromLine(line)
    }

    /// Parse a checkbox from a line of text
    private func parseCheckboxFromLine(_ line: String) -> CheckboxType? {
        // Match checkbox pattern: - [X] or * [X] or + [X] or numbered list with checkbox
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        // Check for task list patterns
        let patterns = [
            "^[-*+]\\s+\\[(.)]",     // Unordered: - [x], * [x], + [x]
            "^\\d+\\.\\s+\\[(.)]",   // Ordered: 1. [x]
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let charRange = Range(match.range(at: 1), in: trimmed) {
                let checkboxChar = String(trimmed[charRange])
                return CheckboxRegistry.shared.type(forId: checkboxChar)
            }
        }

        return nil
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 0) {
            // Statistics
            HStack(spacing: 12) {
                statisticLabel(value: wordCount, singular: "word", plural: "words")
                statisticLabel(value: characterCount, singular: "char", plural: "chars")
                statisticLabel(value: lineCount, singular: "line", plural: "lines")
            }
            .padding(.horizontal, 12)

            // Checkbox type indicator
            if let checkboxType = currentCheckboxType {
                Divider()
                    .frame(height: 12)
                    .padding(.horizontal, 8)

                HStack(spacing: 4) {
                    Text(checkboxType.name)
                        .font(.caption)
                        .foregroundColor(Color(nsColor: NSColor(hex: checkboxType.cssColor(isDark: false)) ?? .secondaryLabelColor))
                }
            }

            Spacer()

            // Path bar
            if let fileURL = fileURL {
                PathBarView(url: fileURL)
                    .padding(.horizontal, 8)
            } else {
                Text("Unsaved Document")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
            }
        }
        .frame(height: 22)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Subviews

    private func statisticLabel(value: Int, singular: String, plural: String) -> some View {
        Text("\(value) \(value == 1 ? singular : plural)")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}

/// A clickable path bar showing file location, similar to Finder.
struct PathBarView: View {

    let url: URL

    /// Path components for display
    private var pathComponents: [(name: String, url: URL)] {
        var components: [(String, URL)] = []
        var currentURL = url.deletingLastPathComponent()

        // Add file name first
        components.append((url.lastPathComponent, url))

        // Walk up the path (limit depth for display)
        let maxDepth = 4
        var depth = 0

        while currentURL.path != "/" && depth < maxDepth {
            components.insert((currentURL.lastPathComponent, currentURL), at: 0)
            currentURL = currentURL.deletingLastPathComponent()
            depth += 1
        }

        // Add ellipsis if we truncated
        if currentURL.path != "/" && depth >= maxDepth {
            components.insert(("...", currentURL), at: 0)
        }

        return components
    }

    var body: some View {
        HStack(spacing: 2) {
            let components = pathComponents
            ForEach(0..<components.count, id: \.self) { index in
                if index > 0 {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundColor(Color(nsColor: .tertiaryLabelColor))
                }

                PathComponentButton(
                    name: components[index].name,
                    url: components[index].url,
                    isLast: index == components.count - 1
                )
            }
        }
    }
}

/// A single clickable path component.
struct PathComponentButton: View {

    let name: String
    let url: URL
    let isLast: Bool

    @State private var isHovering = false

    var body: some View {
        Text(name)
            .font(.caption)
            .fontWeight(isLast ? .medium : .regular)
            .foregroundColor(isLast ? .primary : .secondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(isHovering ? Color.secondary.opacity(0.2) : Color.clear)
            )
            .onHover { hovering in
                isHovering = hovering
            }
            .onTapGesture {
                revealInFinder()
            }
            .contextMenu {
                Button("Open in Finder") {
                    revealInFinder()
                }

                Button("Copy Path") {
                    copyPath()
                }

                if !isLast {
                    Divider()
                    Button("Open Enclosing Folder") {
                        openInFinder()
                    }
                }
            }
    }

    private func revealInFinder() {
        NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
    }

    private func openInFinder() {
        NSWorkspace.shared.open(url)
    }

    private func copyPath() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.path, forType: .string)
    }
}

// MARK: - NSColor Hex Extension

extension NSColor {
    /// Create NSColor from hex string
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        if length == 6 {
            let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            let b = CGFloat(rgb & 0x0000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: 1.0)
        } else if length == 8 {
            let r = CGFloat((rgb & 0xFF000000) >> 24) / 255.0
            let g = CGFloat((rgb & 0x00FF0000) >> 16) / 255.0
            let b = CGFloat((rgb & 0x0000FF00) >> 8) / 255.0
            let a = CGFloat(rgb & 0x000000FF) / 255.0
            self.init(red: r, green: g, blue: b, alpha: a)
        } else {
            return nil
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        Text("Document Content")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white)

        StatusBarView(
            text: "Hello world, this is a test document with some words.",
            fileURL: URL(fileURLWithPath: "/Users/demo/Documents/Projects/QuillSwift/README.md"),
            currentLine: "- [/] In progress task"
        )
    }
    .frame(width: 600, height: 200)
}
