import Foundation
import AppKit
import WebKit

/// Keeps the reading position when toggling between source and preview.
///
/// ## Approach
///
/// The renderer tags every block element with its 0-based source line span
/// (`data-line` / `data-line-end`). From those tags the preview builds a
/// piecewise-linear, monotonic map between *fractional source lines* and
/// *document y offsets*: each block contributes its top edge (start line) and
/// bottom edge (end line + 1), and positions between known points are
/// interpolated. The source editor has the same kind of map from TextKit line
/// fragments. This is the technique VS Code's markdown preview uses.
///
/// The anchor is the **center of the viewport**: the line under the center of
/// one view is placed under the center of the other, clamped at the document
/// edges. A view scrolled all the way to the top or bottom maps to the top or
/// bottom of the other view, so edge positions always survive a toggle.
///
/// Toggling back without scrolling reuses the previous anchor instead of
/// re-measuring, so repeated toggles never drift, even where clamping made the
/// two views disagree about the center line.
final class ScrollSync {

    // MARK: - Types

    /// A mode-independent reading position.
    enum Anchor: Equatable {
        /// Scrolled to the very top of the document
        case top
        /// Scrolled to the very bottom of the document
        case bottom
        /// Fractional 0-based source line under the viewport center
        case line(Double)
    }

    /// The position most recently applied to a view, with the scroll offset it produced.
    private struct AppliedPosition {
        let mode: ViewMode
        let scrollY: CGFloat
        let anchor: Anchor
    }

    // MARK: - Properties

    /// Anchor waiting to be applied once the destination view is ready
    private(set) var pendingAnchor: Anchor?

    private var lastApplied: AppliedPosition?

    /// Tolerance for "the user hasn't scrolled since we positioned the view"
    private let unchangedTolerance: CGFloat = 2

    // MARK: - Capture

    /// Capture the source editor's reading position as the pending anchor.
    func captureSource(from textView: NSTextView) {
        guard let geometry = SourceGeometry(textView: textView) else { return }
        let scrollY = geometry.scrollY
        if let last = lastApplied, last.mode == .source, abs(last.scrollY - scrollY) <= unchangedTolerance {
            pendingAnchor = last.anchor
        } else {
            pendingAnchor = geometry.anchor()
        }
    }

    /// Capture the preview's reading position as the pending anchor.
    func capturePreview(from webView: WKWebView, completion: @escaping () -> Void) {
        webView.evaluateJavaScript("window.__qsSync ? window.__qsSync.anchor() : null") { [weak self] result, _ in
            guard let self else { return completion() }
            if let dict = result as? [String: Any] {
                let scrollY = (dict["scrollY"] as? NSNumber).map { CGFloat($0.doubleValue) } ?? 0
                if let last = self.lastApplied, last.mode == .preview,
                   abs(last.scrollY - scrollY) <= self.unchangedTolerance {
                    self.pendingAnchor = last.anchor
                } else {
                    self.pendingAnchor = Self.anchor(fromScript: dict)
                }
            }
            completion()
        }
    }

    // MARK: - Apply

    /// Scroll the source editor to the pending anchor. Waits for the text view
    /// to have a real viewport, since a freshly created view starts at zero size.
    func applyPending(to textView: NSTextView, attempt: Int = 0) {
        guard let anchor = pendingAnchor else { return }
        guard let clipView = textView.enclosingScrollView?.contentView,
              clipView.bounds.height > 0, textView.window != nil else {
            if attempt < 20 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self, weak textView] in
                    guard let textView else { return }
                    self?.applyPending(to: textView, attempt: attempt + 1)
                }
            }
            return
        }
        guard let geometry = SourceGeometry(textView: textView) else { return }
        let scrollY = geometry.scroll(to: anchor)
        pendingAnchor = nil
        lastApplied = AppliedPosition(mode: .source, scrollY: scrollY, anchor: anchor)
        reapplyIfResized(textView, anchor: anchor, width: clipView.bounds.width, scrollY: scrollY)
    }

    /// If the view settles to a different width right after positioning (the
    /// mode-switch transition), the text rewraps; place the anchor again,
    /// unless the user has already scrolled.
    private func reapplyIfResized(_ textView: NSTextView, anchor: Anchor, width: CGFloat, scrollY: CGFloat, attempt: Int = 0) {
        guard attempt < 3 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self, weak textView] in
            guard let self, let textView, let clipView = textView.enclosingScrollView?.contentView,
                  self.pendingAnchor == nil,
                  abs(clipView.bounds.minY - scrollY) <= self.unchangedTolerance else { return }
            if abs(clipView.bounds.width - width) < 0.5 {
                self.reapplyIfResized(textView, anchor: anchor, width: width, scrollY: scrollY, attempt: attempt + 1)
                return
            }
            guard let geometry = SourceGeometry(textView: textView) else { return }
            let newY = geometry.scroll(to: anchor)
            self.lastApplied = AppliedPosition(mode: .source, scrollY: newY, anchor: anchor)
            self.reapplyIfResized(textView, anchor: anchor, width: clipView.bounds.width, scrollY: newY, attempt: attempt + 1)
        }
    }

    /// Scroll the preview to the pending anchor. Call after the page finishes
    /// loading; the script also waits for images, fonts and diagrams to settle.
    func applyPending(to webView: WKWebView) {
        guard let anchor = pendingAnchor else { return }
        pendingAnchor = nil
        let args: [String: Any]
        switch anchor {
        case .top: args = ["edge": "top", "line": 0]
        case .bottom: args = ["edge": "bottom", "line": 0]
        case .line(let line): args = ["edge": "", "line": line]
        }
        webView.callAsyncJavaScript(
            "return window.__qsSync ? await window.__qsSync.scrollToAnchor(edge, line) : null",
            arguments: args,
            in: nil,
            in: .page
        ) { [weak self] result in
            guard case .success(let value) = result, let number = value as? NSNumber else { return }
            self?.lastApplied = AppliedPosition(mode: .preview, scrollY: CGFloat(number.doubleValue), anchor: anchor)
        }
    }

    // MARK: - Helpers

    private static func anchor(fromScript dict: [String: Any]) -> Anchor {
        switch dict["edge"] as? String {
        case "top": return .top
        case "bottom": return .bottom
        default:
            let line = (dict["line"] as? NSNumber)?.doubleValue ?? 0
            return .line(line)
        }
    }
}

