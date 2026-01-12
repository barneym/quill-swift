import Foundation
import AppKit
import WebKit

/// Manages scroll position synchronization between source editor and preview.
///
/// When toggling between source and preview modes, this maintains the user's
/// reading position by:
/// 1. Recording the top visible line/block before switching
/// 2. Scrolling the target view to the corresponding position
///
/// Phase 7 (read-only preview): Anchors to top visible line
/// After Phase 5 (dual editing): Will anchor to cursor line
class ScrollSync {

    // MARK: - Position Types

    /// Represents a position in the source editor
    struct SourcePosition {
        /// Line number (1-based)
        let line: Int
        /// Character offset within the line
        let characterOffset: Int
        /// Fraction of line visible (0.0 = top of line, 1.0 = bottom)
        let lineFraction: CGFloat
    }

    /// Represents a position in the preview
    struct PreviewPosition {
        /// Approximate line number from source
        let sourceLine: Int
        /// Scroll offset in pixels
        let scrollOffset: CGFloat
    }

    // MARK: - Properties

    /// Last known source position
    private(set) var lastSourcePosition: SourcePosition?

    /// Last known preview position
    private(set) var lastPreviewPosition: PreviewPosition?

    // MARK: - Source Position Tracking

    /// Get the current top visible line from source editor
    func captureSourcePosition(from textView: NSTextView) -> SourcePosition? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let scrollView = textView.enclosingScrollView else {
            return nil
        }

        // Get visible rect in text view coordinates
        let visibleRect = scrollView.documentVisibleRect
        let visibleOrigin = visibleRect.origin

