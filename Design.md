# QuillSwift Design Document

**Version:** 0.1 (Initial Swift Draft)
**Last Updated:** January 2026
**Status:** Architecture Planning
**Based on:** Quill Design Document v0.5

---

## 1. Executive Summary

QuillSwift is a native macOS markdown editor built in Swift that prioritizes the single-file editing workflow. Unlike vault-based systems (Obsidian) or workspace-centric editors (VS Code), QuillSwift treats each markdown file as an independent document — open it, edit it, save it, close it.

This is a native Swift implementation of the Quill concept, designed to eliminate the web-native friction encountered in the Tauri-based version while maintaining the same core philosophy and feature priorities.

**Key differentiators from Quill (Tauri):**
- Pure Swift implementation (no JS↔Rust IPC)
- SwiftUI-first with AppKit integration where needed
- Native macOS menus, windows, and dialogs
- First-class sandbox and notarization support
- Future iOS/iPadOS portability potential

---

## 2. Design Principles

1. **File-first, not project-first** — No vaults, workspaces, or import flows. Files live where they live.
2. **Ship incrementally** — A working source editor with preview is more valuable than a half-finished inline editor.
3. **Simple by default** — Core editing works out of the box; advanced features are opt-in.
4. **Specification compliance with pragmatism** — Target CommonMark + GFM baseline; extensions are documented and toggleable.
5. **Native feel** — Respect macOS conventions for window management, keyboard shortcuts, and system integration.
6. **Unified rendering** — One parser, one renderer. Preview and export must match.
7. **Maintainable architecture** — Prefer proven solutions; build custom only where necessary for unified experience.
8. **Apple best practices** — Follow Human Interface Guidelines, use system frameworks, embrace declarative patterns.

---

## 3. QuillSwift Markdown Profile

QuillSwift supports a defined markdown dialect to avoid scope creep and set clear expectations.

### 3.1 Base Specification

| Specification | Version | Status |
|---------------|---------|--------|
| CommonMark | 0.30 | Required |
| GitHub Flavored Markdown | 0.29-gfm | Required |

### 3.2 Conformance Testing

QuillSwift's conformance is measured by automated test harnesses, not absolute claims.

| Test Suite | Source | Requirement |
|------------|--------|-------------|
| CommonMark spec tests | `spec.txt` from commonmark/commonmark-spec | Must pass |
| GFM spec tests | `spec.txt` from github/cmark-gfm | Must pass |
| Known deviations | `CONFORMANCE.md` in QuillSwift repo | Documented allowlist |

**Known deviations policy:**
- Goal: empty list
- Any deviation must be documented with rationale
- Deviations require maintainer approval
- Deviations are reviewed each major release for potential resolution

### 3.3 Extensions

Each extension is classified by:
- **Default:** Enabled out of the box?
- **Conflicts:** Syntax conflicts with other extensions?
- **Fidelity:** Round-trip expectations
- **Security:** Requires elevated trust?

**Default philosophy:** Minimal safe. Extensions that execute code, fetch remote resources, or render complex SVG are off by default.

| Extension | Default | Conflicts | Fidelity | Security | Priority |
|-----------|---------|-----------|----------|----------|----------|
| YAML front matter | Yes | No | Structural | Safe | P1 |
| Footnotes | Yes | No | Structural | Safe | P2 |
| Emoji shortcodes | Yes | No | Render | Safe | P2 |
| Custom checkboxes | Yes | No | Structural | Safe | P1 |
| Math (KaTeX) | **No** | No | Structural | Low risk | P2 |
| Mermaid diagrams | **No** | No | Lexical | **Elevated** | P2 |
| Table of contents | No | No | N/A | Safe | P2 |
| Highlight (`==text==`) | No | No | Structural | Safe | P3 |

### 3.4 Custom Checkbox Types

QuillSwift supports extended checkbox syntax inspired by Obsidian plugins (e.g., Anypino/Tasks):

**Standard syntax:**
```markdown
- [ ] Unchecked
- [x] Checked
```

