# QuillSwift Research: Swift Libraries & Architecture Decisions

**Last Updated:** January 2026
**Status:** Active research document

This document captures research findings on available Swift libraries and architectural approaches for QuillSwift.

---

## 1. Markdown Parsing Libraries

### Recommendation: `swift-markdown` (Apple)

| Library | Spec Support | Output | Maintenance | Recommendation |
|---------|-------------|--------|-------------|----------------|
| **swift-markdown** | CommonMark + GFM (via cmark-gfm) | AST → custom | **Active** (Swift project) | **Use this** |
| Down | CommonMark (partial GFM) | HTML, NSAttributedString | Moderate | Fallback option |
| Ink | Non-spec, pragmatic | HTML | Light | Not recommended |
| MarkdownKit | Regex-based, not spec | NSAttributedString | Modest | Not recommended |

### swift-markdown Details

- **GitHub:** https://github.com/swiftlang/swift-markdown
- **Maintained by:** Swift project (Apple)
- **Spec compliance:** Uses cmark-gfm, the reference implementation
- **Output:** Strongly-typed `Markup` AST with value semantics
- **Used in:** Swift-DocC, Apple documentation tools

**Key advantages:**
- True CommonMark 0.30 + GFM compliance (our requirement)
- Actively maintained by Swift project
- Well-documented, Swift-native API
- AST can be walked to produce any output format

**Rendering approach:**
```swift
import Markdown

let document = Document(parsing: markdownString)

// Walk AST to produce HTML or AttributedString
struct HTMLRenderer: MarkupWalker {
    var html = ""

    mutating func visitHeading(_ heading: Heading) {
        html += "<h\(heading.level)>"
        descendInto(heading)
        html += "</h\(heading.level)>"
    }
    // ... other visitors
}
```

### Decision

**Use `swift-markdown` as the parser**, with custom renderers for:
- HTML output (for WKWebView preview)
- AttributedString output (for native preview, if pursued)

We'll wrap this in our `MarkdownRenderer` library with a clean public API.

---

## 2. Syntax Highlighting Libraries

### Options Evaluated

| Library | Languages | Output | macOS Support | Maintenance |
|---------|-----------|--------|---------------|-------------|
| **Highlightr** | 180+ (highlight.js) | NSAttributedString | Yes | Stable |
| Splash | Swift only | HTML, AttributedString | Yes | Stable |
| tree-sitter | Many (native parsers) | Tokens | Complex setup | Active |

### Highlightr Details

- **GitHub:** https://github.com/raspu/Highlightr
- **Engine:** Wraps highlight.js grammars
- **Output:** NSAttributedString ready for NSTextView
- **Languages:** 180+ via highlight.js

**Advantages:**
- Proven, widely used
- Extensive language support
- Works well with Cocoa text system
- Themeable

**Considerations:**
- Uses highlight.js under the hood (JavaScript grammars compiled to data)
- May need bridging to modern AttributedString

### Splash Details

- **GitHub:** https://github.com/JohnSundell/Splash
- **Engine:** Custom Swift tokenizer
- **Output:** HTML or AttributedString
- **Languages:** Swift only

**Advantages:**
- Pure Swift, no dependencies
- Very fast for Swift code
- Clean API

**Limitations:**
- Only highlights Swift code
- Would need to combine with other highlighters for multi-language

### Decision

**Use Highlightr for initial implementation** due to its extensive language support. Consider:
- Wrapping in `SyntaxHighlighter` library with abstract interface
- Potentially swapping to tree-sitter for better performance later
- Adding Splash specifically for Swift code if Highlightr's Swift highlighting is insufficient

---

## 3. Text Editor Components

### Options Evaluated

| Component | Platform | Type | Status | Notes |
|-----------|----------|------|--------|-------|
| **NSTextView + TextKit 2** | macOS | Native | Apple SDK | Requires custom work |
| CodeEdit's editor | macOS | AppKit/SwiftUI | Active | Best open-source option |
| AuroraEditor | macOS | AppKit | Community | Similar to CodeEdit |
| Runestone | iOS | UIKit | Active | No macOS support |
| STTextView | iOS | UIKit | Moderate | No macOS support |
| WKWebView + CodeMirror | macOS | Hybrid | Proven | Known challenges |
| RichTextKit | macOS/iOS | SwiftUI | Active | Rich text, not code |

### CodeEdit Analysis

- **GitHub:** https://github.com/CodeEditApp/CodeEdit
- **What it is:** Full open-source Xcode alternative
- **Editor component:** Custom AppKit text view with:
  - Syntax highlighting
  - Line numbers
  - Minimap
  - Code folding

**Advantages:**
- Production-quality code editor in Swift
- macOS-native (AppKit with SwiftUI wrapper)
- Active development

**Considerations:**
- Not a standalone SPM package (integrated into app)
- Would need to extract/adapt the editor component
- Complex codebase to understand

### Native NSTextView + TextKit 2 Analysis

**TextKit 2 (macOS 12+):**
- Modern replacement for TextKit 1
- Better performance for large documents
- More flexible layout system

**What we'd need to build:**
1. Custom NSTextView subclass
2. Syntax highlighting integration
3. Line number gutter
4. Code block styling
5. Custom insertion point behavior
6. Markdown-specific behaviors

