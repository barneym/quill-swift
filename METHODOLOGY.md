# QuillSwift Development Methodology

**Status:** Living Document
**Last Updated:** January 2026
**Purpose:** Document Swift/macOS development practices, Xcode workflow, and tooling decisions for this project.

---

## 1. Overview

QuillSwift is a native macOS markdown editor built in Swift. This document captures our development methodology, tooling decisions, and workflow patterns. It serves as both a reference and a discussion space for evolving our approach.

### 1.1 Why Swift?

The original Quill project used Tauri (Rust + WebView + JavaScript). While architecturally sound, we encountered friction:

- **WebKit quirks** — Safari's WebView behaves differently from Chromium
- **IPC complexity** — JS↔Rust boundary required careful type management
- **Menu API issues** — macOS menu reliability required moving menu creation to Rust
- **Bundling challenges** — jsdom and similar Node.js libraries conflicted with browser context

A native Swift implementation offers:

- **First-class macOS support** — SwiftUI/AppKit are Apple's primary frameworks
- **No IPC boundary** — Single language, single runtime
- **Native menus, windows, dialogs** — Just work, no bridges
- **Sandbox and notarization** — First-class support in Xcode
- **Future iOS/iPadOS potential** — SwiftUI enables code sharing

### 1.2 First Swift Project Considerations

This is our first Swift project. We should:

1. **Lean into Apple conventions** — Follow Human Interface Guidelines, use system-provided components where possible
2. **Start simple, add complexity** — Resist the urge to over-architect before understanding Swift idioms
3. **Document as we learn** — This file captures decisions and lessons
4. **Embrace declarative patterns** — SwiftUI encourages this; carry the mindset to imperative code

---

## 2. Development Environment

### 2.1 Required Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **Xcode** | Primary IDE | Required for iOS/macOS development |
| **Swift** | Language | Ships with Xcode |
| **SwiftPM** | Package management | Xcode-integrated, also works from CLI |
| **Git** | Version control | Standard |
| **macOS Sequoia+** | Target OS | Minimum deployment target TBD |

### 2.2 Optional Tools

| Tool | Purpose | Notes |
|------|---------|-------|
| **SwiftLint** | Code style enforcement | Configurable rules |
| **SwiftFormat** | Auto-formatting | Complementary to SwiftLint |
| **Instruments** | Performance profiling | Ships with Xcode |
| **Periphery** | Dead code detection | Useful for keeping codebase clean |

### 2.3 Xcode vs. CLI Workflow

