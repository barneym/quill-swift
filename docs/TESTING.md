# QuillSwift Testing Strategy

**Status:** Living Document
**Last Updated:** January 2026
**Purpose:** Define testing philosophy, infrastructure, and practices to catch issues early.

---

## 1. Testing Philosophy

### 1.1 Core Principles

1. **Test early, test often** — Testing is not an afterthought; it's part of every phase
2. **Prototype with tests** — Even exploratory prototypes should have basic test coverage
3. **UI testing is not optional** — Presentation and interaction bugs are just as critical as logic bugs
4. **Build toward conformance** — Accumulate test fixtures that become our "ACID test" for markdown
5. **Catch regressions immediately** — CI must block on test failures

### 1.2 Lessons from Quill

The original Quill project had 48 tests but still encountered UI/integration issues:
- Blank window bugs (environment-specific)
- Menu reliability issues (platform-specific)
- Rendering inconsistencies (WebKit vs expectations)

**Key insight:** Unit tests alone are insufficient. We need:
- Integration tests that verify components work together
- UI tests that verify what the user actually sees
- Visual regression tests that catch presentation changes
- Platform-specific tests when using native APIs

---

## 2. Test Types & Frameworks

### 2.1 Test Pyramid

```
                    ┌─────────────────┐
                    │   E2E / UI      │  ← Fewer, slower, high confidence
                    │   (XCUITest)    │
                    ├─────────────────┤
                    │  Integration    │  ← Component interactions
                    │   (XCTest)      │
                    ├─────────────────┤
                    │     Unit        │  ← Many, fast, focused
                    │   (XCTest)      │
                    └─────────────────┘
        + Snapshot tests (swift-snapshot-testing)
        + Conformance tests (CommonMark/GFM spec)
        + Fixture-based tests (our "ACID" suite)
```

### 2.2 Framework Selection

| Test Type | Framework | Purpose |
|-----------|-----------|---------|
| **Unit** | XCTest | Pure logic, isolated components |
| **Integration** | XCTest | Component interaction, data flow |
| **UI** | XCUITest | User interactions, accessibility |
| **Snapshot** | swift-snapshot-testing | Visual regression |
| **Conformance** | Custom harness | Markdown spec compliance |
| **Fixture** | Custom harness | Feature-specific validation |

### 2.3 Test Locations

```
QuillSwift/
├── Tests/
│   ├── QuillSwiftTests/           # App-level tests
│   │   ├── Unit/
│   │   ├── Integration/
│   │   └── Fixtures/
│   │
│   ├── QuillSwiftUITests/         # XCUITest suite
│   │   ├── FileOperationsTests.swift
│   │   ├── EditorTests.swift
│   │   ├── PreviewTests.swift
│   │   └── AccessibilityTests.swift
│   │
│   ├── MarkdownRendererTests/
│   │   ├── ParserTests.swift
│   │   ├── RendererTests.swift
│   │   ├── SanitizerTests.swift
│   │   └── Conformance/
│   │       ├── CommonMarkTests.swift
│   │       └── GFMTests.swift
│   │
│   └── SyntaxHighlighterTests/
│
├── Fixtures/                       # Test input documents
│   ├── conformance/                # Spec test cases
│   ├── features/                   # Feature-specific tests
│   ├── edge-cases/                 # Problematic inputs
│   ├── security/                   # Sanitization tests
│   └── visual/                     # Snapshot reference files
```

---

## 3. Fixture-Based Testing ("ACID Tests")

### 3.1 Concept

Like the Web Standards Project's ACID tests for browsers, we build a library of markdown documents that test specific features. Each fixture:
- Tests one specific feature or edge case
- Has defined expected output
- Can be visually inspected
- Accumulates over time into a comprehensive test suite

### 3.2 Fixture Structure

Each fixture follows a consistent structure:

