# Markdown Conformance

This document describes QuillSwift's conformance to markdown specifications.

## Specification Targets

QuillSwift uses [swift-markdown](https://github.com/apple/swift-markdown) as its parsing engine, which is designed to parse CommonMark-compliant markdown with extensions.

| Specification | Version | Status |
|--------------|---------|--------|
| [CommonMark](https://spec.commonmark.org/) | 0.30 | Supported |
| [GitHub Flavored Markdown](https://github.github.com/gfm/) | 0.29-gfm | Supported |

## Supported Features

### CommonMark Core

| Feature | Status | Notes |
|---------|--------|-------|
| ATX Headings | ✅ Full | #, ##, ... ###### |
| Setext Headings | ✅ Full | Underline with = or - |
| Paragraphs | ✅ Full | |
| Line Breaks | ✅ Full | Hard and soft breaks |
| Block Quotes | ✅ Full | > prefix |
| Lists (bullet) | ✅ Full | -, *, + markers |
| Lists (ordered) | ✅ Full | 1., 2., etc. |
| Code Spans | ✅ Full | `inline code` |
| Fenced Code | ✅ Full | ``` with language info |
| Indented Code | ✅ Full | 4-space indent |
| Thematic Breaks | ✅ Full | ---, ***, ___ |
| Links (inline) | ✅ Full | [text](url) |
| Links (reference) | ✅ Full | [text][ref] |
| Images | ✅ Full | ![alt](src) |
| Emphasis | ✅ Full | *italic*, **bold** |
| Autolinks | ✅ Full | <http://...> |
| HTML (inline) | ⚠️ Stripped | Security: raw HTML removed |
| HTML (block) | ⚠️ Stripped | Security: raw HTML removed |
| Entity References | ✅ Full | &amp;, &lt;, etc. |
| Backslash Escapes | ✅ Full | \* → * |

### GFM Extensions

| Feature | Status | Notes |
|---------|--------|-------|
| Tables | ✅ Full | Pipe tables with alignment |
| Task Lists | ✅ Full | - [ ] and - [x] |
| Strikethrough | ✅ Full | ~~deleted~~ |
| Autolinks (extended) | ⚠️ Partial | www.* autolinks may require refinement |
| Disallowed HTML | ✅ Full | Dangerous tags filtered |

### QuillSwift Extensions

| Feature | Status | Notes |
|---------|--------|-------|
| Custom Checkboxes | ✅ Full | [/], [-], [?], [!] markers |
| Syntax Highlighting | ✅ Full | 180+ languages via Highlightr |
| Mermaid Diagrams | 🔜 Planned | Phase 3+ |

## Known Deviations

### Security-Motivated Deviations

These deviations are intentional for security:

| Spec Example | Behavior | Reason |
|--------------|----------|--------|
| Raw HTML blocks | Stripped | XSS prevention |
| Raw inline HTML | Stripped | XSS prevention |
| javascript: URLs | Blocked | XSS prevention |
| data: URLs | Blocked | Security risk |

### Implementation Notes

1. **HTML Sanitization**: All raw HTML in markdown source is stripped before rendering. This differs from the CommonMark spec which preserves raw HTML, but is necessary for security in a document-based app.

2. **Link Handling**: External links open in the default browser. Local markdown file links trigger document opening in QuillSwift.

3. **Entity Encoding**: HTML entities in code spans are properly escaped (e.g., `<` → `&lt;`).

## Testing

Conformance tests are in `Tests/MarkdownRendererTests/Conformance/`:

- `CommonMarkTests.swift` - Tests against CommonMark 0.30 examples
- `GFMTests.swift` - Tests against GFM extensions

### Running Tests

```bash
# Run all tests
swift test

# Run only conformance tests
swift test --filter Conformance
```

### CI Integration

Conformance tests run on every pull request. Test failures block merging.

## Deviation Allowlist

To add a new known deviation:

1. Document the deviation in this file with rationale
2. Add a comment in the relevant test file referencing this document
3. Create a test that explicitly documents the expected (deviated) behavior

New deviations require explicit approval and documentation.

## References

- [CommonMark Spec 0.30](https://spec.commonmark.org/0.30/)
- [GFM Spec 0.29-gfm](https://github.github.com/gfm/)
- [swift-markdown](https://github.com/apple/swift-markdown)
- [Highlightr](https://github.com/raspu/Highlightr)