**Extended syntax (opt-in):**
```markdown
- [/] In progress
- [-] Cancelled
- [>] Deferred/forwarded
- [<] Scheduled
- [?] Question
- [!] Important
- [*] Star
- ["] Quote/citation
- [l] Location
- [i] Information
- [S] Savings/money
- [I] Idea
- [p] Pro
- [c] Con
- [b] Bookmark
- [f] Fire/urgent
```

**Implementation notes:**
- Rendered as styled checkboxes with distinct icons/colors
- Click behavior: cycle through standard states (unchecked → checked → unchecked)
- Custom states preserve their type when round-tripping
- User can configure which extended types are enabled
- Styling customizable via CSS/theme

### 3.5 Trusted Mode

For documents requiring rich rendering (KaTeX, Mermaid), users can:
1. **Enable globally** in preferences (applies to all documents)
2. **Enable per-window** via menu (View → Enable Rich Rendering)

**Scope:** Per-window. Each window maintains independent trust state. Opening a new document in a new window starts untrusted.

**UI indicator:** When trusted mode is active, the window displays a "Rich" badge in the title bar or status area.

Trusted mode is not persisted per-document to avoid metadata pollution.

---

## 4. Round-Trip Fidelity Model

### 4.1 Fidelity Levels

| Level | Description | Example |
|-------|-------------|---------|
| **Render** | Renders correctly; saving may reformat | Emoji `:smile:` may save as 😄 or `:smile:` |
| **Structural** | Headings, lists, links preserved; formatting may normalize | `*` bullets may become `-` bullets |
| **Lexical** | Preserves exact tokens, whitespace, bullet symbols where possible | Original formatting retained |

### 4.2 Fidelity Commitments

**P0-P1 (Source editing):** Lexical fidelity — what you type is what you get.

**P2+ (Preview editing):** Structural fidelity for edited blocks; lexical fidelity for untouched blocks.

**Explicit non-goals:**
- We do not guarantee lexical fidelity when using preview/inline editing
- We do not preserve trailing whitespace unless meaningful (hard breaks)
- We normalize line endings per user preference on save

---

## 5. Rendering Security Policy

QuillSwift is intended for work use with untrusted documents. Security defaults are conservative.

### 5.1 HTML Sanitization

**Scope:** Sanitization applies only to user-authored raw HTML embedded in Markdown. HTML generated by QuillSwift's Markdown renderer is considered application output and is not subject to the raw-HTML input sanitizer.

Sanitization uses a strict allowlist approach for both tags and attributes.

#### Allowed Tags

`a`, `abbr`, `b`, `blockquote`, `br`, `code`, `dd`, `del`, `details`, `dl`, `dt`, `em`, `h1`, `h2`, `h3`, `h4`, `h5`, `h6`, `hr`, `i`, `img`, `ins`, `kbd`, `li`, `mark`, `ol`, `p`, `pre`, `q`, `s`, `samp`, `small`, `span`, `strong`, `sub`, `summary`, `sup`, `table`, `tbody`, `td`, `tfoot`, `th`, `thead`, `tr`, `ul`, `var`

#### URL Sanitization (href, src)

| Scheme | Allowed | Notes |
|--------|---------|-------|
| `http://`, `https://` | Yes | External links |
| `mailto:` | Yes | Email links |
| `#` (fragment) | Yes | In-document anchors |
| Relative paths | Yes | See §5.2 for click behavior |
| `javascript:` | **No** | Rendered as plain text |
| `file://` | **No** | Rendered as plain text |
| `data:` | **Restricted** | Images only, size limited |

### 5.2 Link Click Behavior

#### External Links
| Link Type | Behavior |
|-----------|----------|
| `http://`, `https://` | Open in default browser |
| `mailto:` | Open in default mail client |

#### Relative Links
Relative links resolve against the document's directory.

