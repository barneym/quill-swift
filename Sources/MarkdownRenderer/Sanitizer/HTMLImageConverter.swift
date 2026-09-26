import Foundation
import Markdown

/// Rewrites HTML `<img>` tags in markdown source as native `![alt](src "title")`.
///
/// Only lossless conversions are made. Pixel `width`/`height` use Obsidian's
/// size syntax (`![alt|300](src)`, `![alt|300x200](src)`), which QuillSwift's
/// renderer also understands. An image with any other attribute (`align`,
/// `style`, percentage sizes, …) is left as HTML and counted in `keptCount`. Tags
/// inside code spans and code blocks are never touched, because only images the
/// parser reports as raw HTML are considered. An HTML block is converted only
/// when it holds nothing but images; markdown inside a larger HTML block would
/// not render.
public enum HTMLImageConverter {

    public struct Edit: Equatable {
        /// UTF-16 range in the source (NSRange-compatible)
        public let location: Int
        public let length: Int
        public let replacement: String
    }

    public struct Result: Equatable {
        public let edits: [Edit]
        /// `<img>` tags left as HTML because converting would lose attributes
        public let keptCount: Int

        public var convertedCount: Int { edits.count }
    }

    static let convertibleAttributes: Set<String> = ["src", "alt", "title", "width", "height"]

    /// Find convertible images. Apply `edits` from last to first.
    public static func convert(_ markdown: String) -> Result {
        let document = Document(parsing: markdown)
        let lineStarts = utf8LineStarts(markdown)
        var edits: [Edit] = []
        var kept = 0

        func visit(_ markup: Markup) {
            if let html = (markup as? InlineHTML)?.rawHTML ?? (markup as? HTMLBlock)?.rawHTML,
               html.range(of: "<img", options: .caseInsensitive) != nil,
               let range = markup.range {
                let tags = allTags(in: html)
                let images = tags.filter { $0.name == "img" && !$0.isClosing }
                let convertible = images.compactMap(markdownImage)
                kept += images.count - convertible.count
                let onlyImages = !images.isEmpty && images.count == convertible.count
                    && tags.count == images.count
                    && strippingTags(html).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                if onlyImages, let span = utf16Range(of: range, in: markdown, lineStarts: lineStarts) {
                    // Keep any line ending the source range includes
                    let original = (markdown as NSString).substring(with: NSRange(location: span.location, length: span.length))
                    let replacement = convertible.joined(separator: markup is HTMLBlock ? "\n" : " ")
                        + (original.hasSuffix("\n") ? "\n" : "")
                    edits.append(Edit(location: span.location, length: span.length, replacement: replacement))
                } else if !onlyImages {
                    kept += convertible.count
                }
                return
            }
            for child in markup.children { visit(child) }
        }
        visit(document)
        return Result(edits: edits.sorted { $0.location < $1.location }, keptCount: kept)
    }

    /// Apply a result to a string (for tests and non-AppKit callers).
    public static func apply(_ result: Result, to markdown: String) -> String {
        let text = NSMutableString(string: markdown)
        for edit in result.edits.reversed() {
            text.replaceCharacters(in: NSRange(location: edit.location, length: edit.length), with: edit.replacement)
        }
        return text as String
    }

    // MARK: - Helpers

    private static func allTags(in html: String) -> [HTMLSanitizer.Tag] {
        var tags: [HTMLSanitizer.Tag] = []
        var index = html.startIndex
        while let start = html[index...].firstIndex(of: "<") {
            if let tag = HTMLSanitizer.parseTag(in: html, at: start) {
                tags.append(tag)
                index = tag.end
            } else {
                index = html.index(after: start)
            }
        }
        return tags
    }

    private static func strippingTags(_ html: String) -> String {
        var out = ""
        var index = html.startIndex
        while let start = html[index...].firstIndex(of: "<") {
            out += html[index..<start]
            if let tag = HTMLSanitizer.parseTag(in: html, at: start) {
                index = tag.end
            } else {
                out += "<"
                index = html.index(after: start)
            }
        }
        return out + html[index...]
    }

    /// `![alt](src "title")` for a lossless image tag, else nil.
    private static func markdownImage(_ tag: HTMLSanitizer.Tag) -> String? {
        var values: [String: String] = [:]
        for attribute in tag.attributes {
            guard convertibleAttributes.contains(attribute.name) else { return nil }
            values[attribute.name] = attribute.value ?? ""
        }
        guard let src = values["src"], !src.isEmpty else { return nil }
        // Obsidian size suffix: pixel values only (percentages etc. stay HTML)
        var size = ""
        let width = values["width"].map(pixels), height = values["height"].map(pixels)
        switch (width, height) {
        case (nil, nil): break
        case (.some(let w?), nil): size = "|\(w)"
        case (.some(let w?), .some(let h?)): size = "|\(w)x\(h)"
        default: return nil
        }
        let alt = (values["alt"] ?? "")
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
        let needsBrackets = src.contains { $0 == " " || $0 == "(" || $0 == ")" }
        let destination = needsBrackets ? "<\(src)>" : src
        var title = ""
        if let value = values["title"], !value.isEmpty {
            title = " \"\(value.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return "![\(alt)\(size)](\(destination)\(title))"
    }

    /// "300" or "300px" → 300; anything else → nil
    private static func pixels(_ value: String) -> Int? {
        var text = value.trimmingCharacters(in: .whitespaces).lowercased()
        if text.hasSuffix("px") { text.removeLast(2) }
        guard let number = Int(text), number > 0 else { return nil }
        return number
    }

    /// UTF-8 offsets of each line start (SourceLocation columns count UTF-8 bytes).
    private static func utf8LineStarts(_ text: String) -> [Int] {
        var starts = [0]
        for (offset, byte) in text.utf8.enumerated() where byte == 0x0A {
            starts.append(offset + 1)
        }
        return starts
    }

    private static func utf16Range(of range: SourceRange, in text: String, lineStarts: [Int]) -> (location: Int, length: Int)? {
        func utf8Offset(_ location: SourceLocation) -> Int? {
            guard location.line >= 1, location.line <= lineStarts.count else { return nil }
            return lineStarts[location.line - 1] + location.column - 1
        }
        guard let start = utf8Offset(range.lowerBound), let end = utf8Offset(range.upperBound),
              start <= end, end <= text.utf8.count else { return nil }
        let utf8 = text.utf8
        let startIndex = utf8.index(utf8.startIndex, offsetBy: start)
        let endIndex = utf8.index(utf8.startIndex, offsetBy: end)
        let location = text.utf16.distance(from: text.utf16.startIndex, to: startIndex)
        let length = text.utf16.distance(from: startIndex, to: endIndex)
        return (location, length)
    }
}
