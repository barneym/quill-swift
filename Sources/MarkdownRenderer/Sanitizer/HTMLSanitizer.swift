import Foundation

/// How raw HTML embedded in markdown is rendered.
public enum RawHTMLPolicy: String, CaseIterable, Sendable {
    /// Keep an allowlist of harmless tags and attributes; drop everything else
    case safe
    /// Show raw HTML as literal text
    case escape
    /// Remove raw HTML entirely
    case strip
}

/// Allowlist sanitizer for raw HTML fragments found in markdown.
///
/// Works tag by tag rather than on a DOM, because the markdown parser hands
/// inline HTML over in pieces (an opening tag and its closing tag arrive as
/// separate nodes). Allowed tags keep only allowed attributes; URL attributes
/// must use a safe scheme. Disallowed tags are removed, and for tags whose
/// content is code or markup (`script`, `style`, …) the content goes too.
/// Text between tags is preserved as-is (it was already HTML in the source).
///
/// Policy, broadly GitHub's: presentational HTML people actually use in
/// markdown (sized images, `<br>`, `<kbd>`, `<details>`, centered divs) keeps
/// working; anything that can run code, load frames, submit forms, or restyle
/// the page does not.
public enum HTMLSanitizer {

    // MARK: - Policy Tables

    /// Tag → attributes it may keep
    static let allowedTags: [String: Set<String>] = {
        let common: Set<String> = ["title", "lang", "dir", "id"]
        var tags: [String: Set<String>] = [:]
        for tag in ["b", "i", "u", "s", "em", "strong", "del", "ins", "mark", "small", "sub", "sup",
                    "kbd", "code", "samp", "var", "abbr", "cite", "q", "dfn", "time", "br", "wbr",
                    "p", "div", "span", "blockquote", "pre", "hr",
                    "h1", "h2", "h3", "h4", "h5", "h6",
                    "ul", "ol", "li", "dl", "dt", "dd",
                    "table", "thead", "tbody", "tfoot", "tr", "caption", "colgroup", "col",
                    "details", "summary", "figure", "figcaption", "picture", "ruby", "rt", "rp"] {
            tags[tag] = common
        }
        tags["a"] = common.union(["href", "name"])
        tags["img"] = common.union(["src", "alt", "width", "height"])
        tags["source"] = ["srcset", "media", "type"]
        tags["ol"] = common.union(["start", "reversed", "type"])
        tags["li"] = common.union(["value"])
        tags["td"] = common.union(["align", "valign", "colspan", "rowspan"])
        tags["th"] = common.union(["align", "valign", "colspan", "rowspan", "scope"])
        tags["col"] = common.union(["span"])
        tags["colgroup"] = common.union(["span"])
        tags["details"] = common.union(["open"])
        tags["time"] = common.union(["datetime"])
        tags["abbr"] = common.union(["title"])
        tags["q"] = common.union(["cite"])
        tags["blockquote"] = common.union(["cite"])
        // README-style centering is ubiquitous
        for tag in ["p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "table", "tr"] {
            tags[tag]?.insert("align")
        }
        return tags
    }()

    /// Tags removed together with everything up to their closing tag
    static let contentDroppingTags: Set<String> = [
        "script", "style", "iframe", "frame", "frameset", "object", "embed", "applet",
        "textarea", "title", "xmp", "noembed", "noframes", "plaintext", "noscript",
        "template", "svg", "math", "select", "option"
    ]

    static let urlAttributes: Set<String> = ["href", "src", "cite", "srcset"]

    // MARK: - Sanitizing

    /// Sanitize a raw HTML fragment under the `.safe` policy.
    public static func sanitize(_ html: String) -> String {
        var output = ""
        var index = html.startIndex
        var droppingUntil: String?

        while index < html.endIndex {
            guard let tagStart = html[index...].firstIndex(of: "<") else {
                if droppingUntil == nil { output += html[index...] }
                break
            }
            if droppingUntil == nil { output += html[index..<tagStart] }

            // Comments are dropped whole
            if html[tagStart...].hasPrefix("<!--") {
                if let end = html.range(of: "-->", range: tagStart..<html.endIndex) {
                    index = end.upperBound
                } else {
                    index = html.endIndex
                }
                continue
            }

            guard let tag = parseTag(in: html, at: tagStart) else {
                // A lone "<" that isn't a tag: keep it escaped
                if droppingUntil == nil { output += "&lt;" }
                index = html.index(after: tagStart)
                continue
            }
            index = tag.end

            if let dropping = droppingUntil {
                if tag.isClosing && tag.name == dropping { droppingUntil = nil }
                continue
            }
            if contentDroppingTags.contains(tag.name) {
                if !tag.isClosing && !tag.isSelfClosing { droppingUntil = tag.name }
                continue
            }
            guard let allowed = allowedTags[tag.name] else { continue }
            output += render(tag, allowedAttributes: allowed)
        }
        return output
    }

    /// Render a fragment under any policy.
    public static func render(_ html: String, policy: RawHTMLPolicy) -> String {
        switch policy {
        case .safe: return sanitize(html)
        case .strip: return ""
        case .escape:
            return html
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
        }
    }