| Resolved Target | Click Behavior |
|-----------------|----------------|
| Markdown file (`.md`, `.markdown`) | Open in QuillSwift in new window |
| Image file (`.png`, `.jpg`, etc.) | Open in Quick Look |
| Other file types | Show confirmation dialog or reveal in Finder |
| Directory | Show in Finder |
| Non-existent path | Show error |

### 5.3 Image Handling

| Image Source | Default Behavior | User Override |
|--------------|------------------|---------------|
| **Local relative path** | Render | N/A |
| **Local absolute path** | Render with warning badge | N/A |
| **Remote URL (http/https)** | **Placeholder** | "Load remote images" setting |
| **Data URI (allowed types)** | Render (size limit: 5MB) | N/A |
| **Data URI (SVG)** | **Blocked** | No override |

### 5.4 Diagram Rendering (Mermaid)

Mermaid diagrams execute JavaScript to render SVG. Security measures:

| Measure | Implementation |
|---------|----------------|
| **Default state** | Disabled — renders as fenced code block |
| **Activation** | Requires trusted mode (per-window or global) |
| **Sandbox** | Render in isolated WKWebView |
| **Size limits** | Max 50KB diagram source; timeout after 5 seconds |

---

## 6. Feature Requirements

### 6.1 P0 — Minimum Viable Product (Ship Fast)

These features define the **first public release**. Goal: a functional source editor with preview toggle that people can actually use.

#### File Operations

| ID | Feature | Description |
|----|---------|-------------|
| P0-F01 | Open file from Finder | Double-click `.md` file opens in QuillSwift |
| P0-F02 | Open file via menu/shortcut | File → Open (⌘O) |
| P0-F03 | Create new file | File → New (⌘N), creates untitled document |
| P0-F04 | Save file | File → Save (⌘S), Save As (⇧⌘S) |
| P0-F05 | File association | Register as handler for `.md`, `.markdown` |
| P0-F06 | Dirty state indicator | Window title shows unsaved changes (•) |
| P0-F07 | Close confirmation | Prompt to save unsaved changes on close |

#### UI Layout

| ID | Feature | Description |
|----|---------|-------------|
| P0-U01 | Single-pane window | One view at a time (source or preview) |
| P0-U02 | Toggle source/preview | ⌘E switches between modes |
| P0-U03 | Mode indicator | Visual indicator of current mode in title bar or status |

#### Editing — Source Mode

| ID | Feature | Description |
|----|---------|-------------|
| P0-E01 | Text input | Standard text entry with cursor |
| P0-E02 | Selection | Mouse and keyboard selection |
| P0-E03 | Cut/Copy/Paste | Standard clipboard operations |
| P0-E04 | Undo/Redo | Multi-level undo stack (⌘Z, ⇧⌘Z) |
| P0-E05 | Find | Find in document (⌘F) |
| P0-E06 | Find and Replace | Find with replacement (⌘⌥F) |
| P0-E07 | Syntax highlighting | Visual distinction for markdown elements |

#### Preview Mode

| ID | Feature | Description |
|----|---------|-------------|
| P0-P01 | Rendered preview | See formatted output (read-only) |
| P0-P02 | Scroll position sync | Maintain reading position on toggle |

#### Rendering

| ID | Feature | Description |
|----|---------|-------------|
| P0-R01 | CommonMark parsing | Per conformance tests (§3.2) |
| P0-R02 | GFM parsing | Tables, task lists, strikethrough, autolinks |
| P0-R03 | Fenced code blocks | Syntax highlighting for common languages |

#### Window Management

| ID | Feature | Description |
|----|---------|-------------|
| P0-W01 | Multiple windows | Each file opens in independent window |
| P0-W02 | Native window chrome | Standard macOS title bar |

**P0 Success Criteria:**
- User can open a markdown file, edit it in source mode, preview the result, and save
- All operations work via keyboard
- Preview output matches what export will produce (unified renderer)
- Conformance tests pass (per §3.2)
- No crashes on files up to 1MB

---

### 6.2 P1 — Polished Source Editor

