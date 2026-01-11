# QuillSwift Test Fixtures

This directory contains markdown test documents organized by category. These fixtures serve as our "ACID test" suite for the markdown renderer.

## Directory Structure

```
Fixtures/
├── conformance/          # Spec compliance tests
│   ├── commonmark/       # CommonMark 0.30 spec examples
│   └── gfm/              # GFM 0.29 spec examples
│
├── features/             # Feature-specific tests
│   ├── headings/         # H1-H6, ATX, Setext
│   ├── lists/            # Ordered, unordered, nested
│   ├── code-blocks/      # Fenced, indented, language hints
│   ├── tables/           # GFM tables
│   ├── checkboxes/       # Standard and extended checkboxes
│   ├── links/            # Inline, reference, autolinks
│   ├── images/           # Local, remote, data URIs
│   └── blockquotes/      # Nested quotes
│
├── edge-cases/           # Problematic inputs
│   ├── unicode/          # Emoji, CJK, RTL, combining chars
│   ├── large-files/      # Performance testing
│   └── malformed/        # Invalid/ambiguous markdown
│
├── security/             # Sanitization tests
│   └── (XSS, injection, URL schemes)
│
└── visual/               # Snapshot reference images
```

## Fixture File Conventions

### Input Files
- Named `*.input.md`
- Pure markdown content
- No special annotations

### Expected Output Files
- Named `*.expected.html`
- Expected HTML after rendering
- Normalized whitespace

### Metadata Files
- Each subdirectory has a `README.md`
- Documents what the fixtures test
- Lists related spec sections

## Adding New Fixtures

1. Create input file: `feature-name.input.md`
2. Create expected output: `feature-name.expected.html`
3. Update the directory's README.md
4. Run tests to verify

## Running Fixture Tests

```bash
# All fixture tests
swift test --filter FixtureTests

# Specific category
swift test --filter FixtureTests/testFeatureFixtures
```

## Fixture Development

As we implement features, we add fixtures that test:
1. The basic happy path
2. Edge cases and variations
3. Interactions with other features
4. Error conditions

Over time, this builds into a comprehensive validation suite.
