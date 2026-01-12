# QuillSwift Architecture

## Assumptions & TBDs

| Item | Status | Notes |
|------|--------|-------|
| macOS minimum version | **TBD** | 13+ (Ventura) for TextKit 2, or 14+ (Sonoma)? |
| Editor engine | **Researching** | NSTextView vs WKWebView vs Custom |
| Preview renderer | **Researching** | Native AttributedString vs WKWebView |
| Markdown parser | **Researching** | swift-markdown, Ink, Down, or custom |
| Syntax highlighter | **Researching** | Splash, Highlightr, or custom |

---

## Project Structure

QuillSwift uses a hybrid approach:
- **Xcode project** for the macOS app (proper app bundle with menus, focus, etc.)
- **Swift Package Manager** for standalone libraries (MarkdownRenderer, SyntaxHighlighter)

```
QuillSwift/
├── QuillSwift.xcodeproj/         # Xcode project (app target)
├── Package.swift                 # Package manifest (libraries only)
├── QuillSwiftApp/                # App source files
│   ├── QuillSwiftApp.swift       # @main entry point
│   ├── ContentView.swift         # Main view
│   ├── MarkdownDocument.swift    # Document model
│   ├── Info.plist                # App metadata
│   └── QuillSwift.entitlements   # App entitlements
├── Sources/
│   ├── MarkdownRenderer/             # Standalone library (via SPM)
│   │   └── Public/
│   │       └── MarkdownRenderer.swift # Public API
│   │
│   └── SyntaxHighlighter/            # Standalone library (via SPM)
│       └── Highlighter.swift          # Main API
│
├── Tests/
│   ├── MarkdownRendererTests/        # Tests for markdown library
│   └── SyntaxHighlighterTests/       # Tests for highlighter library
│
└── Fixtures/                         # Test fixtures for conformance testing
    ├── conformance/
    ├── renderer/
    └── security/
```

**Build Commands:**
- **App**: Open `QuillSwift.xcodeproj` in Xcode, or run `xcodebuild -scheme QuillSwift`
- **Libraries only**: `swift build` (builds MarkdownRenderer and SyntaxHighlighter)
- **Tests**: `swift test` (library tests) or run via Xcode (includes app tests)

---

## Module Responsibilities