These features make the source editor **pleasant to use daily**. Target: v1.0 release.

#### Enhanced File Operations

| ID | Feature | Description |
|----|---------|-------------|
| P1-F01 | Recent files | File → Open Recent |
| P1-F02 | Window state persistence | Remember size/position per file |
| P1-F03 | Additional file extensions | `.mdown`, `.mkd`, `.mkdn` support |
| P1-F04 | Encoding detection | UTF-8, UTF-16, ISO-8859-1 |

#### Source Editing Enhancements

| ID | Feature | Description |
|----|---------|-------------|
| P1-E01 | Line numbers | Optional line number gutter |
| P1-E02 | Auto-completion | Brackets, quotes, markdown syntax |
| P1-E03 | Smart lists | Auto-continue list items on Enter |
| P1-E04 | Formatting shortcuts | ⌘B (bold), ⌘I (italic), etc. |
| P1-E05 | Heading shortcuts | ⌘1-6 for heading levels |
| P1-E06 | Link shortcut | ⌘K for insert link |
| P1-E07 | Custom checkboxes | Extended checkbox syntax (§3.4) |

#### Extended Markdown

| ID | Feature | Description |
|----|---------|-------------|
| P1-M01 | YAML front matter | Parse and display as collapsible block |

#### Preview Enhancements

| ID | Feature | Description |
|----|---------|-------------|
| P1-P01 | Click-to-edit | Click preview element → switch to source at that location |
| P1-P02 | Link hover preview | Show URL in status bar on hover |

#### Appearance

| ID | Feature | Description |
|----|---------|-------------|
| P1-A01 | Light theme | Clean light color scheme |
| P1-A02 | Dark theme | Dark color scheme |
| P1-A03 | System theme follow | Match macOS light/dark setting |
| P1-A04 | Font customization | Editor font family and size |

#### Statistics

| ID | Feature | Description |
|----|---------|-------------|
| P1-S01 | Word count | Real-time word count in status bar |
| P1-S02 | Character count | With/without spaces |

---

### 6.3 P2 — Rich Editing & Extensions

These features add **inline/preview editing** and **extended markdown**. Target: v1.x releases.

#### Extended Markdown Rendering

| ID | Feature | Description |
|----|---------|-------------|
| P2-M01 | Math rendering (KaTeX) | Inline and display math (requires trusted mode) |
| P2-M02 | Mermaid diagrams | Flowcharts, sequence diagrams (requires trusted mode) |
| P2-M03 | Footnotes | Reference-style footnotes |
| P2-M04 | Emoji shortcodes | `:smile:` → 😄 |
| P2-M05 | Table of contents | Auto-generate from headings |

#### Theming & Customization

| ID | Feature | Description |
|----|---------|-------------|
| P2-T01 | CSS customization | User-provided CSS for preview styling |
| P2-T02 | Theme import | Import community themes (CSS files) |
| P2-T03 | Preview style settings | Font, spacing, margins, image presentation |

#### Export

| ID | Feature | Description |
|----|---------|-------------|
| P2-X01 | Export to HTML | Standalone HTML file (uses preview renderer) |
| P2-X02 | Export to PDF | Print preview to PDF (WYSIWYG) |
| P2-X03 | Copy as HTML | Copy rendered HTML to clipboard |

#### Image Handling

| ID | Feature | Description |
|----|---------|-------------|
| P2-G01 | Paste image from clipboard | Auto-save to relative path |
| P2-G02 | Drag-drop images | Insert image reference |
| P2-G03 | Image sizing controls | UI for image dimensions |

---

### 6.4 P3 — Enhanced Experience

These features **polish the experience** but are not release blockers. Target: v2.x releases.

#### Productivity

| ID | Feature | Description |
|----|---------|-------------|
| P3-P01 | Command palette | ⌘⇧P fuzzy command search |
| P3-P02 | Outline sidebar | Navigate by headings |
| P3-P03 | Customizable shortcuts | User-configurable key bindings |
| P3-P04 | Spell check | System spell checker integration |
| P3-P05 | Split view | Optional side-by-side source + preview |

