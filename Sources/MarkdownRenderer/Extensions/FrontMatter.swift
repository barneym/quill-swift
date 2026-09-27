import Foundation

/// YAML front matter (`---` … `---` at the very top of a document).
///
/// Obsidian, Jekyll, Hugo and most static-site tools treat this block as
/// metadata. Parsed as markdown it becomes a horizontal rule followed by a
/// setext heading (text underlined by `---`), which is why it rendered bold.
/// The preview shows it as a compact properties table, like Obsidian's
/// Properties view; clipboard HTML omits it.
public struct FrontMatter: Equatable {

    /// A property as displayed: a key with a scalar or list value
    public struct Property: Equatable {
        public let key: String
        public let values: [String]
        public let isList: Bool
    }

    /// Raw YAML between the delimiters
    public let yaml: String

    /// Number of source lines the block occupies, delimiters included
    public let lineCount: Int

    /// Parsed properties, or nil when the YAML is more than flat key/value
    /// pairs and lists (then the raw YAML is shown instead)
    public let properties: [Property]?

    // MARK: - Detection

    /// Split leading front matter from `markdown`.
    ///
    /// Returns the front matter and the body with the front matter lines
    /// replaced by empty lines, so source line numbers are unchanged.
    public static func split(_ markdown: String) -> (frontMatter: FrontMatter, body: String)? {
        guard markdown.hasPrefix("---") else { return nil }
        let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false)
        guard let first = lines.first, isDelimiter(first, allowDots: false) else { return nil }

        guard let closing = lines.indices.dropFirst().first(where: { isDelimiter(lines[$0], allowDots: true) }) else {
            return nil
        }
        let yamlLines = lines[1..<closing].map { String($0.trimmingTrailingCR) }
        // An empty "---\n---" pair is a thematic break, not metadata
        guard !yamlLines.isEmpty else { return nil }

        let yaml = yamlLines.joined(separator: "\n")
        let frontMatter = FrontMatter(yaml: yaml, lineCount: closing + 1, properties: parseProperties(yamlLines))
        let body = Array(repeating: "", count: closing + 1).joined(separator: "\n")
            + "\n" + lines[(closing + 1)...].joined(separator: "\n")
        return (frontMatter, body)
    }

    private static func isDelimiter(_ line: Substring, allowDots: Bool) -> Bool {
        let trimmed = line.trimmingTrailingCR.trimmingCharacters(in: .whitespaces)
        return trimmed == "---" || (allowDots && trimmed == "...")
    }

    // MARK: - Minimal YAML (flat maps, inline and block lists, scalars)

    static func parseProperties(_ lines: [String]) -> [Property]? {
        var properties: [Property] = []
        var index = 0
        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            index += 1
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            // Top-level keys only; indentation here means nesting we don't model
            guard line.first.map({ !$0.isWhitespace }) == true,
                  let colon = keyColon(in: line) else { return nil }
            let key = String(line[..<colon]).trimmingCharacters(in: .whitespaces)
            let rest = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)

            if rest.isEmpty {
                // Block list ("- item" lines) or an empty value
                var items: [String] = []
                while index < lines.count {
                    let next = lines[index].trimmingCharacters(in: .whitespaces)
                    guard next.hasPrefix("- ") || next == "-" else { break }
                    items.append(unquote(String(next.dropFirst()).trimmingCharacters(in: .whitespaces)))
                    index += 1
                }
                if index < lines.count, let first = lines[index].first, first.isWhitespace,
                   !lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                    return nil  // nested mapping
                }
                properties.append(Property(key: key, values: items, isList: !items.isEmpty))
            } else if rest.hasPrefix("[") && rest.hasSuffix("]") {
                let inner = rest.dropFirst().dropLast()
                let items = splitFlowList(String(inner)).map(unquote).filter { !$0.isEmpty }
                properties.append(Property(key: key, values: items, isList: true))
            } else if rest.hasPrefix("{") || rest == "|" || rest == ">" || rest.hasPrefix("|") || rest.hasPrefix(">") {
                return nil  // flow maps and block scalars: show raw
            } else {
                properties.append(Property(key: key, values: [unquote(rest)], isList: false))
            }
        }
        return properties
    }

    /// The colon ending a key (`key: value` or `key:`), outside quotes
    private static func keyColon(in line: String) -> String.Index? {
        var quote: Character?
        var index = line.startIndex
        while index < line.endIndex {
            let c = line[index]
            if let q = quote {
                if c == q { quote = nil }
            } else if c == "\"" || c == "'" {
                quote = c
            } else if c == ":" {
                let next = line.index(after: index)
                if next == line.endIndex || line[next] == " " || line[next] == "\t" { return index }
            }
            index = line.index(after: index)
        }
        return nil
    }

    /// Split `a, "b, c", d` on commas outside quotes
    private static func splitFlowList(_ text: String) -> [String] {
        var items: [String] = []
        var current = ""
        var quote: Character?
        for c in text {
            if let q = quote {
                current.append(c)
                if c == q { quote = nil }
            } else if c == "\"" || c == "'" {
                quote = c
                current.append(c)
            } else if c == "," {
                items.append(current.trimmingCharacters(in: .whitespaces))
                current = ""
            } else {
                current.append(c)
            }
        }
        items.append(current.trimmingCharacters(in: .whitespaces))
        return items
    }

    private static func unquote(_ value: String) -> String {
        // Strip a trailing comment on unquoted scalars
        var text = value
        if let first = text.first, first == "\"" || first == "'", text.count >= 2, text.last == first {
            text = String(text.dropFirst().dropLast())
            if first == "\"" { text = text.replacingOccurrences(of: "\\\"", with: "\"") }
            return text
        }
        if let hash = text.range(of: " #") { text = String(text[..<hash.lowerBound]) }
        return text.trimmingCharacters(in: .whitespaces)
    }

    // MARK: - HTML

    /// Properties table (or raw YAML) for the preview.
    public func html(lineAttributes: String) -> String {
        func escape(_ s: String) -> String {
            s.replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        }
        guard let properties else {
            return "<div class=\"qs-frontmatter\"\(lineAttributes)><pre><code>\(escape(yaml))</code></pre></div>\n"
        }
        var html = "<div class=\"qs-frontmatter\"\(lineAttributes)><table>\n"
        for property in properties {
            html += "<tr><th>\(escape(property.key))</th><td>"
            if property.isList {
                html += property.values.map { "<span class=\"qs-property-item\">\(escape($0))</span>" }.joined(separator: " ")
            } else {
                html += escape(property.values.first ?? "")
            }
            html += "</td></tr>\n"
        }
        return html + "</table></div>\n"
    }
}

private extension Substring {
    var trimmingTrailingCR: Substring { last == "\r" ? dropLast() : self }
}