// MARK: - Source Geometry

/// Maps between fractional source lines and y offsets in the source editor.
private struct SourceGeometry {
    let textView: NSTextView
    let layoutManager: NSLayoutManager
    let textContainer: NSTextContainer
    let clipView: NSClipView
    /// UTF-16 offset of the first character of each line
    let lineStarts: [Int]
    let length: Int

    init?(textView: NSTextView) {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              let clipView = textView.enclosingScrollView?.contentView else {
            return nil
        }
        self.textView = textView
        self.layoutManager = layoutManager
        self.textContainer = textContainer
        self.clipView = clipView
        let string = textView.string as NSString
        self.length = string.length
        self.lineStarts = Self.lineStarts(of: string)
        // Line positions below the fold are only valid once laid out
        layoutManager.ensureLayout(for: textContainer)
    }

    var scrollY: CGFloat { clipView.bounds.minY }
    private var viewportHeight: CGFloat { clipView.bounds.height }
    private var maxScrollY: CGFloat { max(0, textView.frame.height - viewportHeight) }
    private var originY: CGFloat { textView.textContainerOrigin.y }

    func anchor() -> ScrollSync.Anchor {
        if maxScrollY <= 1 || scrollY <= 1 { return .top }
        if scrollY >= maxScrollY - 1 { return .bottom }
        return .line(line(atY: scrollY + viewportHeight / 2 - originY))
    }

    /// Scroll so the anchor sits at the viewport center; returns the resulting offset.
    func scroll(to anchor: ScrollSync.Anchor) -> CGFloat {
        let target: CGFloat
        switch anchor {
        case .top:
            target = 0
        case .bottom:
            target = maxScrollY
        case .line(let line):
            let y = originY + y(forLine: line)
            target = min(max(0, y - viewportHeight / 2), maxScrollY)
        }
        clipView.scroll(to: NSPoint(x: clipView.bounds.minX, y: target))
        textView.enclosingScrollView?.reflectScrolledClipView(clipView)
        return clipView.bounds.minY
    }

    // MARK: Line ↔ y

    /// Top of line `index` in text-container coordinates.
    private func lineTop(_ index: Int) -> CGFloat {
        guard index < lineStarts.count else { return layoutManager.usedRect(for: textContainer).maxY }
        let charIndex = lineStarts[index]
        if charIndex >= length {
            // Empty last line lives in the extra line fragment
            let extra = layoutManager.extraLineFragmentRect
            return extra.isEmpty ? layoutManager.usedRect(for: textContainer).maxY : extra.minY
        }
        let glyphIndex = layoutManager.glyphIndexForCharacter(at: charIndex)
        return layoutManager.lineFragmentRect(forGlyphAt: glyphIndex, effectiveRange: nil).minY
    }

    func y(forLine line: Double) -> CGFloat {
        let clamped = min(max(0, line), Double(lineStarts.count))
        let index = min(Int(clamped.rounded(.down)), lineStarts.count - 1)
        let fraction = CGFloat(clamped - Double(index))
        let top = lineTop(index)
        let bottom = lineTop(index + 1)
        return top + fraction * max(0, bottom - top)
    }

    func line(atY y: CGFloat) -> Double {
        guard length > 0 else { return 0 }
        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(for: NSPoint(x: 0, y: y), in: textContainer, fractionOfDistanceThroughGlyph: &fraction)
        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let index = Self.lineIndex(containing: charIndex, in: lineStarts)
        let top = lineTop(index)
        let bottom = lineTop(index + 1)
        guard bottom > top else { return Double(index) }
        return Double(index) + Double(min(max(0, (y - top) / (bottom - top)), 1))
    }

