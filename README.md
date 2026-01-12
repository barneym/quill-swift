# QuillSwift

A native macOS markdown editor built in Swift. "TextEdit for Markdown" - fast, minimal, and focused on the writing experience.

## Status

**Phase 1: Markdown Rendering** - Preview displays rendered markdown with syntax themes.

## Features (Planned)

- Native macOS app with SwiftUI
- Source editing with syntax highlighting
- Live preview rendering
- Document-based architecture (open, save, multiple windows)
- GitHub Flavored Markdown support
- Custom checkbox types (Obsidian Anypino-style)
- CSS/theme customization for advanced users

## Requirements

- macOS 13+ (Ventura)
- Xcode 15+ (Swift 5.9+)

## Quick Start

```bash
# Clone
git clone https://github.com/barneym/quill-swift.git
cd quill-swift

# Open in Xcode
open QuillSwift.xcodeproj

# Or build from command line
xcodebuild -scheme QuillSwift -configuration Debug build

# Run library tests
swift test
```

## Project Structure

QuillSwift uses a hybrid approach:
- **Xcode project** for the macOS app (proper app bundle)
- **Swift Package Manager** for standalone libraries

```
QuillSwift/
├── QuillSwift.xcodeproj/    # Xcode project (app)
├── Package.swift            # SPM manifest (libraries)
├── QuillSwiftApp/           # App source files
├── Sources/
│   ├── MarkdownRenderer/    # Standalone markdown library
│   └── SyntaxHighlighter/   # Standalone highlighter library
├── Tests/
└── Fixtures/                # Test fixtures
```

## Standalone Libraries

### MarkdownRenderer

Parse and render markdown to HTML or AttributedString.

```swift
import MarkdownRenderer

let html = MarkdownRenderer.renderHTML(from: "# Hello World")
```

### SyntaxHighlighter

Tokenize and highlight source code.

```swift
import SyntaxHighlighter

let result = SyntaxHighlighter.highlight(code: "let x = 5", language: .swift)
let html = result.html
```

## Documentation

- [Design Document](Design.md) - Full design specification
- [Architecture](docs/ARCHITECTURE.md) - Module structure and dependencies
- [Implementation Plan](docs/IMPLEMENTATION_PLAN.md) - Phased execution plan
- [Testing Strategy](docs/TESTING.md) - Testing philosophy and approach
- [Contributing](CONTRIBUTING.md) - Contribution guidelines

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and guidelines.

## License

MIT License - see LICENSE for details.
