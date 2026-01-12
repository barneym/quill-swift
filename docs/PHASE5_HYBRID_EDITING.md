# Phase 5: Hybrid WYSIWYG Editing (Live Preview Mode)

## Status: NOT IMPLEMENTED

The current `LivePreviewTextView.swift` is non-functional scaffolding with fundamental issues. A proper implementation is required.

---

## Objective

Create a seamless hybrid editing experience where:
- The editor shows **formatted preview** for lines the cursor is NOT on
- When the cursor **enters a line**, raw markdown syntax is revealed
- When the cursor **leaves a line**, it reformats to preview
- Cursor movement is **fluid and seamless** - feels like a normal editor
- Lines **naturally transform** as you navigate through the document

**Reference Implementation**: Obsidian's Live Preview mode

---

## Key Requirements

### 1. Seamless Cursor Movement
- Cursor navigation (arrow keys, mouse click) should feel natural
- No jarring transitions or visual jumps when moving between lines
- Line height should remain stable during transitions (no layout shift)
- Typing should work exactly as expected without cursor position issues

### 2. Line-Level Formatting
- **Current line (cursor present)**: Shows raw markdown syntax
- **Other lines**: Shows formatted preview (bold rendered, headings sized, links styled, etc.)
- Transition happens when cursor enters/leaves a line boundary

### 3. Jitter Prevention
- Minimize visual mutations during active editing
- Smart debouncing to avoid rapid reformatting while typing
- Don't reformat the current line while user is actively editing it
- Only reformat when cursor truly leaves (not during selection changes)

### 4. Block-Level Awareness
For multi-line constructs (code blocks, blockquotes, lists), consider treating the entire block as a unit:
- Entering anywhere in a code block reveals the whole block
- Leaving the block reformats it as a whole
- Prevents partial formatting of related lines

---

## What's Wrong with Current Implementation

The existing `LivePreviewTextView.swift` has these fundamental problems:

### 1. Broken Cursor Positioning
```swift
// WRONG: Hides characters visually but keeps them in text buffer
let hiddenAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 1),
    .foregroundColor: NSColor.clear
]
```

This approach:
- Characters are still in the text buffer at full count
- Arrow keys navigate through invisible characters
- Cursor position doesn't match visual position
- Selection breaks (selecting "Heading" actually selects "## Heading")
- Copy/paste includes hidden syntax

### 2. No Cursor Position Mapping
When `## Heading` displays as "Heading", the code provides no mapping between:
- Visual cursor position (character 0 of "Heading")
- Source cursor position (character 3 of "## Heading")

### 3. Editing is Broken
If you type while syntax is "hidden", characters insert at wrong visual positions.

---

## Correct Implementation Approach

### Option A: Style-Only Formatting (Recommended Start)

Don't hide characters - just style them differently:
- `##` shows in light gray, smaller font
- `**` shows in very light color
- Link URLs show in muted color

**Pros**:
- Cursor position is always correct
- No mapping needed
- Editing works naturally
- Simpler implementation

**Cons**:
- Less "clean" visual appearance
- Syntax characters still visible (just de-emphasized)

### Option B: True Character Hiding (Complex)

Use TextKit 2's layout system to actually hide characters from display while keeping them in the model:
- Custom `NSTextLayoutFragment` that skips rendering certain ranges
- Cursor position mapping via `NSTextLocation` translation
- Complex but achieves true WYSIWYG appearance

**Pros**:
- Clean visual appearance like Obsidian

**Cons**:
- Complex TextKit 2 implementation
- Cursor mapping is error-prone
- May have edge cases with selection, undo, etc.

### Option C: Dual-Buffer Approach (Most Complex)

Maintain two buffers:
- Source buffer: Raw markdown
- Display buffer: Formatted text with cursor mapping

**Pros**:
- Complete control over display

**Cons**:
- Most complex
- Sync issues between buffers
- Undo/redo complexity

---

## Implementation Steps (Recommended Path)

### Phase 5a: Style-Only Hybrid (MVP)
1. Delete current broken `LivePreviewTextView.swift` code
2. Implement line-level cursor tracking
3. On cursor leave: Apply de-emphasized styling to syntax characters
4. On cursor enter: Restore normal styling (reveal syntax)
5. Test thoroughly with all markdown constructs
6. Tune debouncing for smooth experience

### Phase 5b: Enhanced Visual Polish
1. Evaluate if style-only is sufficient for UX goals
2. If not, investigate TextKit 2 layout hiding approach
3. Implement proper cursor position mapping if needed

---

## Acceptance Criteria

- [ ] Cursor movement through document feels fluid and natural
- [ ] Lines transform seamlessly as cursor enters/leaves
- [ ] No visual jitter or layout shifts during navigation
- [ ] Typing works correctly on any line
- [ ] Selection works correctly across formatted lines
- [ ] Copy/paste works correctly
- [ ] Undo/redo works correctly
- [ ] Code blocks handled as units
- [ ] Blockquotes handled appropriately
- [ ] Lists (including nested) handled appropriately
- [ ] Performance acceptable on large documents (50KB+)
- [ ] Matches Obsidian Live Preview UX quality

---

## Test Cases

1. **Arrow key navigation**: Up/down through formatted headings
2. **Click positioning**: Click in middle of formatted bold text
3. **Typing mid-line**: Enter a formatted line, type in middle
4. **Selection across lines**: Select text spanning formatted and raw lines
5. **Multi-line blocks**: Navigate into/out of code blocks
6. **Rapid navigation**: Quick repeated arrow keys
7. **Mouse + keyboard**: Click then arrow keys
8. **Undo after format transition**: Type, leave line, undo

---

## Related Files

- `QuillSwiftApp/Editor/LivePreviewTextView.swift` - Current broken implementation (needs rewrite)
- `QuillSwiftApp/Editor/MarkdownTextView.swift` - Base class
- `QuillSwiftApp/Editor/MarkdownHighlighter.swift` - Syntax highlighting (reference for patterns)

---

## References

- [Obsidian Live Preview](https://help.obsidian.md/Editing+and+formatting/Live+preview) - Target UX
- [TextKit 2 Documentation](https://developer.apple.com/documentation/uikit/textkit) - For advanced implementation
- [NSTextLayoutManager](https://developer.apple.com/documentation/appkit/nstextlayoutmanager) - Layout control