**When to use Xcode:**
- UI design and preview (SwiftUI Canvas)
- Debugging with breakpoints
- Interface Builder (if using storyboards, which we likely won't)
- Signing and notarization configuration
- Running on simulators/devices
- Core Data model editing (if used)

**When to use CLI:**
- Running tests: `swift test`
- Building: `swift build`
- Package management: `swift package` commands
- CI/CD pipelines
- Quick iteration without full IDE overhead

**Recommended workflow:**
```bash
# Open project in Xcode
open QuillSwift.xcodeproj  # or .xcworkspace if we have one

# Or build/test from command line
swift build
swift test

# Run specific tests
swift test --filter MarkdownRendererTests
```

### 2.4 Project Structure Options

**Option A: Single Xcode Project**
```
QuillSwift/
├── QuillSwift.xcodeproj
├── Sources/
│   ├── QuillSwift/           # Main app target
│   ├── MarkdownRenderer/     # Library target
│   └── SyntaxHighlighter/    # Library target
├── Tests/
└── Package.swift             # For SPM-based builds
```

**Option B: Workspace with Multiple Projects**
```
QuillSwift/
├── QuillSwift.xcworkspace
├── QuillSwift/               # Main app project
│   └── QuillSwift.xcodeproj
├── Packages/
│   ├── MarkdownRenderer/     # SPM package
│   └── SyntaxHighlighter/    # SPM package
```

**Recommendation:** Start with Option A (simpler), extract to Option B when libraries stabilize.

---

## 3. Architecture Approach

### 3.1 SwiftUI-First

We will use SwiftUI as the primary UI framework, dropping to AppKit when necessary.

**Use SwiftUI for:**
- Window chrome and layout
- Menus and toolbar
- Settings UI
- File dialogs (via SwiftUI's fileImporter/fileExporter)
- Simple views and controls

**Use AppKit (via NSViewRepresentable) for:**
- Complex text editing (NSTextView)
- Custom drawing if needed
- Any system component without SwiftUI equivalent

### 3.2 Document-Based App Architecture

macOS has a document-based app pattern built into AppKit and SwiftUI. We should evaluate:

**SwiftUI Document App:**
```swift
@main
struct QuillSwiftApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
```

**Pros:**
- Free file handling (open, save, save as, recent files)
- Native document dirty tracking
- Automatic window management

**Cons:**
- Less control over window behavior
- May conflict with our "file-first, no metadata" philosophy if it creates hidden state

**Decision:** Research needed. Document if this fits our "no hidden metadata" requirement.

### 3.3 State Management

**SwiftUI provides:**
- `@State` — Local view state
- `@StateObject` — Observable object ownership
- `@ObservedObject` — Observable object reference
- `@EnvironmentObject` — Dependency injection
- `@Binding` — Two-way data flow

**Our approach:**
- Keep state close to where it's used
- Prefer `@StateObject` for document-level state
- Use environment for app-wide settings
- Avoid global singletons

---

## 4. Editor Engine Decision

This is the most critical architectural decision. We're evaluating three approaches:

### 4.1 Option A: NSTextView + TextKit 2

**Description:** Use Apple's native text system with custom extensions for markdown.

**Pros:**
- Fully native, no hybrid complexity
- TextKit 2 (macOS 12+) is modern and powerful
- Good IME, accessibility, and internationalization support
- Integrates naturally with AppKit/SwiftUI

**Cons:**
- Significant custom work for:
  - Syntax highlighting
  - Line numbers
  - Code block rendering
  - Table rendering (very challenging)
  - Image embedding
- May be limiting for rich content (Mermaid diagrams, math)
- Steeper learning curve if unfamiliar with TextKit

**Effort estimate:** High (building markdown-aware text editor from scratch)

**Best if:** We want maximum native feel and are willing to invest in custom work.

### 4.2 Option B: WKWebView + CodeMirror/Existing JS Editor

**Description:** Embed a web-based editor in a native WebView, similar to Tauri approach.

**Pros:**
- CodeMirror 6 is mature and feature-complete
- Faster time to initial functionality
- Tables, images, diagrams render well in HTML
- Portable to future web/mobile versions

**Cons:**
- **This is what caused problems in Quill** — the hybrid approach
- Two-way communication (Swift↔JS) adds complexity
- Focus, keyboard, and IME handling can be tricky
- Less "native" feel
- Debugging spans two ecosystems

**Effort estimate:** Medium (integration work), but with known friction points

**Best if:** We prioritize feature completeness over native purity.

### 4.3 Option C: Custom Editor Component

**Description:** Build a markdown-aware text editor from the ground up.

**Pros:**
- Full control over every aspect
- Can be designed specifically for markdown semantics
- Could become a standalone reusable library
- No compromises or workarounds

**Cons:**
- **Largest scope by far** — essentially building a text editor
- Text editing is notoriously complex (IME, bidi, selection, etc.)
- Would require extensive testing including visual regression
- Could easily become a multi-month or multi-year effort

**Effort estimate:** Very high (separate project within the project)

**Best if:** We're committed to long-term investment and want to contribute a significant open-source component.

### 4.4 Research Questions

Before deciding, we need to answer:

1. **What do other Swift markdown editors use?**
   - MacDown, Nota, Bear, iA Writer (investigate their approaches)
2. **What's the current state of TextKit 2?**
   - Is it mature enough for complex use cases?
3. **Are there existing Swift text editor components?**
   - Runestone (syntax highlighting editor for iOS)
   - STTextView (macOS alternative to NSTextView)
4. **What's the minimum viable editor for P0?**
   - Can we start simpler and add complexity?

---

## 5. Preview Rendering Decision

Closely tied to the editor decision.

### 5.1 Option A: Native AttributedString

**Description:** Parse markdown to an NSAttributedString (or AttributedString) and render in a native view.

**Pros:**
- Fully native, fast
- Good text selection and accessibility
- No web view overhead

**Cons:**
- Limited support for complex elements:
  - Tables (possible but custom)
  - Code blocks with syntax highlighting (custom work)
  - Images (inline in AttributedString is tricky)
  - Diagrams (very challenging)
- May need custom drawing for some elements

### 5.2 Option B: WKWebView for Preview

**Description:** Render markdown to HTML and display in a WebView (like Tauri version).

**Pros:**
- Full HTML/CSS rendering capability
- Tables, images, diagrams work naturally
- Can share styling with any future web version
- Syntax highlighting libraries available (Prism, Highlight.js)

**Cons:**
- Hybrid architecture
- Need to bridge scroll position, events
- Performance overhead for simple content

### 5.3 Option C: Hybrid Approach

**Description:** Native rendering for simple elements, WKWebView for complex ones.

**Pros:**
- Best of both worlds
- Native feel for common content
- Full capability for edge cases

**Cons:**
- Two rendering paths to maintain
- Complex switching logic
- Potential visual inconsistencies

### 5.4 Recommendation

Given the richness requirements (tables, images, Mermaid diagrams, math):

**WKWebView for preview is likely pragmatic**, even if we pursue native for the editor. The preview is read-only, so hybrid complexity is lower.

---

## 6. Dependency Management

### 6.1 Swift Package Manager (SPM)

SPM is the standard for Swift. We'll use it for:
- External dependencies
- Internal library modules
- Plugin-based build tools (SwiftLint, etc.)

**Package.swift structure:**
```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuillSwift",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "QuillSwift", targets: ["QuillSwift"]),
        .library(name: "MarkdownRenderer", targets: ["MarkdownRenderer"]),
    ],
    dependencies: [
        // External dependencies here
    ],
    targets: [
        .executableTarget(name: "QuillSwift", dependencies: ["MarkdownRenderer"]),
        .target(name: "MarkdownRenderer"),
        .testTarget(name: "MarkdownRendererTests", dependencies: ["MarkdownRenderer"]),
    ]
)
```

### 6.2 Dependency Policy

Following Quill's philosophy:
- **Minimize dependencies** — Each dependency is a maintenance burden
- **Prefer Apple frameworks** — They're "free" and well-maintained
- **Document justification** — Every dependency needs a reason
- **Audit regularly** — Remove unused dependencies

---

## 7. Testing Strategy

### 7.1 Test Types

| Type | Framework | Purpose |
|------|-----------|---------|
| **Unit** | XCTest | Pure logic testing |
| **Integration** | XCTest | Component interaction |
| **UI** | XCUITest | End-to-end user flows |
| **Snapshot** | swift-snapshot-testing | Visual regression |
| **Conformance** | Custom harness | Markdown spec compliance |

### 7.2 Running Tests

```bash
# All tests via CLI
swift test

# Specific test class
swift test --filter MarkdownRendererTests

# With verbose output
swift test -v

# In Xcode: Cmd+U
```

### 7.3 CI Configuration

GitHub Actions with macOS runner:
```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - name: Build
        run: swift build
      - name: Test
        run: swift test
```

---

## 8. Code Style

### 8.1 SwiftLint Configuration

Create `.swiftlint.yml`:
```yaml
disabled_rules:
  - trailing_whitespace
  - line_length  # We'll set our own

opt_in_rules:
  - empty_count
  - explicit_init
  - first_where
  - sorted_imports

line_length:
  warning: 120
  error: 150

identifier_name:
  min_length: 2
```

### 8.2 Naming Conventions

Follow Swift API Design Guidelines:
- Types and protocols: `UpperCamelCase`
- Everything else: `lowerCamelCase`
- Acronyms: Treat as word (`htmlParser` not `HTMLParser`, unless at start: `HTMLParser`)
- Boolean properties: Read as assertions (`isEmpty`, `hasContent`)

---

## 9. Open Questions

This section tracks questions we're actively investigating.

| Question | Status | Notes |
|----------|--------|-------|
| NSTextView vs WKWebView for editor | Researching | See §4 |
| Document-based app architecture fit | Researching | Does it create hidden state? |
| Minimum macOS version | TBD | 13 (Ventura)? 14 (Sonoma)? |
| Existing Swift markdown libraries | Researching | See §10 |
| Existing Swift text editor components | Researching | Runestone, STTextView |

---

## 10. Research Log

### 10.1 Swift Markdown Libraries

*To be populated with research findings*

**Known options:**
- **swift-markdown** (Apple) — CommonMark parser, used in DocC
- **Ink** (Sundell) — Swift markdown parser
- **Down** — Swift wrapper around cmark
- **MarkdownKit** — Pure Swift, CommonMark

### 10.2 Swift Syntax Highlighting

*To be populated with research findings*

**Known options:**
- **Splash** (Sundell) — Swift-focused syntax highlighter
- **Sourceful** — Editor with syntax highlighting
- **Runestone** (iOS) — Syntax highlighting editor component
- **Highlightr** — Wrapper around highlight.js

### 10.3 Swift Text Editor Components

*To be populated with research findings*

**Known options:**
- **Runestone** — iOS syntax highlighting editor
- **STTextView** — macOS NSTextView alternative
- **CodeEditorView** (CodeEdit project) — macOS code editor

---

## 11. Revision History

| Date | Changes |
|------|---------|
| Jan 2026 | Initial document creation |

---

*This is a living document. Update it as we learn and as decisions are made.*
