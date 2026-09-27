import Foundation
import Markdown

/// One math span lifted out of the markdown source before parsing.
struct MathSpan: Equatable {
    /// The TeX between the delimiters
    let tex: String
    /// `$$ … $$` (or a ```math fence) rather than `$ … $`
    let isDisplay: Bool
    /// The span as written, delimiters included (quote markers stripped), for
    /// clean HTML and for placeholders that land somewhere math can't render
    let source: String
    /// Source lines the span covered (1 for a single-line span)
    let lineCount: Int
}

/// Math pre-pass: replaces `$…$` and `$$…$$` spans with alphanumeric
/// placeholders so markdown can't mangle TeX (`a_b_c` emphasis, `\\` escapes,
/// `|` splitting table cells). The renderer swaps the placeholders for math
/// elements in its output.
///
/// Rules follow Obsidian / pandoc `tex_math_dollars`:
/// - `$$ … $$` is display math, on one line or across lines (no blank line inside).
/// - `$ … $` is inline math on one line: the opening `$` is not followed by
///   whitespace, the closing `$` is not preceded by whitespace nor followed by a
///   digit — so "$5 and $10" stays text.
/// - `\$` is a literal dollar.
/// - Nothing inside code spans, fenced or indented code, or HTML blocks changes.
///   (Inline tags don't protect: in `$a<b$` the `<` is TeX, as in pandoc.)
///
/// A multi-line span becomes the placeholder followed by the same number of
/// newlines (each keeping its line's blockquote/indent prefix), so source line
/// numbers — used for scroll sync — are unchanged.
struct MathExtraction {
    /// The markdown with math spans replaced by placeholders
    let markdown: String
    /// Extracted spans; span `i` is marked by `placeholder(i)`
    let spans: [MathSpan]
    /// Placeholder prefix, chosen so it does not already occur in the source
    let prefix: String

    func placeholder(_ index: Int) -> String { "\(prefix)\(index)X" }

    /// Matches any placeholder; group 1 is the span index
    var placeholderPattern: NSRegularExpression {
        try! NSRegularExpression(pattern: "\(prefix)(\\d+)X")
    }