```
Fixtures/
├── features/
│   ├── headings/
│   │   ├── README.md               # What this fixture tests
│   │   ├── basic.input.md          # Input document
│   │   ├── basic.expected.html     # Expected HTML output
│   │   ├── nested.input.md
│   │   ├── nested.expected.html
│   │   └── ...
│   │
│   ├── lists/
│   │   ├── README.md
│   │   ├── unordered.input.md
│   │   ├── unordered.expected.html
│   │   ├── ordered.input.md
│   │   ├── nested-mixed.input.md
│   │   └── ...
│   │
│   ├── code-blocks/
│   ├── tables/
│   ├── checkboxes/
│   │   ├── standard.input.md
│   │   ├── extended.input.md       # Custom checkbox types
│   │   └── ...
│   │
│   ├── links/
│   ├── images/
│   └── ...
│
├── edge-cases/
│   ├── unicode/
│   ├── large-files/
│   ├── malformed/
│   └── ...
│
└── security/
    ├── xss-basic.input.md
    ├── script-injection.input.md
    ├── url-schemes.input.md
    └── ...
```

### 3.3 Fixture README Template

Each feature directory has a README explaining what it tests:

```markdown
# Headings Fixtures

## Purpose
Test heading parsing and rendering (H1-H6).

## Features Tested
- [ ] H1 through H6 levels
- [ ] ATX-style headings (# prefix)
- [ ] Setext-style headings (underlines)
- [ ] Heading with inline formatting
- [ ] Heading anchor generation

## Edge Cases
- Empty headings
- Headings with only whitespace
- Deeply nested heading levels
- Headings in blockquotes

## Related Specs
- CommonMark 4.2 (ATX headings)
- CommonMark 4.3 (Setext headings)
```

### 3.4 Running Fixture Tests

```swift
// MarkdownRendererTests/FixtureTests.swift

import XCTest
@testable import MarkdownRenderer

final class FixtureTests: XCTestCase {

    func testAllFeatureFixtures() throws {
        let fixturesURL = Bundle.module.url(forResource: "Fixtures/features", withExtension: nil)!
        let fixtures = try FixtureLoader.loadAll(from: fixturesURL)

        for fixture in fixtures {
            let html = MarkdownRenderer.renderHTML(from: fixture.input)
            XCTAssertEqual(
                html.normalized,
                fixture.expectedHTML.normalized,
                "Fixture failed: \(fixture.name)"
            )
        }
    }

    func testSecurityFixtures() throws {
        let fixturesURL = Bundle.module.url(forResource: "Fixtures/security", withExtension: nil)!
        let fixtures = try FixtureLoader.loadAll(from: fixturesURL)

        for fixture in fixtures {
            let html = MarkdownRenderer.renderHTML(from: fixture.input, sanitize: true)

            // Security fixtures define what must NOT appear
            for forbidden in fixture.forbiddenPatterns {
                XCTAssertFalse(
                    html.contains(forbidden),
                    "Security violation in \(fixture.name): found '\(forbidden)'"
                )
            }
        }
    }
}
```

---

## 4. UI Testing Strategy

### 4.1 What to Test

| Area | Tests |
|------|-------|
| **File Operations** | New, Open, Save, Save As, Close |
| **Editing** | Type, Select, Cut/Copy/Paste, Undo/Redo |
| **Navigation** | Toggle source/preview, scroll, find |
| **Menus** | All menu items trigger correct actions |
| **Keyboard** | All shortcuts work correctly |
| **Accessibility** | VoiceOver labels, focus order |

### 4.2 XCUITest Examples

