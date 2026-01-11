# QuillSwift Implementation Plan

## Overview

QuillSwift development proceeds in sequential phases. Each phase must be complete before the next begins.

---

## Phase 0: Scaffold

**Objective:** Bootable SwiftUI macOS app with DocumentGroup architecture.

### Files to Create

```
QuillSwift/
├── Package.swift
├── Sources/
│   └── QuillSwift/
│       ├── QuillSwiftApp.swift      # @main entry with DocumentGroup
│       ├── MarkdownDocument.swift   # Document model (FileDocument)
│       └── ContentView.swift        # Basic text editor view
└── Tests/
    └── QuillSwiftTests/
        └── DocumentTests.swift
```

### Acceptance Criteria

- [ ] `swift build` succeeds
- [ ] `swift test` runs (even with minimal tests)
- [ ] App launches via Xcode or `swift run`
- [ ] File → New creates untitled document
- [ ] File → Open opens file picker
- [ ] File → Save saves document
- [ ] Window shows file content in basic TextEditor

### Boundary Rules

- No markdown parsing
- No preview rendering
- No syntax highlighting
- Just basic text editing with SwiftUI TextEditor

---

## Phase 1: Markdown Rendering (Preview Only)

**Objective:** Parse markdown and display rendered preview in WKWebView.

### Dependencies to Add

```swift
dependencies: [
    .package(url: "https://github.com/swiftlang/swift-markdown.git", from: "0.4.0"),
]
```

### Files to Create/Modify

```
Sources/
├── QuillSwift/
│   ├── Preview/
│   │   ├── PreviewView.swift        # WKWebView wrapper
│   │   └── PreviewTheme.swift       # CSS theme handling
│   └── ContentView.swift            # Add toggle between source/preview
│
├── MarkdownRenderer/                # New library target
│   ├── Public/
│   │   └── MarkdownRenderer.swift   # Public API
│   ├── Renderer/
│   │   └── HTMLRenderer.swift       # AST → HTML walker
│   └── Sanitizer/
│       └── HTMLSanitizer.swift      # Security filtering
│
Resources/
└── Themes/
    ├── default-light.css
    └── default-dark.css
```

### Acceptance Criteria

- [ ] Toggle source/preview with ⌘E
- [ ] Preview shows rendered markdown
- [ ] Headings, paragraphs, lists render correctly
- [ ] Code blocks render (without highlighting initially)
- [ ] Tables render correctly
- [ ] Links are clickable (open in browser)
- [ ] HTML in markdown is sanitized
- [ ] Theme follows system light/dark mode

### Tests Required

- Unit: HTMLRenderer produces correct HTML for basic elements
- Unit: HTMLSanitizer removes dangerous content
- Snapshot: Render fixtures and compare

### Boundary Rules

- No syntax highlighting yet
- No scroll sync
- No custom checkboxes yet
- Preview is read-only

---

## Phase 2: Source Editor Enhancement

**Objective:** Replace basic TextEditor with proper source editing experience.

### Architecture Decision Required

Before starting Phase 2, we must decide between:
- **Path A:** Extract/adapt CodeEdit's editor
- **Path B:** Build on NSTextView + TextKit 2
- **Path C:** WKWebView + CodeMirror

See `RESEARCH.md` for analysis. Create ADR documenting decision.

### Files to Create (vary by path)

**If Path A or B (native editor):**
```
Sources/
├── QuillSwift/
│   └── Editor/
│       ├── SourceEditorView.swift   # NSViewRepresentable wrapper
│       ├── MarkdownTextView.swift   # Custom NSTextView subclass
│       └── LineNumberGutter.swift   # Line numbers
│
├── SyntaxHighlighter/               # New library target
│   ├── Highlighter.swift            # Main API
│   ├── Languages/                   # Language definitions
│   └── Themes/                      # Highlight themes
```

