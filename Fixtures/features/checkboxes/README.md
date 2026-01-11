# Checkboxes Fixtures

## Purpose

Test standard and extended checkbox parsing and rendering.

## Features Tested

### Standard Checkboxes (GFM)

- [ ] Unchecked checkbox `- [ ]`
- [ ] Checked checkbox `- [x]` or `- [X]`
- [ ] Checkbox with text
- [ ] Nested checkbox lists
- [ ] Mixed checkbox and regular list items

### Extended Checkboxes (QuillSwift)

- [ ] In progress `- [/]`
- [ ] Cancelled `- [-]`
- [ ] Deferred `- [>]`
- [ ] Scheduled `- [<]`
- [ ] Question `- [?]`
- [ ] Important `- [!]`
- [ ] Star `- [*]`
- [ ] Quote `- ["]`
- [ ] Location `- [l]`
- [ ] Information `- [i]`
- [ ] Savings `- [S]`
- [ ] Idea `- [I]`
- [ ] Pro `- [p]`
- [ ] Con `- [c]`
- [ ] Bookmark `- [b]`
- [ ] Fire/urgent `- [f]`

## Fixtures

| File | Tests |
|------|-------|
| `standard.input.md` | GFM-style checkboxes |
| `extended.input.md` | All extended checkbox types |
| `mixed.input.md` | Standard and extended mixed |
| `nested.input.md` | Nested checkbox lists |
| `disabled.input.md` | Test with extensions disabled |

## Rendering Requirements

- Standard checkboxes render as interactive `<input type="checkbox">`
- Extended checkboxes render with distinct icons/colors
- CSS variables control checkbox styling
- Click toggles between states appropriately

## Related Specs

- GFM Task Lists
- Obsidian-style checkboxes (inspiration, not spec)

## Configuration

Extended checkboxes are controlled by setting:
```json
{
  "markdown": {
    "extensions": {
      "custom_checkboxes": true
    }
  }
}
```