```swift
// QuillSwiftUITests/FileOperationsTests.swift

import XCTest

final class FileOperationsTests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launch()
    }

    func testNewDocument() {
        // Cmd+N creates new window
        app.typeKey("n", modifierFlags: .command)

        // New window should appear
        XCTAssertEqual(app.windows.count, 2)

        // Window title should be "Untitled"
        let newWindow = app.windows.element(boundBy: 1)
        XCTAssertTrue(newWindow.title.contains("Untitled"))
    }

    func testOpenFile() throws {
        // Prepare test file
        let testFile = try createTempMarkdownFile("# Test\n\nHello world")

        // Open via menu
        app.menuBars.menuBarItems["File"].click()
        app.menuBars.menuItems["Open..."].click()

        // Navigate to file (simplified - real test would handle dialog)
        // ...

        // Verify content loaded
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.value as? String ?? "" contains: "# Test")
    }

    func testTogglePreview() {
        // Create document with content
        let editor = app.textViews.firstMatch
        editor.typeText("# Hello\n\nWorld")

        // Toggle to preview (Cmd+E)
        app.typeKey("e", modifierFlags: .command)

        // Verify preview is visible
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.exists)

        // Verify heading is rendered
        XCTAssertTrue(webView.staticTexts["Hello"].exists)
    }
}
```

### 4.3 Accessibility Testing

```swift
// QuillSwiftUITests/AccessibilityTests.swift

final class AccessibilityTests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        continueAfterFailure = false
        app.launch()
    }

    func testEditorAccessibility() {
        let editor = app.textViews.firstMatch

        // Editor should be accessible
        XCTAssertTrue(editor.isHittable)

        // Should have accessibility label
        XCTAssertFalse(editor.label.isEmpty)

        // Should support keyboard navigation
        editor.typeKey(.tab, modifierFlags: [])
        // Verify focus moved appropriately
    }

    func testMenuAccessibility() {
        // All menu items should be accessible via keyboard
        app.typeKey("o", modifierFlags: .command)  // Open
        // Verify dialog appeared

        app.typeKey(.escape, modifierFlags: [])  // Cancel

        app.typeKey("e", modifierFlags: .command)  // Toggle preview
        // Verify mode changed
    }
}
```

---

## 5. Snapshot Testing

### 5.1 Purpose

Catch unintended visual changes in:
- Preview rendering
- Syntax highlighting
- Theme application
- UI layout

### 5.2 Setup

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.15.0"),
]

// Tests
import SnapshotTesting

final class PreviewSnapshotTests: XCTestCase {

    func testBasicRendering() {
        let markdown = """
        # Hello World

        This is a paragraph with **bold** and *italic*.

        - List item 1
        - List item 2
        """

        let html = MarkdownRenderer.renderHTML(from: markdown)
        let view = PreviewView(html: html, theme: .defaultLight)

        assertSnapshot(matching: view, as: .image(size: CGSize(width: 600, height: 400)))
    }

    func testCodeBlockHighlighting() {
        let markdown = """
        ```swift
        func hello() {
            print("Hello, World!")
        }
        ```
        """

        let html = MarkdownRenderer.renderHTML(from: markdown)
        let view = PreviewView(html: html, theme: .defaultDark)

        assertSnapshot(matching: view, as: .image(size: CGSize(width: 600, height: 200)))
    }
}
```

### 5.3 Snapshot Review Process

1. New snapshots are created on first run
2. Changes to rendering will fail tests
3. Review diffs carefully before updating
4. Commit snapshots to version control

---

## 6. Conformance Testing

### 6.1 CommonMark Spec Tests

```swift
// MarkdownRendererTests/Conformance/CommonMarkTests.swift

import XCTest
@testable import MarkdownRenderer

final class CommonMarkTests: XCTestCase {

