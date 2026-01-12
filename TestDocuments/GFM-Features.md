# GitHub Flavored Markdown Features

This document demonstrates GFM extensions supported by QuillSwift.

## Tables

### Simple Table

| Feature | Status | Priority |
|---------|--------|----------|
| Tables | Done | High |
| Task Lists | Done | High |
| Strikethrough | Done | Medium |
| Autolinks | Done | Low |

### Alignment

| Left | Center | Right |
|:-----|:------:|------:|
| L1 | C1 | R1 |
| Left aligned | Centered | Right aligned |
| Text | Text | 123.45 |

### Complex Table

| Category | Item | Price | Quantity | Total |
|:---------|:-----|------:|:--------:|------:|
| Fruit | Apple | $1.50 | 4 | $6.00 |
| Fruit | Banana | $0.75 | 6 | $4.50 |
| Vegetable | Carrot | $2.00 | 3 | $6.00 |
| Vegetable | Broccoli | $3.25 | 2 | $6.50 |
| | | | **Total** | **$23.00** |

## Strikethrough

This is ~~deleted text~~ with strikethrough.

You can also use ~~multiple words~~ in strikethrough.

~~Entire paragraphs can be struck through if needed, though this is less common in practice.~~

## Autolinks

### URLs
- https://github.com
- https://www.apple.com/macos
- ftp://files.example.com/document.pdf

### Email
- user@example.com
- support@quillswift.app

### Extended Autolinks (GFM)
- www.example.com (without protocol)

## Task Lists (Standard)

- [x] Create markdown parser
- [x] Implement GFM extensions
- [ ] Add syntax highlighting
- [ ] Write documentation

## Fenced Code Blocks with Language

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        Text("Hello, QuillSwift!")
            .font(.largeTitle)
            .foregroundColor(.primary)
    }
}
```

```python
def render_markdown(text: str) -> str:
    """Convert markdown to HTML."""
    import markdown
    return markdown.markdown(text, extensions=['tables', 'fenced_code'])
```

```javascript
// JavaScript example
const renderPreview = async (markdown) => {
  const html = await marked.parse(markdown);
  document.getElementById('preview').innerHTML = html;
};
```

```json
{
  "name": "QuillSwift",
  "version": "1.0.0",
  "features": ["markdown", "preview", "export"]
}
```

```bash
# Shell commands
git add .
git commit -m "Add GFM support"
git push origin main
```

## Footnotes

Here's a sentence with a footnote[^1].

And another one[^note].

[^1]: This is the first footnote.
[^note]: This is a named footnote with more content.

## Definition Lists

Term 1
: Definition for term 1

Term 2
: First definition for term 2
: Second definition for term 2

## Abbreviations

The HTML specification is maintained by the W3C.

*[HTML]: Hyper Text Markup Language
*[W3C]: World Wide Web Consortium

---

*All GFM features above should render correctly in the preview.*