**Advantages:**
- Fully native, no hybrid complexity
- Best IME/internationalization support
- Integrates naturally with macOS

**Challenges:**
- Significant development effort
- TextKit 2 has learning curve
- Rich content (tables, images) is complex

### WKWebView + CodeMirror Analysis

**How it works:**
- Embed CodeMirror 6 (or Monaco, Ace) in WKWebView
- Swift↔JavaScript bridge for content sync

**Advantages:**
- CodeMirror 6 is excellent and battle-tested
- Tables, images, diagrams work naturally
- Could share code with web version

**Challenges:**
- **This caused problems in Quill (Tauri):**
  - Focus handling issues
  - Keyboard event routing
  - IME complications
  - Two ecosystems to debug
- Still hybrid complexity

### Decision: Research Further Before Committing

We have three viable paths:

**Path A: Extract from CodeEdit**
- Study CodeEdit's editor implementation
- Adapt for QuillSwift's needs
- Moderate effort, proven code

**Path B: Build on NSTextView + TextKit 2**
- Custom implementation from scratch
- Most native, most control
- Highest effort

**Path C: WKWebView + CodeMirror (revisited)**
- Accept hybrid complexity
- Fastest to features
- Known pain points

**Recommendation:** Start with **Path A** (study CodeEdit) while prototyping **Path B** (NSTextView). Make final decision after building minimal prototypes of each approach.

---

## 4. Preview Rendering

### Decision: WKWebView for Preview

For the read-only preview, **WKWebView is the pragmatic choice**:

1. **Rich content support:**
   - Tables render perfectly
   - Images display naturally
   - Mermaid diagrams work (in trusted mode)
   - Math (KaTeX) works (in trusted mode)

2. **CSS customization:**
   - User themes via CSS
   - Easy styling adjustments
   - Consistent with web standards

3. **Lower complexity than editor:**
   - Preview is read-only
   - No input handling complexity
   - No IME concerns

**Implementation:**
```swift
struct PreviewView: NSViewRepresentable {
    let html: String
    let theme: PreviewTheme

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.configuration.preferences.javaScriptEnabled = false // unless trusted
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let fullHTML = theme.wrap(html)
        webView.loadHTMLString(fullHTML, baseURL: documentDirectory)
    }
}
```

---

## 5. Document Architecture

### SwiftUI DocumentGroup Evaluation

**What DocumentGroup provides:**
- Automatic file open/save
- Recent files menu
- Window management
- Document state tracking

**Concern:** Does it create hidden metadata?

**Finding:** DocumentGroup uses the standard macOS document architecture:
- No sidecar files created
- State stored in standard UserDefaults
- Compatible with our "no hidden metadata" philosophy

**Decision:** **Use DocumentGroup** for document handling. It aligns with our goals and provides significant functionality for free.

```swift
@main
struct QuillSwiftApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { file in
            ContentView(document: file.$document)
        }
        .commands {
            // Custom menu commands
        }
    }
}
```

---

## 6. Minimum macOS Version

### Options

| Version | Name | Key Features |
|---------|------|--------------|
| macOS 13 | Ventura | TextKit 2 stable, SwiftUI 4 |
| macOS 14 | Sonoma | SwiftUI improvements, better menus |
| macOS 15 | Sequoia | Latest SwiftUI, new APIs |

### Decision: **macOS 14 (Sonoma) minimum**

**Rationale:**
- TextKit 2 is more stable
- Better SwiftUI menu support
- Still covers ~80%+ of macOS users
- Reasonable support window (2+ years old by shipping)

---

## 7. Research Log

### Swift Markdown Ecosystem (January 2026)

- **swift-markdown** is clearly the best choice for spec compliance
- Down and MarkdownKit are viable but less maintained
- Ink is too opinionated for our needs
- Native SwiftUI `Text` only handles inline markdown, not blocks

### Text Editor Landscape (January 2026)

- No drop-in SPM package for macOS code editing exists
- CodeEdit has the best open-source implementation
- Runestone is iOS-only
- Building custom on TextKit 2 is viable but significant

### Syntax Highlighting (January 2026)

- Highlightr (highlight.js wrapper) is the practical choice
- Splash is excellent but Swift-only
- tree-sitter would be better performance but complex setup

---

## 8. Open Research Questions

1. **CodeEdit editor extraction:**
   - How modular is their editor code?
   - Can it be reasonably extracted as a package?
   - What's the effort to adapt it?

2. **TextKit 2 prototype:**
   - How difficult is basic markdown editing?
   - What about tables and images?
   - Performance with large files?

3. **Highlightr + swift-markdown integration:**
   - Can code blocks be highlighted during AST walk?
   - Performance characteristics?

4. **Custom checkbox rendering:**
   - How to render extended checkbox types in HTML?
   - SVG icons vs CSS-based styling?

---

## 9. Next Steps

1. **Create minimal SwiftUI app** with DocumentGroup
2. **Integrate swift-markdown** and render to HTML
3. **Display in WKWebView** with basic CSS
4. **Prototype NSTextView** with basic markdown highlighting
5. **Evaluate CodeEdit** editor code extraction feasibility
6. **Make editor architecture decision** based on prototypes

---

*This document will be updated as research progresses.*