#### Visual Enhancements

| ID | Feature | Description |
|----|---------|-------------|
| P3-V01 | Additional themes | 4-6 built-in themes |
| P3-V02 | Custom CSS editor | In-app CSS editing with preview |
| P3-V03 | Distraction-free mode | Fullscreen minimal chrome |

#### macOS Integration

| ID | Feature | Description |
|----|---------|-------------|
| P3-I01 | Quick Look extension | Render preview in Finder |
| P3-I02 | Share sheet | macOS share menu support |
| P3-I03 | Services menu | System services integration |
| P3-I04 | URL handler | `quillswift://open?file=path` |

---

### 6.5 P4 — Future Considerations

These features may be **deferred indefinitely**. Evaluate for v3.0+.

#### Cross-Platform

| ID | Feature | Description |
|----|---------|-------------|
| P4-C01 | iOS/iPadOS support | Using SwiftUI shared code |
| P4-C02 | Catalyst | Mac Catalyst as alternative |

#### Advanced Features

| ID | Feature | Description |
|----|---------|-------------|
| P4-A01 | Tabs | Tabbed interface |
| P4-A02 | Sidebar file browser | Optional folder view |
| P4-A03 | Inline editing | Edit rendered content directly (Typora-style) |

---

## 7. Technical Architecture

### 7.1 Framework: SwiftUI + AppKit Hybrid

**Rationale:**
- SwiftUI provides modern, declarative UI patterns
- AppKit integration for complex text editing (NSTextView/TextKit 2)
- Native macOS integration without bridges
- Future iOS/iPadOS portability via SwiftUI

### 7.2 Architecture Decision: Editor Engine

**Status:** Under research. See METHODOLOGY.md §4.

**Options being evaluated:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **NSTextView + TextKit 2** | Apple's native text system | Fully native, good i18n/IME | Significant custom work |
| **WKWebView + CodeMirror** | Web editor in native shell | Feature-complete, proven | Hybrid complexity |
| **Custom editor** | Purpose-built from scratch | Full control, reusable | Largest scope |

**Decision criteria:**
- Rich content support (tables, images, diagrams)
- Future mobile portability
- Development velocity vs. long-term maintainability
- Native feel and performance

### 7.3 Architecture Decision: Preview Rendering

**Status:** Under research. See METHODOLOGY.md §5.

**Options being evaluated:**

| Option | Description | Pros | Cons |
|--------|-------------|------|------|
| **Native AttributedString** | Pure Swift rendering | Fast, native | Limited for complex content |
| **WKWebView** | HTML rendering | Full capability | Hybrid architecture |
| **Hybrid** | Native for simple, WebView for complex | Best of both | Two paths to maintain |

**Leaning:** WKWebView for preview is pragmatic given rich content requirements (tables, diagrams, math). Preview is read-only, reducing hybrid complexity.

### 7.4 CSS Customization Architecture (P2)

For users who want to customize preview styling:

**User-provided CSS location:**
```
~/Library/Application Support/QuillSwift/themes/
├── custom.css           # User's custom overrides
├── imported-theme.css   # Downloaded themes
└── ...
```

**Customizable elements:**
- Font family, size, line height
- Heading styles (color, size, spacing)
- Code block styling (background, font)
- Table borders and padding
- Image framing and max-width
- Blockquote styling
- Checkbox icons and colors
- Mermaid diagram theming
- Link colors and hover states

**CSS variable system:**
```css
:root {
  /* Typography */
  --qs-font-body: -apple-system, sans-serif;
  --qs-font-mono: SF Mono, Menlo, monospace;
  --qs-font-size: 16px;
  --qs-line-height: 1.6;

  /* Colors */
  --qs-color-text: #1a1a1a;
  --qs-color-heading: #000000;
  --qs-color-link: #0066cc;
  --qs-color-code-bg: #f5f5f5;

  /* Spacing */
  --qs-spacing-paragraph: 1em;
  --qs-spacing-heading: 1.5em;

  /* Images */
  --qs-image-max-width: 100%;
  --qs-image-border-radius: 4px;

  /* Checkboxes */
  --qs-checkbox-size: 18px;
  --qs-checkbox-checked-color: #22c55e;
  --qs-checkbox-cancelled-color: #ef4444;
}
```