| Module | Responsibility | May Import |
|--------|---------------|------------|
| **QuillSwift (App)** | App lifecycle, window management, menu bar | All internal modules |
| **App/** | Entry point, app delegate, window coordination | Document, Editor, Preview, Settings |
| **Document/** | Document model, dirty state, file I/O | MarkdownRenderer, Shared |
| **Editor/** | Source editing view, syntax highlighting | Document, SyntaxHighlighter, Shared |
| **Preview/** | Rendered preview display, link handling | Document, MarkdownRenderer, Shared |
| **Settings/** | Preferences UI and storage | Shared |
| **MarkdownRenderer** | Parse markdown, render to HTML/AttributedString | SyntaxHighlighter (optional) |
| **SyntaxHighlighter** | Tokenize and highlight code | (none) |

---

## Dependency Rules

```
┌─────────────────────────────────────┐
│         QuillSwift (App)            │
├─────────────────────────────────────┤
│                                     │
│  ┌──────────┐    ┌──────────┐      │
│  │  Editor  │    │ Preview  │      │
│  └────┬─────┘    └────┬─────┘      │
│       │               │            │
│       └───────┬───────┘            │
│               ▼                    │
│       ┌──────────────┐             │
│       │   Document   │             │
│       └──────┬───────┘             │
│              │                     │
└──────────────│─────────────────────┘
               │
               ▼
    ┌─────────────────────┐
    │  MarkdownRenderer   │ ◄─── Standalone library
    └──────────┬──────────┘
               │ (optional)
               ▼
    ┌─────────────────────┐
    │  SyntaxHighlighter  │ ◄─── Standalone library
    └─────────────────────┘
```

### Hard Constraints

1. **Editor CANNOT import Preview** — These are independent views
2. **Preview CANNOT import Editor** — No direct coupling
3. **MarkdownRenderer is standalone** — No app dependencies, can be used by other projects
4. **SyntaxHighlighter is standalone** — No app dependencies, can be used by other projects
5. **Document has no UI dependencies** — Pure model layer

### Enforcement

- Swift Package Manager target dependencies enforce this
- Code review catches violations
- Future: Custom build plugin or linter rule

---

## Standalone Libraries

### MarkdownRenderer

**Purpose:** Parse markdown and render to HTML or AttributedString.

**Public API:**
```swift
import MarkdownRenderer

// Parse and render to HTML
let html = MarkdownRenderer.renderHTML(
    from: markdownString,
    options: .init(
        extensions: [.gfm, .customCheckboxes],
        sanitize: true
    )
)

// Parse and render to AttributedString
let attributedString = MarkdownRenderer.renderAttributedString(
    from: markdownString,
    theme: RendererTheme.default
)

// Parse to AST for inspection
let document = MarkdownParser.parse(markdownString)
```

**Design goals:**
- CommonMark 0.30 + GFM 0.29 conformance
- Extension system for custom syntax
- Declarative configuration
- Thread-safe, no global state

### SyntaxHighlighter

**Purpose:** Tokenize and highlight source code.

**Public API:**
```swift
import SyntaxHighlighter

// Highlight code
let highlighted = SyntaxHighlighter.highlight(
    code: sourceCode,
    language: .swift,
    theme: .defaultDark
)

// Get AttributedString
let attributedString = highlighted.attributedString

// Get HTML
let html = highlighted.html
```

**Design goals:**
- Support common languages (Swift, JS, Python, Rust, Go, etc.)
- Themeable output
- Fast tokenization
- Usable as standalone library

---

## Data Flow

### Opening a File

```
User: Cmd+O
    │
    ▼
┌─────────────┐    ┌──────────────┐    ┌──────────────┐
│ WindowMgr   │───▶│ FileDialog   │───▶│ FileHandling │
└─────────────┘    └──────────────┘    └──────┬───────┘
                                              │
                                              ▼
                                       ┌──────────────┐
                                       │ MD Document  │
                                       └──────┬───────┘
                                              │
                               ┌──────────────┼──────────────┐
                               ▼              ▼              ▼
                        ┌──────────┐   ┌──────────┐   ┌──────────┐
                        │ Editor   │   │ Preview  │   │ Title    │
                        │ View     │   │ View     │   │ Bar      │
                        └──────────┘   └──────────┘   └──────────┘
```

### Editing Flow

```
User types
    │
    ▼
┌──────────────┐     ┌──────────────┐
│ Editor View  │────▶│ Document     │
└──────────────┘     │ (content,    │
                     │  dirty=true) │
                     └──────┬───────┘
                            │
                            │ (if preview visible)
                            ▼
                     ┌──────────────┐     ┌──────────────┐
                     │ MD Renderer  │────▶│ Preview View │
                     └──────────────┘     └──────────────┘
```

### Save Flow

```
User: Cmd+S
    │
    ▼
┌──────────────┐
│ Document     │
│ (path?)      │
└──────┬───────┘
       │
       ├─── path exists ──▶ Write to file ──▶ dirty=false
       │
       └─── no path ──▶ Save dialog ──▶ Write ──▶ Update path ──▶ dirty=false
```

---

## State Management

### App-Level State

Managed via `@AppStorage` and custom `AppSettings` class:

```swift
@AppStorage("appearance.theme") var theme: Theme = .system
@AppStorage("editor.fontSize") var fontSize: Int = 14
```

### Document-Level State

Each document window has its own state:

```swift
class DocumentState: ObservableObject {
    @Published var content: String
    @Published var filePath: URL?
    @Published var isDirty: Bool = false
    @Published var viewMode: ViewMode = .source
    @Published var isTrusted: Bool = false
    @Published var cursorPosition: Int = 0
}
```

### View-Level State

Local to each view:

```swift
struct EditorView: View {
    @State private var searchText: String = ""
    @State private var isSearchVisible: Bool = false
}
```

---

## Error Model

Errors are typed and user-presentable:

```swift
enum QuillSwiftError: LocalizedError {
    case fileNotFound(URL)
    case permissionDenied(URL)
    case encodingError(URL, String)
    case ioError(URL, Error)
    case parseError(String)

    var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.lastPathComponent)"
        // ...
        }
    }
}
```

---

## Concurrency Model

### Main Thread

- All UI updates
- User input handling
- Document state changes

### Background

- File I/O (async/await)
- Markdown parsing for large files
- Syntax highlighting
- Export operations

```swift
func openFile(_ url: URL) async throws -> MarkdownDocument {
    // Read file on background
    let content = try await Task.detached {
        try String(contentsOf: url, encoding: .utf8)
    }.value

    // Update UI on main
    await MainActor.run {
        document.content = content
        document.filePath = url
    }
}
```

---

## Testing Strategy

### Unit Tests

```swift
// MarkdownRendererTests
func testHeadingParsing() {
    let doc = MarkdownParser.parse("# Hello")
    XCTAssertEqual(doc.children.count, 1)
    XCTAssert(doc.children[0] is Heading)
}

// SanitizerTests
func testScriptRemoval() {
    let html = "<script>alert('xss')</script>Hello"
    let sanitized = HTMLSanitizer.sanitize(html)
    XCTAssertEqual(sanitized, "Hello")
}
```

### Integration Tests

```swift
// DocumentTests
func testOpenEditSave() async throws {
    let doc = try await DocumentManager.open(testFile)
    doc.content += "\nNew line"
    try await DocumentManager.save(doc)

    let reopened = try await DocumentManager.open(testFile)
    XCTAssert(reopened.content.contains("New line"))
}
```

### Conformance Tests

```swift
// Run CommonMark spec tests
func testCommonMarkConformance() {
    for testCase in CommonMarkSpec.testCases {
        let result = MarkdownRenderer.renderHTML(from: testCase.input)
        XCTAssertEqual(result, testCase.expected, testCase.description)
    }
}
```

### UI Tests

```swift
// XCUITest
func testOpenFile() {
    let app = XCUIApplication()
    app.launch()

    app.menuBars.menuBarItems["File"].click()
    app.menuBars.menuItems["Open..."].click()
    // ... navigate file dialog
}
```

---

## Security Considerations

1. **HTML Sanitization** — All user-provided raw HTML is sanitized
2. **URL Validation** — Only safe schemes allowed in links
3. **Sandbox** — App runs in macOS sandbox with minimal entitlements
4. **File Access** — Use security-scoped bookmarks for non-document locations
5. **Trusted Mode** — Explicit opt-in for JavaScript-based rendering (Mermaid)

---

## Performance Considerations

1. **Lazy Rendering** — Don't render preview until visible
2. **Debounced Updates** — Throttle preview updates during rapid typing
3. **Virtualized Editing** — For very large files, consider virtualized text view
4. **Background Parsing** — Parse/render on background thread for files > threshold
5. **Caching** — Cache parsed AST, invalidate on edit

---

## Revision History

| Date | Changes |
|------|---------|
| Jan 2026 | Initial architecture document |