**If Path C (WebView + CodeMirror):**
```
Sources/
├── QuillSwift/
│   └── Editor/
│       ├── WebEditorView.swift      # WKWebView wrapper
│       ├── EditorBridge.swift       # Swift↔JS communication
│       └── Resources/
│           └── codemirror/          # CM6 bundle
```

### Acceptance Criteria

- [ ] Syntax highlighting for markdown elements
- [ ] Line numbers (optional, via setting)
- [ ] Find in document (⌘F)
- [ ] Find and replace (⌘⌥F)
- [ ] Proper undo/redo integration
- [ ] Good performance on 500KB files

### Tests Required

- Unit: Syntax highlighter tokenizes correctly
- Integration: Editor integrates with document model
- Performance: Typing latency < 16ms

### Boundary Rules

- No formatting shortcuts yet (⌘B, etc.)
- No auto-completion
- No smart lists

---

## Phase 3: Code Block Highlighting

**Objective:** Add syntax highlighting to code blocks in preview.

### Dependencies to Add

```swift
dependencies: [
    .package(url: "https://github.com/raspu/Highlightr.git", from: "2.2.1"),
]
```

### Files to Modify

```
Sources/
├── MarkdownRenderer/
│   └── Renderer/
│       └── CodeBlockRenderer.swift  # Integrate Highlightr
│
├── QuillSwift/
│   └── Preview/
│       └── PreviewTheme.swift       # Add highlight CSS
```

### Acceptance Criteria

- [ ] Code blocks in preview are highlighted
- [ ] Language detection from fence info string
- [ ] Highlight theme matches preview theme
- [ ] Common languages work (Swift, JS, Python, Go, etc.)

### Tests Required

- Unit: Code block rendering with various languages
- Snapshot: Highlighted code output

### Boundary Rules

- Only affects preview, not source editor (unless Path C)
- Highlight theme is preview-only setting

---

## Phase 4: Editing Enhancements

**Objective:** Add productivity features for source editing.

### Files to Modify

```
Sources/
├── QuillSwift/
│   ├── Editor/
│   │   ├── FormattingCommands.swift # ⌘B, ⌘I, etc.
│   │   ├── SmartLists.swift         # Auto-continue lists
│   │   └── AutoCompletion.swift     # Bracket completion
│   │
│   └── App/
│       └── Commands.swift           # Menu commands
```

### Acceptance Criteria

- [ ] ⌘B wraps selection in **bold**
- [ ] ⌘I wraps selection in *italic*
- [ ] ⌘K opens link insertion
- [ ] ⌘1-6 sets heading level
- [ ] Enter in list continues list
- [ ] Tab/Shift-Tab adjusts indentation
- [ ] Auto-close brackets and quotes

### Tests Required

- Unit: Formatting commands produce correct markdown
- Unit: Smart list continuation logic
- Integration: Commands work in editor context

### Boundary Rules

- Commands work in source mode only
- No rich editing in preview yet

---

## Phase 5: Custom Checkboxes & Extensions

**Objective:** Support extended checkbox syntax and other markdown extensions.

### Files to Modify

```
Sources/
├── MarkdownRenderer/
│   ├── Extensions/
│   │   ├── CustomCheckboxes.swift   # Extended checkbox parsing
│   │   └── Extensions.swift         # Extension registry
│   │
│   └── Renderer/
│       └── CheckboxRenderer.swift   # Checkbox → HTML
│
Resources/
├── Themes/
│   └── checkboxes.css               # Checkbox styling
│
├── Icons/
│   └── checkboxes/                  # Checkbox icons (SVG or SF Symbols)
```

### Acceptance Criteria

- [ ] Standard checkboxes render and click to toggle
- [ ] Extended checkboxes render with correct icons/colors
- [ ] Click extended checkbox cycles through states
- [ ] Settings to enable/disable extended syntax
- [ ] Custom checkbox CSS variables for theming

### Tests Required

- Unit: Parse extended checkbox syntax
- Unit: Render checkbox HTML correctly
- Integration: Checkbox click updates document

---

## Phase 6: Scroll Sync

**Objective:** Maintain reading position when toggling between source and preview.