    // MARK: Line Table

    /// Line starts using CommonMark line endings (LF, CRLF, CR).
    static func lineStarts(of string: NSString) -> [Int] {
        var starts = [0]
        let length = string.length
        var buffer = [unichar](repeating: 0, count: length)
        string.getCharacters(&buffer, range: NSRange(location: 0, length: length))
        var i = 0
        while i < length {
            let c = buffer[i]
            if c == 0x0A {
                starts.append(i + 1)
            } else if c == 0x0D {
                if i + 1 < length, buffer[i + 1] == 0x0A { i += 1 }
                starts.append(i + 1)
            }
            i += 1
        }
        return starts
    }

    static func lineIndex(containing charIndex: Int, in starts: [Int]) -> Int {
        var low = 0, high = starts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if starts[mid] <= charIndex { low = mid } else { high = mid - 1 }
        }
        return low
    }
}

// MARK: - Preview Script

extension ScrollSync {

    /// Injected into the preview page. Builds the line ↔ y map from `data-line`
    /// attributes and exposes `anchor()` and `scrollToAnchor(edge, line)`.
    static let previewScript = """
    (function() {
        function points() {
            var sy = window.scrollY;
            var raw = [];
            document.querySelectorAll('[data-line]').forEach(function(el) {
                var r = el.getBoundingClientRect();
                if (r.width === 0 && r.height === 0) { return; }
                var start = +el.dataset.line;
                var end = el.dataset.lineEnd !== undefined ? +el.dataset.lineEnd : start;
                raw.push([start, r.top + sy]);
                raw.push([end + 1, r.bottom + sy]);
            });
            raw.sort(function(a, b) { return a[0] - b[0] || a[1] - b[1]; });
            // Keep a strictly-increasing-line, non-decreasing-y sequence
            var out = [[0, 0]];
            raw.forEach(function(p) {
                var last = out[out.length - 1];
                if (p[0] > last[0] && p[1] >= last[1]) { out.push(p); }
            });
            return out;
        }

        function yForLine(line) {
            var pts = points();
            for (var i = 0; i < pts.length - 1; i++) {
                var a = pts[i], b = pts[i + 1];
                if (line < b[0]) {
                    return a[1] + (Math.max(line, a[0]) - a[0]) / (b[0] - a[0]) * (b[1] - a[1]);
                }
            }
            return pts[pts.length - 1][1];
        }

        function lineForY(y) {
            var pts = points();
            for (var i = 0; i < pts.length - 1; i++) {
                var a = pts[i], b = pts[i + 1];
                if (y < b[1] && b[1] > a[1]) {
                    return a[0] + (Math.max(y, a[1]) - a[1]) / (b[1] - a[1]) * (b[0] - a[0]);
                }
            }
            return pts[pts.length - 1][0];
        }

        function maxScroll() {
            return Math.max(0, document.documentElement.scrollHeight - window.innerHeight);
        }

        function delay(ms) { return new Promise(function(r) { setTimeout(r, ms); }); }

        // Resolve once images, fonts and diagrams have settled (bounded wait)
        function settled() {
            var waits = [];
            if (document.fonts && document.fonts.ready) { waits.push(document.fonts.ready); }
            document.querySelectorAll('img').forEach(function(img) {
                if (!img.complete) {
                    waits.push(new Promise(function(r) { img.addEventListener('load', r); img.addEventListener('error', r); }));
                }
            });
            var diagrams = new Promise(function(resolve) {
                var tries = 0;
                (function poll() {
                    var pending = Array.prototype.some.call(
                        document.querySelectorAll('.mermaid-diagram'),
                        function(d) { return d.childElementCount === 0; });
                    if (!pending || tries++ > 40) { resolve(); } else { setTimeout(poll, 25); }
                })();
            });
            waits.push(diagrams);
            return Promise.race([Promise.all(waits), delay(1500)]).then(function() {
                return new Promise(function(r) { requestAnimationFrame(function() { requestAnimationFrame(r); }); });
            });
        }

        window.__qsSync = {
            anchor: function() {
                var sy = window.scrollY, max = maxScroll();
                if (max <= 1 || sy <= 1) { return { edge: 'top', scrollY: sy }; }
                if (sy >= max - 1) { return { edge: 'bottom', scrollY: sy }; }
                return { edge: '', line: lineForY(sy + window.innerHeight / 2), scrollY: sy };
            },
            scrollToAnchor: async function(edge, line) {
                await settled();
                var target;
                if (edge === 'top') { target = 0; }
                else if (edge === 'bottom') { target = maxScroll(); }
                else { target = Math.min(Math.max(0, yForLine(line) - window.innerHeight / 2), maxScroll()); }
                // Round rather than let WebKit truncate, so a round trip lands on the same pixel
                window.scrollTo(0, Math.round(target));
                return window.scrollY;
            },
            lineForY: lineForY,
            yForLine: yForLine
        };
    })();
    """
}
