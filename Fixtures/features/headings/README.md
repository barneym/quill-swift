# Headings Fixtures

## Purpose

Test heading parsing and rendering (H1-H6).

## Features Tested

- [ ] H1 through H6 levels
- [ ] ATX-style headings (# prefix)
- [ ] Setext-style headings (underlines)
- [ ] Heading with inline formatting (bold, italic, code)
- [ ] Heading with links
- [ ] Heading anchor ID generation
- [ ] Empty headings
- [ ] Headings with leading/trailing whitespace

## Fixtures

| File | Tests |
|------|-------|
| `atx-basic.input.md` | Basic ATX headings H1-H6 |
| `setext-basic.input.md` | Setext H1 and H2 |
| `inline-formatting.input.md` | Bold, italic, code in headings |
| `edge-cases.input.md` | Empty, whitespace, deeply nested |

## Related Specs

- CommonMark 4.2 (ATX headings)
- CommonMark 4.3 (Setext headings)

## Notes

- Anchor IDs use `q-` prefix to avoid conflicts
- Duplicate headings get numbered suffixes
