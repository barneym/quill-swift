# QuillSwift Implementation Plan

## Overview

QuillSwift development proceeds in sequential phases. Each phase must be complete before the next begins.

---

## Phase 0: Scaffold (COMPLETE)

**Objective:** Bootable SwiftUI macOS app with DocumentGroup architecture.

**Status:** Complete - App builds and runs with proper menus and keyboard focus.

### Project Structure

```
QuillSwift/
├── QuillSwift.xcodeproj/    # Xcode project (macOS app)
├── Package.swift            # SPM manifest (libraries only)
├── QuillSwiftApp/           # App source files
│   ├── QuillSwiftApp.swift
│   ├── ContentView.swift
│   ├── MarkdownDocument.swift
│   ├── Info.plist
│   └── QuillSwift.entitlements
├── Sources/
│   ├── MarkdownRenderer/    # Standalone library
│   └── SyntaxHighlighter/   # Standalone library
└── Tests/
    ├── MarkdownRendererTests/
    └── SyntaxHighlighterTests/
```

### Acceptance Criteria

- [x] `xcodebuild -scheme QuillSwift build` succeeds
- [x] `swift test` runs (35 tests passing)
- [x] App launches with proper menus and keyboard focus
- [x] File → New creates untitled document
- [x] File → Open opens file picker
- [x] File → Save saves document
- [x] Window shows file content in basic TextEditor

### Notes

- Uses hybrid approach: Xcode project for app, SPM for libraries
- This resolves macOS app bundle requirements (Info.plist, entitlements)
- Libraries can still be built/tested independently via `swift build/test`

---

## Phase 1: Markdown Rendering (Preview Only) - COMPLETE

**Objective:** Parse markdown and display rendered preview in WKWebView.

**Status:** Complete. Preview displays rendered markdown with proper theming.

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

- [x] Toggle source/preview with ⌘E
- [x] Preview shows rendered markdown
- [x] Headings, paragraphs, lists render correctly
- [x] Code blocks render (without highlighting initially)
- [x] Tables render correctly
- [x] Links are clickable (open in browser)
- [x] HTML in markdown is sanitized (stripped by default)
- [x] Theme follows system light/dark mode

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

## Phase 2: Source Editor Enhancement - COMPLETE

**Objective:** Replace basic TextEditor with proper source editing experience.

**Status:** Complete. NSTextView-based editor with markdown syntax highlighting.

### Completed Features

- [x] Syntax highlighting for markdown elements
- [x] Line numbers gutter (optional, via `showLineNumbers` parameter)
- [x] Find in document (⌘F)
- [x] Find and Replace (⌘⌥F)
- [x] Status bar with word count, character count, line count
- [x] Clickable path bar (Finder-style, with context menu)
- [x] Proper undo/redo integration
- [x] Code block detection (prevents inline patterns inside fenced blocks)

### Known Issues

- **Replace performance on large files**: Find and Replace can cause UI freeze on 500KB+ files. This is a TextKit performance issue that may need optimization in a future pass.

### Deferred to Later

- **Find in Preview mode**: Will be added when edit capability is added to preview (Phase 5)

### Architecture Decision: Path B (NSTextView + TextKit 2)

Selected native macOS approach for:
- Best IME/accessibility support
- Native macOS text handling
- Full control over rendering
- Foundation for Phase 5 (Live Preview Editing)

Note: Architecture is not a "one-way door" - abstractions kept clean to allow pivoting if needed.

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

## Phase 5: Live Preview Editing (Hybrid WYSIWYG)

**Objective:** Unified editing experience that shows formatted preview while editing markdown source.