### Files to Create

```
Sources/
├── QuillSwift/
│   ├── Preview/
│   │   └── ScrollSync.swift         # Position mapping
│   │
│   └── Editor/
│       └── PositionTracking.swift   # Line → block mapping
```

### Acceptance Criteria

- [ ] Source → Preview: scrolls to corresponding block
- [ ] Preview → Source: scrolls to corresponding line
- [ ] Long documents maintain position accurately
- [ ] Fallback to proportional scroll when no mapping

### Tests Required

- Unit: Line → block mapping generation
- Unit: Scroll position calculation
- Integration: Toggle preserves position

---

## Phase 7: Theming & Customization

**Objective:** Allow users to customize preview appearance.

### Files to Create

```
Sources/
├── QuillSwift/
│   ├── Settings/
│   │   ├── SettingsView.swift       # Preferences UI
│   │   └── ThemeManager.swift       # Load custom CSS
│   │
│   └── Preview/
│       └── CSSVariables.swift       # CSS variable injection
│
Application Support/
└── QuillSwift/
    └── themes/
        └── custom.css               # User CSS location
```

### Acceptance Criteria

- [ ] Settings UI for appearance customization
- [ ] Load user CSS from Application Support
- [ ] CSS variables for all customizable properties
- [ ] Live preview of theme changes
- [ ] Import/export themes

### Tests Required

- Unit: Theme loading and variable extraction
- Integration: CSS applies correctly

---

## Phase 8: Conformance Testing

**Objective:** Automated conformance testing against CommonMark and GFM specs.

### Files to Create

```
Tests/
├── MarkdownRendererTests/
│   └── Conformance/
│       ├── CommonMarkTests.swift
│       └── GFMTests.swift
│
Fixtures/
├── conformance/
│   ├── commonmark/
│   └── gfm/
│
CONFORMANCE.md
```

### Acceptance Criteria

- [ ] CommonMark spec tests run in CI
- [ ] GFM spec tests run in CI
- [ ] Failures block merge
- [ ] Known deviations documented in CONFORMANCE.md
- [ ] Deviation additions require explicit allowlist entry

### Tests Required

- Conformance: All CommonMark 0.30 spec tests
- Conformance: All GFM 0.29 spec tests

---

## Phase 9: Export

**Objective:** Export documents to HTML and PDF.

### Files to Create

```
Sources/
├── QuillSwift/
│   └── Export/
│       ├── HTMLExporter.swift       # Standalone HTML export
│       └── PDFExporter.swift        # Print to PDF
```

### Acceptance Criteria

- [ ] Export to HTML creates standalone file
- [ ] HTML includes inlined CSS
- [ ] Export to PDF via print dialog
- [ ] Copy as HTML to clipboard
- [ ] Exported HTML matches preview exactly

---

## Phase 10: macOS Integration

**Objective:** Deep macOS integration features.

### Files to Create

```
Sources/
├── QuillSwift/
│   └── Integration/
│       ├── QuickLookExtension/      # Finder preview
│       ├── ShareExtension/          # Share sheet
│       └── URLHandler.swift         # quillswift:// protocol
```

### Acceptance Criteria

- [ ] Quick Look preview in Finder
- [ ] Share sheet support
- [ ] URL scheme handler
- [ ] Services menu integration

---

## Milestone Summary

| Phase | Milestone | Target |
|-------|-----------|--------|
| 0-1 | Basic editor + preview | MVP |
| 2-4 | Polished source editing | v0.5 |
| 5-7 | Extensions & customization | v1.0 |
| 8-10 | Conformance & integration | v1.x |

---

## Decision Points

These decisions must be made before proceeding:

| Decision | Phase | Blocker For |
|----------|-------|-------------|
| Editor architecture (A/B/C) | Before Phase 2 | Phase 2-4 |
| Minimum macOS version | Before Phase 0 | All phases |
| Custom editor vs CodeMirror | Before Phase 2 | Architecture |

---

*This plan will be updated as implementation progresses.*