Users can override any variable or add custom CSS rules.

### 7.5 Module Structure

```
QuillSwift/
├── Sources/
│   ├── QuillSwift/              # Main app target
│   │   ├── App/                 # App entry, window management
│   │   ├── Editor/              # Source editing view
│   │   ├── Preview/             # Rendered preview view
│   │   ├── Document/            # Document model, state
│   │   ├── Settings/            # Preferences
│   │   └── Shared/              # Shared utilities
│   │
│   ├── MarkdownRenderer/        # Standalone library
│   │   ├── Parser/              # Markdown → AST
│   │   ├── Renderer/            # AST → HTML/AttributedString
│   │   ├── Extensions/          # GFM, checkboxes, etc.
│   │   └── Sanitizer/           # HTML sanitization
│   │
│   └── SyntaxHighlighter/       # Standalone library
│       ├── Languages/           # Language definitions
│       ├── Themes/              # Highlight themes
│       └── Renderer/            # Token → styled output
│
├── Tests/
│   ├── QuillSwiftTests/
│   ├── MarkdownRendererTests/
│   └── SyntaxHighlighterTests/
│
└── Package.swift
```

### 7.6 Dependency Direction

```
App (QuillSwift)
    ↓
┌───┴───┐
Editor  Preview
  ↓       ↓
Document ←─┐
  ↓        │
┌──────────┘
│
MarkdownRenderer ← SyntaxHighlighter
    ↓
Shared/lib
```

**Hard constraints:**
- `Editor` CANNOT import `Preview`
- `MarkdownRenderer` is a standalone library with no app dependencies
- `SyntaxHighlighter` is a standalone library with no app dependencies
- `Document` has no UI dependencies

---

## 8. QuillSwift Core Rule

To maintain the "simple file editor" philosophy, any feature must pass this test:

**A feature is in scope if it:**
1. Operates on a single document at a time
2. Requires no persistent metadata beyond the file itself (except window geometry and cursor)
3. Does not require background processes when no document is open
4. Does not maintain per-folder or per-project state