        // Find the glyph at the top of visible area
        let glyphIndex = layoutManager.glyphIndex(for: visibleOrigin, in: textContainer)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)

        // Get line number for this character
        let string = textView.string as NSString
        var lineNumber = 1
        var charCount = 0

        string.enumerateSubstrings(
            in: NSRange(location: 0, length: min(charIndex, string.length)),
            options: [.byLines, .substringNotRequired]
        ) { _, _, enclosingRange, _ in
            lineNumber += 1
            charCount = enclosingRange.location + enclosingRange.length
        }

        // Calculate character offset within line
        let charOffset = charIndex - charCount

        // Calculate line fraction (how much of line is above visible area)
        let lineRect = layoutManager.boundingRect(forGlyphRange: NSRange(location: glyphIndex, length: 1), in: textContainer)
        let lineFraction = (visibleOrigin.y - lineRect.origin.y) / lineRect.height

        let position = SourcePosition(
            line: lineNumber,
            characterOffset: max(0, charOffset),
            lineFraction: max(0, min(1, lineFraction))
        )

        lastSourcePosition = position
        return position
    }

    /// Scroll source editor to a position
    func scrollSource(to position: SourcePosition, in textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        let string = textView.string as NSString

        // Find character index for line
        var charIndex = 0
        var currentLine = 1

        string.enumerateSubstrings(
            in: NSRange(location: 0, length: string.length),
            options: [.byLines, .substringNotRequired]
        ) { _, _, enclosingRange, stop in
            if currentLine >= position.line {
                charIndex = enclosingRange.location
                stop.pointee = true
            }
            currentLine += 1
        }

        // Add character offset
        charIndex = min(charIndex + position.characterOffset, string.length)

        // Get glyph for this character
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)

        // Get rect for this position
        let lineRect = layoutManager.boundingRect(
            forGlyphRange: NSRange(location: glyphIndex, length: 1),
            in: textContainer
        )

        // Scroll to position with line fraction offset
        var scrollPoint = lineRect.origin
        scrollPoint.y -= position.lineFraction * lineRect.height
        scrollPoint.y = max(0, scrollPoint.y)

        // Scroll the text view
        textView.scroll(scrollPoint)
    }

    /// Scroll source to show a specific line at the top
    func scrollSourceToLine(_ line: Int, in textView: NSTextView) {
        let position = SourcePosition(line: line, characterOffset: 0, lineFraction: 0)
        scrollSource(to: position, in: textView)
    }

    // MARK: - Preview Position Tracking

    /// Capture current preview scroll position
    func capturePreviewPosition(from webView: WKWebView, completion: @escaping (PreviewPosition?) -> Void) {
        // Get current scroll position via JavaScript
        webView.evaluateJavaScript("window.pageYOffset || document.documentElement.scrollTop") { result, error in
            guard let scrollOffset = result as? CGFloat else {
                completion(nil)
                return
            }

            // Estimate source line from scroll position
            // This is approximate - better mapping would use data attributes
            webView.evaluateJavaScript("document.body.scrollHeight") { heightResult, _ in
                let bodyHeight = heightResult as? CGFloat ?? 1

                // Approximate line based on scroll fraction
                let scrollFraction = scrollOffset / bodyHeight

                webView.evaluateJavaScript("document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, pre, blockquote, tr').length") { countResult, _ in
                    let blockCount = countResult as? Int ?? 1
                    let estimatedLine = Int(Double(blockCount) * scrollFraction) + 1

                    let position = PreviewPosition(
                        sourceLine: estimatedLine,
                        scrollOffset: scrollOffset
                    )

                    self.lastPreviewPosition = position
                    completion(position)
                }
            }
        }
    }

    /// Scroll preview to show content corresponding to source line
    func scrollPreviewToLine(_ line: Int, in webView: WKWebView) {
        // Use JavaScript to scroll to approximate position
        // Better implementation would use data-line attributes on HTML elements
        let js = """
        (function() {
            // Get all block elements
            var blocks = document.querySelectorAll('p, h1, h2, h3, h4, h5, h6, li, pre, blockquote, tr');
            var targetBlock = Math.min(\(line - 1), blocks.length - 1);

            if (targetBlock >= 0 && blocks[targetBlock]) {
                blocks[targetBlock].scrollIntoView({ behavior: 'auto', block: 'start' });
            }
        })();
        """

        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    /// Scroll preview to a specific scroll offset
    func scrollPreview(toOffset offset: CGFloat, in webView: WKWebView) {
        let js = "window.scrollTo(0, \(offset));"
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    // MARK: - Mode Switching

    /// Sync position from source to preview
    func syncSourceToPreview(textView: NSTextView, webView: WKWebView) {
        guard let position = captureSourcePosition(from: textView) else {
            return
        }

        scrollPreviewToLine(position.line, in: webView)
    }

    /// Sync position from preview to source
    func syncPreviewToSource(webView: WKWebView, textView: NSTextView, completion: @escaping () -> Void) {
        capturePreviewPosition(from: webView) { [weak self] position in
            guard let position = position else {
                completion()
                return
            }

            self?.scrollSourceToLine(position.sourceLine, in: textView)
            completion()
        }
    }
}

// MARK: - Line Mapping

extension ScrollSync {

    /// Generate a mapping from source lines to preview block indices
    /// This enables more accurate scroll sync by tracking actual correspondences
    struct LineMapping {
        /// Maps source line number to preview block index
        var sourceToPreview: [Int: Int] = [:]

        /// Maps preview block index to source line
        var previewToSource: [Int: Int] = [:]
    }

    /// Build a line mapping from markdown source
    /// This parses the source to identify block boundaries
    func buildLineMapping(from source: String) -> LineMapping {
        var mapping = LineMapping()
        var blockIndex = 0
        var lineNumber = 1

        let lines = source.components(separatedBy: .newlines)

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Skip empty lines (don't create blocks)
            if trimmed.isEmpty {
                lineNumber += 1
                continue
            }

            // Map this line to current block
            mapping.sourceToPreview[lineNumber] = blockIndex
            mapping.previewToSource[blockIndex] = lineNumber

            // Determine if this starts a new block
            // (simplified - real implementation would be more sophisticated)
            if trimmed.hasPrefix("#") ||        // Heading
               trimmed.hasPrefix("- ") ||       // List item
               trimmed.hasPrefix("* ") ||
               trimmed.hasPrefix("+ ") ||
               trimmed.hasPrefix("> ") ||       // Blockquote
               trimmed.hasPrefix("```") ||      // Code fence
               trimmed.first?.isNumber == true  // Ordered list
            {
                blockIndex += 1
            } else if !lines.indices.contains(lineNumber) ||
                      lines[lineNumber].trimmingCharacters(in: .whitespaces).isEmpty {
                // End of paragraph
                blockIndex += 1
            }

            lineNumber += 1
        }

        return mapping
    }
}