**Status:** NOT IMPLEMENTED. Current LivePreviewTextView.swift is broken scaffolding (cursor positioning fails, editing doesn't work). See `docs/PHASE5_HYBRID_EDITING.md` for correct requirements. Reference: Obsidian's Live Preview mode.

### Design Philosophy

This is a **hybrid line-level editor**, not a side-by-side split view. The editor shows formatted text (bold, italic, headings, etc.) but reveals raw markdown syntax when editing.

**Key Principles:**

1. **Markdown Source is Primary**
   - All edits happen to the markdown source
   - Preview formatting is derived/secondary
   - Never lose source fidelity for display convenience

2. **Format on Completion**
   - Formatting updates once valid syntax is complete
   - Example: `**bold**` formats only after closing `**`
   - In-progress edits show raw syntax: `**bold` (not formatted)

3. **Avoid Jitter**
   - Preview can lag behind edits to minimize visual instability
   - Focus on maintaining line, block, and page integrity
   - No flashy/distracting transitions during typing

4. **Context-Aware Syntax Reveal**
   - Cursor entering formatted text reveals the underlying syntax
   - Example: Cursor in bold text shows `**text**`
   - Moving cursor away re-formats the text

5. **Micro-Block Immediate Formatting**
   - Small elements like checkboxes can format immediately
   - `[ ]` → ☐ upon completing the closing bracket
   - Cursor entering the checkbox reverts to `[x]` for easy status change

### Implementation Approach

```
Sources/
├── QuillSwift/
│   └── Editor/
│       ├── LivePreviewTextView.swift    # Hybrid editing view
│       ├── SyntaxRevealManager.swift    # Cursor-aware syntax reveal
│       ├── FormattingEngine.swift       # Markdown → styled text
│       └── JitterPrevention.swift       # Stability during edits
```

### Rendering Model

```
┌─────────────────────────────────────────────────────────────┐
│  Markdown Source (Primary)                                   │
│  "# Hello **World**"                                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  Live Preview Layer (Derived)                               │
│  ┌──────────────────────┐                                   │
│  │ Hello World          │  ← Cursor outside: formatted      │
│  │ (heading, bold)      │                                   │
│  └──────────────────────┘                                   │
│  ┌──────────────────────┐                                   │
│  │ # Hello **World**    │  ← Cursor inside: raw syntax      │
│  └──────────────────────┘                                   │
└─────────────────────────────────────────────────────────────┘
```

### Challenges & Considerations

1. **Cursor Position Mapping**
   - Raw syntax and formatted text have different lengths
   - Must maintain correct cursor position through transitions
   - Example: "**bold**" (8 chars) → "bold" (4 chars formatted)

2. **Block-Level vs Line-Level**
   - Line-level: each line formats/reveals independently
   - Block-level: entire blocks (code fences, blockquotes) as units
   - May need both, with appropriate behavior per element type

3. **Undo/Redo Integration**
   - Undo operates on markdown source
   - Display changes are cosmetic, not in undo stack

4. **Performance**
   - Large documents need efficient incremental updates
   - Only re-render affected lines/blocks
   - Consider TextKit 2 layout management

### Acceptance Criteria

- [ ] Formatted preview displays while editing
- [ ] Cursor entering text reveals raw syntax
- [ ] Cursor leaving text re-formats
- [ ] No jitter/flashing during normal typing
- [ ] Checkboxes format immediately, reveal on cursor enter
- [ ] Headings show formatted size, reveal `#` on cursor
- [ ] Bold/italic show styled, reveal `**`/`*` on cursor
- [ ] Links show styled text, reveal `[text](url)` on cursor
- [ ] Code blocks maintain code styling with fence reveal
- [ ] Proper cursor position through format transitions
- [ ] Undo/redo works correctly

### Tests Required

- Unit: Syntax reveal trigger logic
- Unit: Cursor position mapping through transitions
- Unit: Jitter prevention stability
- Integration: Full edit cycle without visual artifacts
- Performance: No lag on 100KB documents

### Boundary Rules

- Focus on core markdown elements first (headings, bold, italic, links, code)
- Extended elements (tables, custom checkboxes) in later iterations
- Scroll position stability is critical

### Flexibility Note

Implementation may need to deviate based on:
- macOS TextKit capabilities and limitations
- User experience testing and feedback
- Performance characteristics discovered during development

This is directional guidance; actual implementation should optimize for the best user experience.

---

## Phase 6: Custom Checkboxes & Extensions

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

## Phase 7: Scroll Sync

**Objective:** Maintain reading position when toggling between source and preview.

### Position Anchoring Strategy

**Phase 7 (Read-only preview):**
- Anchor to **top visible line** when toggling modes
- Map source line numbers to preview block positions
- Scroll target view to show same content region

**After Phase 5 (Dual editing):**
- Anchor to **cursor line position** when toggling
- Cursor line should appear at same relative screen position
- Not necessary to track specific cursor column within line

**Stretch goal:**
- Preserve cursor column position through mode transitions
- Requires character-level mapping between source and rendered text

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
- [ ] Anchor point is top visible line (Phase 7)
- [ ] Anchor point is cursor line (after Phase 5)
- [ ] Long documents maintain position accurately
- [ ] Fallback to proportional scroll when no mapping

### Tests Required

- Unit: Line → block mapping generation
- Unit: Scroll position calculation
- Integration: Toggle preserves position
- Integration: Cursor line anchoring (after Phase 5)

---

## Phase 8: Theming & Customization

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

## Phase 9: Conformance Testing

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

## Phase 10: Export

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

## Phase 11: macOS Integration

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

## Phase 12: Window & Session Management

**Objective:** Professional multi-document workflow with session persistence.

**Status:** PARTIAL. Session persistence implemented (SessionManager, DraftStorage). Tabbed interface NOT implemented.

### Tab-Based Document Management

Similar to Safari, Finder, and professional editors:

- **Tabbed interface** - Multiple documents open in tabs within a single window
- **Tab drag-out** - Drag a tab out of window to create new window
- **Tab docking** - Drag tabs between windows to consolidate
- **Tab reordering** - Drag tabs to reorder within a window
- **New tab** - ⌘T creates new untitled document in current window
- **Close tab** - ⌘W closes current tab (not window if other tabs exist)

### Session Persistence

Seamless work continuity across app restarts:

- **Remember open windows** - Restore window positions and sizes
- **Remember open tabs** - Restore all open documents per window
- **Preserve unsaved edits** - Keep in-progress changes without forcing save
- **Quick restart support** - System restart returns to exact working state
- **Depart and return** - Close laptop, return next day, continue where you left off

### Implementation Considerations

```
Sources/
├── QuillSwift/
│   └── Session/
│       ├── SessionManager.swift      # Persist/restore session state
│       ├── TabWindowController.swift # Tab management
│       ├── DraftStorage.swift        # Unsaved content persistence
│       └── WindowState.swift         # Window geometry & tab order
```

### Technical Notes

- Use `NSWindowRestoration` protocol for native restoration
- Store drafts in `~/Library/Application Support/QuillSwift/Drafts/`
- Consider using `NSDocument` autosave infrastructure
- Tab management may require custom `NSWindowController` subclass
- SwiftUI `WindowGroup` has limitations; may need AppKit integration

### Acceptance Criteria

- [ ] Multiple documents open in tabs
- [ ] Drag tab to create new window
- [ ] Drag tab to dock into another window
- [ ] ⌘T creates new tab, ⌘W closes tab
- [ ] Quit and relaunch restores all windows/tabs
- [ ] Unsaved edits preserved across restart
- [ ] System restart preserves working state
- [ ] No data loss on unexpected quit

### Boundary Rules

- Must integrate cleanly with DocumentGroup architecture
- Don't break standard File → Open/Save/Close behavior
- Session restore should be fast (<2s for typical session)

---

## Milestone Summary

| Phase | Milestone | Target |
|-------|-----------|--------|
| 0-1 | Basic editor + preview | MVP |
| 2-4 | Polished source editing | v0.5 |
| 5 | Live Preview Editing (Hybrid WYSIWYG) | v0.8 |
| 6-8 | Extensions & customization | v1.0 |
| 9-11 | Conformance & integration | v1.x |
| 12 | Window & Session Management | v2.0 |

---

## Decision Points

These decisions must be made before proceeding:

| Decision | Phase | Blocker For |
|----------|-------|-------------|
| Editor architecture (A/B/C) | Before Phase 2 | Phase 2-4 |
| Minimum macOS version | Before Phase 0 | All phases |
| Custom editor vs CodeMirror | Before Phase 2 | Architecture |

---

## Maintenance: Upstream Monitoring

To stay current with markdown standards and extensions, establish a process to monitor:

### Primary Sources

| Source | URL | Watch For |
|--------|-----|-----------|
| CommonMark Spec | https://spec.commonmark.org/ | New spec versions (0.31+) |
| GFM Spec | https://github.github.com/gfm/ | Updates to tables, task lists, etc. |
| swift-markdown | https://github.com/swiftlang/swift-markdown | New releases, GFM support |

### Extension Sources

| Source | URL | Watch For |
|--------|-----|-----------|
| Mermaid | https://github.com/mermaid-js/mermaid | New diagram types |
| highlight.js | https://github.com/highlightjs/highlight.js | New language support |
| Highlightr | https://github.com/raspu/Highlightr | Swift integration updates |

### Recommended Process

1. **GitHub Watch**: Star and watch key repositories for release notifications
2. **Periodic Review**: Monthly check of spec changelogs
3. **Issue Tracking**: Create QuillSwift issues for relevant upstream changes
4. **Optional**: GitHub Actions workflow to check releases weekly and create issues for review

---

*This plan will be updated as implementation progresses.*
