# Contributing to QuillSwift

## Overview

QuillSwift is a native macOS markdown editor built in Swift. This document outlines the contribution process, coding standards, and task management approach.

---

## Development Setup

### Prerequisites

- macOS 13+ (Ventura) or later
- Xcode 15+ (with Swift 5.9+)
- Git

### Getting Started

```bash
# Clone the repository
git clone https://github.com/barneym/quill-swift.git
cd quill-swift

# Open in Xcode
open Package.swift
# Or: xed .

# Build from command line
swift build

# Run tests
swift test
```

---

## Definition of Done

A contribution is complete when:

1. **Compiles** — `swift build` succeeds with no errors
2. **Tests pass** — `swift test` passes
3. **Lint passes** — SwiftLint passes (when configured)
4. **Documentation** — Public APIs are documented
5. **Demo script runs** — Manual verification steps pass

---

## Task Template

When creating tickets for implementation work:

```markdown
## Objective
[What this task accomplishes]

## Phase
[P0 | P1 | P2 | P3 | P4]

## Constraints
- [What this task must NOT do]
- [Boundaries and limitations]

## Files to Touch
- `Sources/QuillSwift/...`
- `Tests/...`

## Acceptance Criteria
- [ ] [Specific, testable requirement]
- [ ] [Another requirement]

## Demo Script
1. [Step to verify the feature works]
2. [Another step]
```

---

## Coding Standards

### Swift Style

Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/).

Key points:
- Use descriptive names that read naturally
- Prefer clarity over brevity
- Use `camelCase` for functions, properties, variables
- Use `UpperCamelCase` for types and protocols
- Boolean properties read as assertions: `isEmpty`, `hasContent`

### File Organization

```swift
// 1. Import statements (sorted alphabetically)
import Foundation
import SwiftUI

// 2. Type declaration
struct MyView: View {
    // MARK: - Properties
    // (constants, then variables, then computed)

    // MARK: - Initialization

    // MARK: - Body (for SwiftUI views)

    // MARK: - Methods
    // (public, then internal, then private)
}

// 3. Extensions (in same file if closely related)
extension MyView {
    // ...
}
```

### Comments

- Document public APIs with `///` doc comments
- Use `// MARK: -` for section organization
- Avoid redundant comments that repeat the code
- TODOs must reference an issue: `// TODO(#123): Description`

### Error Handling

```swift
// Prefer throwing functions over optionals for failures
func loadDocument(from url: URL) throws -> MarkdownDocument {
    guard FileManager.default.fileExists(atPath: url.path) else {
        throw QuillSwiftError.fileNotFound(url)
    }
    // ...
}

// Use Result for async callbacks if not using async/await
```

---

## Commit Guidelines

### Format

```
<type>: <short description>

[Optional longer description]

[Optional: Signed-off-by / Co-Authored-By]
```

### Types

| Type | Description |
|------|-------------|
| `feat` | New feature |
| `fix` | Bug fix |
| `docs` | Documentation only |
| `test` | Adding/updating tests |
| `refactor` | Code change that neither fixes a bug nor adds a feature |
| `chore` | Maintenance (dependencies, CI, etc.) |
| `ci` | CI/CD configuration |

### Examples

```
feat: Add markdown heading parsing

Implements H1-H6 heading detection with proper nesting.

Co-Authored-By: Claude Opus 4.5 <noreply@anthropic.com>
```

```
fix: Handle empty files without crash

Files with no content now display empty editor instead of crashing.
Fixes #42.
```

---

## Pull Request Process

1. **One PR per ticket** — Don't combine unrelated changes
2. **Clear description** — Explain what and why
3. **Link issues** — Reference the issue being addressed
4. **Small diffs** — Keep changes focused and reviewable
5. **Tests included** — Add tests for new functionality
6. **Documentation updated** — Update docs if behavior changes

### PR Template

```markdown
## Summary
[Brief description of changes]

## Related Issue
Closes #XX

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Documentation
- [ ] Refactoring

## Testing
- [ ] Unit tests added/updated
- [ ] Manual testing performed

## Checklist
- [ ] Code compiles without errors
- [ ] Tests pass
- [ ] Documentation updated (if needed)
```

---

## AI-Specific Guidelines

This project is designed for AI-assisted development. When contributing via AI tools:

### Do

- Follow the task template exactly
- Keep diffs minimal and focused
- Add tests for new functionality
- Use existing patterns from the codebase
- Stop and escalate when hitting boundaries

### Don't

- Introduce new dependencies without approval
- Refactor unrelated code
- Change architecture without discussion
- Create new systems to "fix" design issues
- Make changes outside the ticket scope

### Dependency Policy

Adding a new dependency requires:
1. Explicit justification in the PR description
2. Evaluation of maintenance status
3. Review of license compatibility
4. Consideration of alternatives

---

## Testing

### Running Tests

```bash
# All tests
swift test

# Specific test class
swift test --filter MarkdownParserTests

# With verbose output
swift test --verbose
```

### Writing Tests

```swift
import XCTest
@testable import MarkdownRenderer

final class MarkdownParserTests: XCTestCase {
    func testParsesHeading() {
        // Given
        let markdown = "# Hello World"

        // When
        let document = MarkdownParser.parse(markdown)

        // Then
        XCTAssertEqual(document.children.count, 1)
        let heading = document.children[0] as? Heading
        XCTAssertNotNil(heading)
        XCTAssertEqual(heading?.level, 1)
    }
}
```

### Test Organization

```
Tests/
├── MarkdownRendererTests/
│   ├── ParserTests.swift           # Unit tests for parser
│   ├── RendererTests.swift         # Unit tests for renderer
│   ├── SanitizerTests.swift        # Security tests
│   └── Conformance/
│       ├── CommonMarkTests.swift   # Spec conformance
│       └── GFMTests.swift          # GFM conformance
├── SyntaxHighlighterTests/
└── QuillSwiftTests/
    ├── DocumentTests.swift
    └── IntegrationTests.swift
```

---

## Architecture Boundaries

See `docs/ARCHITECTURE.md` for detailed module responsibilities.

Key rules:
- `MarkdownRenderer` is a standalone library — no app dependencies
- `SyntaxHighlighter` is a standalone library — no app dependencies
- `Editor` and `Preview` are independent views — no direct imports
- `Document` is a pure model — no UI dependencies

---

## License

By contributing to QuillSwift, you agree that your contributions will be licensed under the MIT License.

### DCO (Developer Certificate of Origin)

All contributions require DCO sign-off:

```
Signed-off-by: Your Name <your.email@example.com>
```

This certifies that you have the right to submit the contribution under the project's license.

---

## Questions?

If you have questions about contributing:
1. Check existing issues for similar questions
2. Open a new issue with the `question` label
3. Reach out to maintainers

Thank you for contributing to QuillSwift!