    func testAllCommonMarkExamples() throws {
        let specTests = try CommonMarkSpec.loadExamples()

        var failures: [String] = []

        for test in specTests {
            let result = MarkdownRenderer.renderHTML(from: test.markdown)
            let expected = test.html

            if result.normalized != expected.normalized {
                failures.append("""
                Example \(test.example):
                Input: \(test.markdown)
                Expected: \(expected)
                Got: \(result)
                """)
            }
        }

        XCTAssertTrue(failures.isEmpty, "Failed examples:\n\(failures.joined(separator: "\n\n"))")
    }
}
```

### 6.2 GFM Spec Tests

Similar structure for GFM-specific tests (tables, task lists, strikethrough, autolinks).

### 6.3 Known Deviations

```swift
// Deviations are tracked and explicitly allowed
struct ConformanceDeviation {
    let spec: String           // "CommonMark" or "GFM"
    let example: Int           // Example number
    let reason: String         // Why we deviate
    let approved: Date         // When approved
    let approvedBy: String     // Who approved
}

// In CONFORMANCE.md and loaded at test time
let allowedDeviations: [ConformanceDeviation] = [
    // Currently empty - goal is to keep it empty
]
```

---

## 7. Testing During Prototyping

### 7.1 Prototype Test Requirements

Even exploratory prototypes should have:

1. **Smoke tests** — Does it launch? Does it not crash?
2. **Basic functionality tests** — Does the core behavior work?
3. **Edge case tests** — What happens with unusual input?

### 7.2 Prototype Test Template

```swift
// When prototyping a new component, start with:

final class PrototypeTests: XCTestCase {

    // 1. Smoke test
    func testComponentInitializes() {
        let component = MyComponent()
        XCTAssertNotNil(component)
    }

    // 2. Happy path
    func testBasicOperation() {
        let component = MyComponent()
        let result = component.process("input")
        XCTAssertEqual(result, "expected")
    }

    // 3. Edge cases
    func testEmptyInput() {
        let component = MyComponent()
        let result = component.process("")
        // Define expected behavior
    }

    func testLargeInput() {
        let component = MyComponent()
        let largeInput = String(repeating: "x", count: 100_000)
        // Should not crash, should complete in reasonable time
        let result = component.process(largeInput)
        XCTAssertNotNil(result)
    }
}
```

---

## 8. CI Integration

### 8.1 GitHub Actions Workflow

```yaml
# .github/workflows/test.yml
name: Tests

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test:
    runs-on: macos-14  # Sonoma for latest Xcode

    steps:
      - uses: actions/checkout@v4

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.2.app

      - name: Build
        run: swift build

      - name: Run Unit Tests
        run: swift test

      - name: Run UI Tests
        run: xcodebuild test \
          -scheme QuillSwift \
          -destination 'platform=macOS' \
          -testPlan UITests

      - name: Upload Test Results
        if: failure()
        uses: actions/upload-artifact@v4
        with:
          name: test-results
          path: .build/test-results/
```

### 8.2 Test Failure Policy

- All tests must pass before merge
- Flaky tests are bugs to be fixed, not skipped
- New features require new tests
- Bug fixes require regression tests

---

## 9. Performance Testing

### 9.1 Metrics to Track

| Metric | Target | How to Test |
|--------|--------|-------------|
| App launch | < 500ms | XCTest measure block |
| File open (100KB) | < 50ms | XCTest measure block |
| Typing latency | < 16ms | Custom instrumentation |
| Preview render (10KB) | < 100ms | XCTest measure block |

### 9.2 Performance Test Example

```swift
func testFileOpenPerformance() throws {
    let largeFile = try createTempMarkdownFile(
        String(repeating: "# Heading\n\nParagraph.\n\n", count: 1000)
    )

    measure {
        let document = try! MarkdownDocument(fileURL: largeFile)
        XCTAssertFalse(document.content.isEmpty)
    }
}
```

---

## 10. Test Maintenance

### 10.1 Regular Review

- Review test coverage monthly
- Remove obsolete tests
- Update fixtures when spec changes
- Keep snapshot references current

### 10.2 Test Hygiene

- Tests should be fast (< 1 second each for unit tests)
- Tests should be deterministic (no flakiness)
- Tests should be independent (no order dependencies)
- Tests should be readable (clear intent)

---

*This document will be updated as testing practices evolve.*