    /// Whether a URL is safe for href/src: http(s), mailto, fragment, relative,
    /// or (for images) an inline raster image.
    public static func isSafeURL(_ value: String, allowImageData: Bool = false) -> Bool {
        // Browsers ignore control characters and whitespace inside schemes ("java\tscript:")
        let compact = value.unicodeScalars
            .filter { !CharacterSet.whitespacesAndNewlines.union(.controlCharacters).contains($0) }
            .map(String.init).joined().lowercased()
        guard let colon = compact.firstIndex(of: ":") else { return true } // relative / fragment
        // A colon after the first "/", "?" or "#" belongs to the path, not a scheme
        if let firstDelimiter = compact.firstIndex(where: { "/?#".contains($0) }), firstDelimiter < colon {
            return true
        }
        let scheme = String(compact[..<colon])
        switch scheme {
        case "http", "https", "mailto":
            return true
        case "data":
            guard allowImageData else { return false }
            return ["data:image/png", "data:image/gif", "data:image/jpeg", "data:image/webp"]
                .contains { compact.hasPrefix($0) }
        default:
            return false
        }
    }

    // MARK: - Tag Parsing

    struct Tag {
        var name: String
        var isClosing: Bool
        var isSelfClosing: Bool
        var attributes: [(name: String, value: String?)]
        var end: String.Index
    }

    /// Parse one tag starting at `start` ("<"). Returns nil if it isn't a tag.
    static func parseTag(in html: String, at start: String.Index) -> Tag? {
        var i = html.index(after: start)
        guard i < html.endIndex else { return nil }
        var isClosing = false
        if html[i] == "/" {
            isClosing = true
            i = html.index(after: i)
        }
        let nameStart = i
        while i < html.endIndex, html[i].isLetter || html[i].isNumber || html[i] == "-" {
            i = html.index(after: i)
        }
        guard i > nameStart, html[nameStart].isLetter else { return nil }
        let name = html[nameStart..<i].lowercased()

        var attributes: [(name: String, value: String?)] = []
        var isSelfClosing = false
        while i < html.endIndex {
            let c = html[i]
            if c == ">" {
                return Tag(name: name, isClosing: isClosing, isSelfClosing: isSelfClosing,
                           attributes: attributes, end: html.index(after: i))
            }
            if c.isWhitespace {
                i = html.index(after: i)
                continue
            }
            if c == "/" {
                isSelfClosing = true
                i = html.index(after: i)
                continue
            }
            // Attribute name
            let attrStart = i
            while i < html.endIndex, !html[i].isWhitespace, !"=>/\"'".contains(html[i]) {
                i = html.index(after: i)
            }
            guard i > attrStart else {
                i = html.index(after: i) // stray quote etc.
                continue
            }
            let attrName = html[attrStart..<i].lowercased()
            while i < html.endIndex, html[i].isWhitespace { i = html.index(after: i) }
            var value: String?
            if i < html.endIndex, html[i] == "=" {
                i = html.index(after: i)
                while i < html.endIndex, html[i].isWhitespace { i = html.index(after: i) }
                guard i < html.endIndex else { return nil }
                if html[i] == "\"" || html[i] == "'" {
                    let quote = html[i]
                    let valueStart = html.index(after: i)
                    guard let valueEnd = html[valueStart...].firstIndex(of: quote) else { return nil }
                    value = String(html[valueStart..<valueEnd])
                    i = html.index(after: valueEnd)
                } else {
                    let valueStart = i
                    while i < html.endIndex, !html[i].isWhitespace, html[i] != ">" {
                        i = html.index(after: i)
                    }
                    value = String(html[valueStart..<i])
                }
            }
            attributes.append((attrName, value))
        }
        return nil // unterminated
    }

    private static func render(_ tag: Tag, allowedAttributes: Set<String>) -> String {
        if tag.isClosing { return "</\(tag.name)>" }
        var out = "<\(tag.name)"
        for attribute in tag.attributes where allowedAttributes.contains(attribute.name) {
            guard let raw = attribute.value else {
                out += " \(attribute.name)"
                continue
            }
            let value = decodeEntities(raw)
            if urlAttributes.contains(attribute.name) {
                let isImageSource = tag.name == "img" && attribute.name == "src"
                guard isSafeURL(value, allowImageData: isImageSource) else { continue }
            }
            out += " \(attribute.name)=\"\(escapeAttribute(value))\""
        }
        return out + (tag.isSelfClosing ? " />" : ">")
    }

    /// Decode the entities that could hide a scheme ("&#106;avascript:")
    private static func decodeEntities(_ value: String) -> String {
        guard value.contains("&") else { return value }
        var result = ""
        var i = value.startIndex
        while i < value.endIndex {
            if value[i] == "&", let semi = value[i...].firstIndex(of: ";"),
               value.distance(from: i, to: semi) <= 10 {
                let entity = value[value.index(after: i)..<semi]
                var scalar: Unicode.Scalar?
                if entity.hasPrefix("#x") || entity.hasPrefix("#X") {
                    scalar = UInt32(entity.dropFirst(2), radix: 16).flatMap(Unicode.Scalar.init)
                } else if entity.hasPrefix("#") {
                    scalar = UInt32(entity.dropFirst()).flatMap(Unicode.Scalar.init)
                } else {
                    let named: [Substring: Unicode.Scalar] = ["amp": "&", "lt": "<", "gt": ">", "quot": "\"",
                                                              "apos": "'", "colon": ":", "tab": "\t", "newline": "\n"]
                    scalar = named[entity]
                }
                if let scalar {
                    result.unicodeScalars.append(scalar)
                    i = value.index(after: semi)
                    continue
                }
            }
            result.append(value[i])
            i = value.index(after: i)
        }
        return result
    }

    private static func escapeAttribute(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
