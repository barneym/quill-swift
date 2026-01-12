# Large Document Performance Test

This document is designed to test QuillSwift's performance with larger files.

---

## Section 1: Lorem Ipsum Text

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.

Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum. Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet, consectetur, adipisci velit.

### Subsection 1.1

Lorem ipsum dolor sit amet, **consectetur adipiscing elit**. Vivamus lacinia odio vitae vestibulum vestibulum. Cras venenatis euismod malesuada. Nulla facilisi. Nullam vel eros sit amet *lectus molestie* tincidunt.

Praesent commodo cursus magna, vel scelerisque nisl consectetur et. Donec id elit non mi porta gravida at eget metus. Nullam id dolor id nibh ultricies vehicula ut id elit.

```swift
// Code block for performance testing
struct PerformanceTest {
    let iterations: Int
    let data: [String]

    func run() -> TimeInterval {
        let start = Date()
        for _ in 0..<iterations {
            _ = data.map { $0.uppercased() }
        }
        return Date().timeIntervalSince(start)
    }
}
```

### Subsection 1.2

| Column A | Column B | Column C | Column D |
|----------|----------|----------|----------|
| Row 1 | Data | Data | Data |
| Row 2 | Data | Data | Data |
| Row 3 | Data | Data | Data |
| Row 4 | Data | Data | Data |
| Row 5 | Data | Data | Data |

---

## Section 2: Task Lists

- [x] Task 1 completed
- [x] Task 2 completed
- [x] Task 3 completed
- [ ] Task 4 pending
- [ ] Task 5 pending
- [/] Task 6 in progress
- [!] Task 7 important
- [-] Task 8 blocked
- [x] Task 9 completed
- [ ] Task 10 pending

---

## Section 3: More Content

### Code Examples

```python
def fibonacci(n):
    """Calculate the nth Fibonacci number."""
    if n <= 1:
        return n
    return fibonacci(n - 1) + fibonacci(n - 2)

# Test the function
for i in range(20):
    print(f"F({i}) = {fibonacci(i)}")
```

```javascript
class DocumentManager {
    constructor() {
        this.documents = new Map();
    }

    addDocument(id, content) {
        this.documents.set(id, {
            content,
            created: new Date(),
            modified: new Date()
        });
    }

    getDocument(id) {
        return this.documents.get(id);
    }

    updateDocument(id, content) {
        const doc = this.documents.get(id);
        if (doc) {
            doc.content = content;
            doc.modified = new Date();
        }
    }
}
```

### Blockquotes

> "The quick brown fox jumps over the lazy dog." This sentence contains every letter of the alphabet.
>
> > Nested quote with more text to test rendering performance.
> >
> > > Even more deeply nested to stress test the parser.

---

## Section 4: Repeated Content for Size

### Paragraph Block 1

Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.

### Paragraph Block 2

Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.

### Paragraph Block 3

Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.

### Paragraph Block 4

Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt.

### Paragraph Block 5

At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident.

---

## Section 5: Links and References

Here are some [inline links](https://example.com) and [another link](https://github.com).

Reference-style links: [GitHub][gh] and [Apple][apple].

[gh]: https://github.com
[apple]: https://apple.com

---

## Section 6: Images

![Test Image 1](https://via.placeholder.com/400x200)

![Test Image 2](https://via.placeholder.com/300x150)

---

## Section 7: Mixed Formatting

This paragraph contains **bold text**, *italic text*, `inline code`, ~~strikethrough~~, and a [link](https://example.com). It also has ***bold italic*** text.

Another paragraph with mixed content: The `render()` function takes a **markdown string** and returns *HTML output*. See the [documentation](https://docs.example.com) for details.

---

## Section 8: Long List

1. Item one
2. Item two
3. Item three
4. Item four
5. Item five
6. Item six
7. Item seven
8. Item eight
9. Item nine
10. Item ten
11. Item eleven
12. Item twelve
13. Item thirteen
14. Item fourteen
15. Item fifteen
16. Item sixteen
17. Item seventeen
18. Item eighteen
19. Item nineteen
20. Item twenty

---

## Section 9: Definition List

Term 1
: Definition of term 1 with some additional text to make it longer.

Term 2
: Definition of term 2.
: Another definition for term 2.

Term 3
: Definition of term 3 with **bold** and *italic* formatting.

---

## Section 10: Final Notes

This document contains approximately:
- 10 major sections
- Multiple code blocks in different languages
- Tables with various alignments
- Task lists with extended checkbox syntax
- Nested blockquotes
- Mixed inline formatting
- Reference-style and inline links
- Images
- Definition lists

The goal is to test:
1. Syntax highlighting performance
2. Preview rendering speed
3. Scroll performance
4. Find and Replace on larger content

---

*End of performance test document.*