    static func extract(from markdown: String) -> MathExtraction {
        var prefix = "QSMATHPH"
        while markdown.contains(prefix) { prefix += "Q" }
        guard markdown.contains("$") else {
            return MathExtraction(markdown: markdown, spans: [], prefix: prefix)
        }

        let bytes = Array(markdown.utf8)
        let protected = protectedRanges(in: markdown, bytes: bytes)
        var scanner = Scanner(bytes: bytes, protected: protected)
        let found = scanner.scan()
        guard !found.isEmpty else {
            return MathExtraction(markdown: markdown, spans: [], prefix: prefix)
        }

        var output: [UInt8] = []
        output.reserveCapacity(bytes.count)
        var spans: [MathSpan] = []
        var cursor = 0
        for match in found {
            output.append(contentsOf: bytes[cursor..<match.range.lowerBound])
            let index = spans.count
            output.append(contentsOf: Array("\(prefix)\(index)X".utf8))

            // Keep the line structure: one newline (plus that line's quote /
            // indent prefix) for each newline the span covered
            var sourceLines: [String] = []
            let raw = String(decoding: bytes[match.range], as: UTF8.self)
            for (lineIndex, line) in raw.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
                if lineIndex == 0 {
                    sourceLines.append(String(line))
                    continue
                }
                let linePrefix = Self.continuationPrefix(of: line)
                output.append(UInt8(ascii: "\n"))
                output.append(contentsOf: Array(linePrefix.utf8))
                sourceLines.append(String(line.dropFirst(linePrefix.count)))
            }
            let source = sourceLines.joined(separator: "\n")
            let delimiter = match.isDisplay ? 2 : 1
            let tex = String(source.dropFirst(delimiter).dropLast(delimiter))
            spans.append(MathSpan(
                tex: tex,
                isDisplay: match.isDisplay,
                source: source,
                lineCount: sourceLines.count
            ))
            cursor = match.range.upperBound
        }
        output.append(contentsOf: bytes[cursor...])
        return MathExtraction(
            markdown: String(decoding: output, as: UTF8.self),
            spans: spans,
            prefix: prefix
        )
    }

    /// Leading whitespace and blockquote markers of a continuation line
    private static func continuationPrefix(of line: Substring) -> String {
        var end = line.startIndex
        while end < line.endIndex, line[end] == " " || line[end] == "\t" || line[end] == ">" {
            end = line.index(after: end)
        }
        // Keep the prefix only if it is quote markup or indentation, never content
        return String(line[..<end])
    }

    // MARK: - Protected regions (code, HTML blocks)

    /// Byte ranges of code spans, code blocks and HTML blocks in the source, found
    /// with the real parser so every CommonMark code form is covered.
    private static func protectedRanges(in markdown: String, bytes: [UInt8]) -> [Range<Int>] {
        var lineStarts = [0]
        for (offset, byte) in bytes.enumerated() where byte == UInt8(ascii: "\n") {
            lineStarts.append(offset + 1)
        }
        func offset(line: Int, column: Int) -> Int {
            let lineIndex = min(max(line - 1, 0), lineStarts.count - 1)
            return min(lineStarts[lineIndex] + max(column - 1, 0), bytes.count)
        }
        func lineEnd(_ line: Int) -> Int {
            line < lineStarts.count ? lineStarts[line] : bytes.count
        }

        var collector = ProtectedRangeCollector()
        collector.visit(Document(parsing: markdown))
        return collector.found.compactMap { item in
            let range = item.range
            if item.wholeLines {
                let start = offset(line: range.lowerBound.line, column: 1)
                let lastLine = range.upperBound.column <= 1 ? range.upperBound.line - 1 : range.upperBound.line
                let end = lineEnd(max(lastLine, range.lowerBound.line))
                return start < end ? start..<end : nil
            }
            let start = offset(line: range.lowerBound.line, column: range.lowerBound.column)
            let end = offset(line: range.upperBound.line, column: range.upperBound.column)
            return start < end ? start..<end : nil
        }.sorted { $0.lowerBound < $1.lowerBound }
    }

    private struct ProtectedRangeCollector: MarkupWalker {
        var found: [(range: SourceRange, wholeLines: Bool)] = []

        mutating func visitCodeBlock(_ codeBlock: CodeBlock) {
            if let range = codeBlock.range { found.append((range, true)) }
        }
        mutating func visitHTMLBlock(_ html: HTMLBlock) {
            if let range = html.range { found.append((range, true)) }
        }
        mutating func visitInlineCode(_ inlineCode: InlineCode) {
            if let range = inlineCode.range { found.append((range, false)) }
        }
    }

    // MARK: - Delimiter scanning

    private struct Match {
        let range: Range<Int>
        let isDisplay: Bool
    }

    private struct Scanner {
        let bytes: [UInt8]
        let protected: [Range<Int>]

        static let dollar = UInt8(ascii: "$")
        static let backslash = UInt8(ascii: "\\")
        static let newline = UInt8(ascii: "\n")

        /// Index of the protected range containing `position`, if any
        func protectedRange(containing position: Int) -> Range<Int>? {
            // Few ranges in practice; binary search keeps large files fast
            var low = 0, high = protected.count - 1
            while low <= high {
                let mid = (low + high) / 2
                let range = protected[mid]
                if position < range.lowerBound { high = mid - 1 }
                else if position >= range.upperBound { low = mid + 1 }
                else { return range }
            }
            return nil
        }

        func isSpace(_ byte: UInt8) -> Bool {
            byte == 0x20 || byte == 0x09 || byte == 0x0A || byte == 0x0D
        }

        func isDigit(_ byte: UInt8) -> Bool {
            byte >= 0x30 && byte <= 0x39
        }

        /// Whether the line starting at `position` is blank
        func blankLine(at position: Int) -> Bool {
            var index = position
            while index < bytes.count, bytes[index] != Self.newline {
                let byte = bytes[index]
                if byte != 0x20 && byte != 0x09 && byte != 0x0D && byte != UInt8(ascii: ">") { return false }
                index += 1
            }
            return true
        }

        mutating func scan() -> [Match] {
            var matches: [Match] = []
            var index = 0
            while index < bytes.count {
                if let range = protectedRange(containing: index) {
                    index = range.upperBound
                    continue
                }
                let byte = bytes[index]
                if byte == Self.backslash {
                    index += 2
                    continue
                }
                guard byte == Self.dollar else {
                    index += 1
                    continue
                }
                if index + 1 < bytes.count, bytes[index + 1] == Self.dollar {
                    if let end = closeDisplay(from: index + 2) {
                        matches.append(Match(range: index..<end, isDisplay: true))
                        index = end
                    } else {
                        index += 2
                    }
                    continue
                }
                if let end = closeInline(from: index + 1) {
                    matches.append(Match(range: index..<end, isDisplay: false))
                    index = end
                } else {
                    index += 1
                }
            }
            return matches
        }

        /// End (exclusive) of a `$$ … $$` span whose content starts at `start`
        func closeDisplay(from start: Int) -> Int? {
            var index = start
            var hasContent = false
            while index < bytes.count {
                if protectedRange(containing: index) != nil { return nil }
                let byte = bytes[index]
                if byte == Self.backslash {
                    hasContent = true
                    index += 2
                    continue
                }
                if byte == Self.newline, blankLine(at: index + 1) { return nil }
                if byte == Self.dollar, index + 1 < bytes.count, bytes[index + 1] == Self.dollar {
                    return hasContent ? index + 2 : nil
                }
                if !isSpace(byte) { hasContent = true }
                index += 1
            }
            return nil
        }

        /// End (exclusive) of a `$ … $` span whose content starts at `start`
        func closeInline(from start: Int) -> Int? {
            guard start < bytes.count, !isSpace(bytes[start]) else { return nil }
            var index = start
            while index < bytes.count {
                if protectedRange(containing: index) != nil { return nil }
                let byte = bytes[index]
                if byte == Self.newline { return nil }
                if byte == Self.backslash {
                    index += 2
                    continue
                }
                if byte == Self.dollar, index > start {
                    let precededBySpace = isSpace(bytes[index - 1])
                    let followedByDigit = index + 1 < bytes.count && isDigit(bytes[index + 1])
                    if !precededBySpace && !followedByDigit {
                        return index + 1
                    }
                }
                index += 1
            }
            return nil
        }
    }
}