**Features that violate this rule are P4 or rejected:**
- File browser sidebar (violates #4)
- Cross-file search (violates #1)
- Background sync (violates #3)
- Project-level settings (violates #4)

---

## 9. Per-File Metadata Storage

QuillSwift stores minimal per-file metadata for user convenience.

### 9.1 What We Store

| Data | Storage Location | Lifetime |
|------|------------------|----------|
| Window position/size | UserDefaults/macOS preferences | Until cleared |
| Last cursor position | UserDefaults | Until cleared |
| Last scroll position | UserDefaults | Until cleared |
| Last view mode | UserDefaults | Until cleared |

### 9.2 Storage Policy

- **No sidecar files** — We never create `.quillswift` or similar files alongside documents
- **No extended attributes** — We don't use xattr on the file

---

## 10. Performance Metrics

### 10.1 Target Metrics

| Metric | Target | Notes |
|--------|--------|-------|
| Cold start | < 500ms | Native should be faster than Tauri |
| File open (100KB) | < 50ms | |
| File open (1MB) | < 200ms | |
| Typing latency | < 16ms | 60fps |
| Idle CPU | 0% | No background activity |
| Idle memory | < 50MB | Native should be lighter |

### 10.2 Large File Strategy

| File Size | Behavior |
|-----------|----------|
| < 500KB | Full rendering, live preview sync |
| 500KB - 5MB | Debounced preview updates (300ms) |
| > 5MB | Warning dialog; offer "source only" mode |
| > 10MB | Source only mode enforced |

---

## 11. Keyboard Shortcuts

### 11.1 File Operations

| Shortcut | Action |
|----------|--------|
| ⌘N | New file |
| ⌘O | Open file |
| ⌘S | Save |
| ⇧⌘S | Save As |
| ⌘W | Close window |
| ⌘Q | Quit |

### 11.2 Editing

| Shortcut | Action |
|----------|--------|
| ⌘Z | Undo |
| ⇧⌘Z | Redo |
| ⌘X | Cut |
| ⌘C | Copy |
| ⌘V | Paste |
| ⌘A | Select all |
| ⌘F | Find |
| ⌘G | Find next |
| ⇧⌘G | Find previous |
| ⌘⌥F | Find and replace |

### 11.3 Formatting (P1+)

| Shortcut | Action |
|----------|--------|
| ⌘B | Bold |
| ⌘I | Italic |
| ⌘K | Insert link |
| ⌃` | Inline code |
| ⌘1-6 | Heading level |

### 11.4 View

| Shortcut | Action |
|----------|--------|
| ⌘E | Toggle source/preview |
| ⌘+ | Zoom in |
| ⌘- | Zoom out |
| ⌘0 | Reset zoom |

---

## 12. Configuration

### 12.1 Settings Location

- **Path:** `~/Library/Application Support/QuillSwift/settings.json`
- **Format:** JSON (or plist if more Apple-native)
- **Hot reload:** Yes

### 12.2 Default Settings

```json
{
  "editor": {
    "fontFamily": "SF Mono",
    "fontSize": 14,
    "lineHeight": 1.6,
    "tabSize": 2,
    "insertSpaces": true,
    "wordWrap": true,
    "showLineNumbers": false
  },
  "appearance": {
    "theme": "system"
  },
  "markdown": {
    "extensions": {
      "yaml_frontmatter": true,
      "footnotes": true,
      "emoji": true,
      "custom_checkboxes": true,
      "math": false,
      "mermaid": false
    }
  },
  "security": {
    "allowRawHtml": false,
    "loadRemoteImages": false
  },
  "customCSS": {
    "enabled": false,
    "path": null
  }
}
```

---

## 13. Testing Strategy

### 13.1 Test Types

| Type | Framework | Purpose |
|------|-----------|---------|
| Unit | XCTest | Pure logic testing |
| Integration | XCTest | Component interaction |
| UI | XCUITest | End-to-end user flows |
| Snapshot | swift-snapshot-testing | Visual regression |
| Conformance | Custom harness | Markdown spec compliance |

### 13.2 Conformance Tests

| Suite | Frequency | Failure Policy |
|-------|-----------|----------------|
| CommonMark spec | Every CI run | Block merge |
| GFM spec | Every CI run | Block merge |
| QuillSwift fixtures | Every CI run | Block merge |

---

## 14. Contribution Policy

### 14.1 License

**MIT License**

Chosen for simplicity and broad compatibility.

### 14.2 Contribution Requirements

**DCO (Developer Certificate of Origin)**

All contributions require DCO sign-off:
```
Signed-off-by: Name <email>
```

---

## 15. Open Questions

1. **Editor engine approach** — NSTextView vs WKWebView vs Custom. See METHODOLOGY.md for research.

2. **Preview rendering approach** — Native vs WebView vs Hybrid. See METHODOLOGY.md for research.

3. **Minimum macOS version** — 13 (Ventura) for TextKit 2? 14 (Sonoma) for latest SwiftUI?

4. **Document-based app architecture** — Does SwiftUI's DocumentGroup fit our "no hidden metadata" philosophy?

5. **Naming** — "QuillSwift" vs something else. May want unique name before public announcement.

---

## 16. Revision History

| Version | Date | Changes |
|---------|------|---------|
| 0.1 | Jan 2026 | Initial Swift draft, adapted from Quill v0.5 |

---

*This document is adapted from the Quill Design Document v0.5. It retains the core philosophy and feature requirements while adapting the technical architecture for native Swift implementation.*
