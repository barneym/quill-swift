import SwiftUI
import AppKit
import WebKit

/// Find bar for preview mode, styled after the native NSTextView find bar.
///
/// Matches are highlighted in the page by `PreviewScripts.find`. The query is
/// shared with the source editor's find bar through the system find pasteboard,
/// so a search carries over when toggling modes (and between apps, as in Safari).
struct PreviewFindBar: View {

    @ObservedObject var model: PreviewFindModel

    @FocusState private var isFieldFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 11))
                TextField("Search", text: $model.query)
                    .textFieldStyle(.plain)
                    .focused($isFieldFocused)
                    .onSubmit { model.next() }
                if !model.query.isEmpty {
                    Text(model.statusText)
                        .font(.caption)
                        .foregroundColor(model.matchCount == 0 ? .red : .secondary)
                        .monospacedDigit()
                        .fixedSize()
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(Color(nsColor: .separatorColor))
            )

            ControlGroup {
                Button(action: model.previous) {
                    Image(systemName: "chevron.left")
                }
                .help("Find Previous (⇧⌘G)")
                Button(action: model.next) {
                    Image(systemName: "chevron.right")
                }
                .help("Find Next (⌘G)")
            }
            .controlSize(.small)
            .fixedSize()
            .disabled(model.matchCount == 0)

            Button("Done", action: model.close)
                .controlSize(.small)
                .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
        .onAppear { isFieldFocused = true }
        .onChange(of: model.focusRequest) { _ in isFieldFocused = true }
        .onChange(of: model.query) { _ in model.search() }
    }
}

// MARK: - Model

/// State and page commands for the preview find bar.
@MainActor
final class PreviewFindModel: ObservableObject {

    @Published var isVisible = false
    @Published var query = ""
    @Published private(set) var matchCount = 0
    @Published private(set) var currentIndex = -1
    /// Bumped to move keyboard focus back into the search field
    @Published private(set) var focusRequest = 0

    weak var webView: WKWebView?

    var statusText: String {
        matchCount == 0 ? "Not found" : "\(currentIndex + 1) of \(matchCount)"
    }

    /// Show the bar, seeded from the shared find pasteboard.
    func show() {
        if !isVisible, let shared = Self.sharedFindString, !shared.isEmpty {
            query = shared
        }
        isVisible = true
        focusRequest += 1
        search()
    }

    func close() {
        isVisible = false
        webView?.evaluateJavaScript("window.__qsFind && window.__qsFind.clear()", completionHandler: nil)
        matchCount = 0
        currentIndex = -1
    }

    /// Re-run the search, e.g. after the page reloads.
    func search() {
        guard isVisible else { return }
        Self.sharedFindString = query
        run("window.__qsFind.search(\(Self.jsString(query)))")
    }

    func next() {
        if !isVisible { show(); return }
        run("window.__qsFind.step(1)")
    }

    func previous() {
        if !isVisible { show(); return }
        run("window.__qsFind.step(-1)")
    }

    /// "Use Selection for Find": seed the query from the page selection.
    func useSelection() {
        webView?.evaluateJavaScript("window.getSelection().toString()") { [weak self] result, _ in
            guard let self, let text = result as? String, !text.isEmpty else { return }
            Self.sharedFindString = text
            self.query = text
        }
    }

    private func run(_ script: String) {
        guard let webView else { return }
        webView.evaluateJavaScript("window.__qsFind ? \(script) : null") { [weak self] result, _ in
            guard let self, let dict = result as? [String: Any] else { return }
            self.matchCount = (dict["count"] as? NSNumber)?.intValue ?? 0
            self.currentIndex = (dict["index"] as? NSNumber)?.intValue ?? -1
        }
    }

    /// JSON-encode a string so it can be embedded in a script literal.
    private static func jsString(_ string: String) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: [string]),
              let array = String(data: data, encoding: .utf8) else {
            return "\"\""
        }
        return String(array.dropFirst().dropLast())
    }

    /// The system-wide find string shared by NSTextView find bars and Safari.
    static var sharedFindString: String? {
        get { NSPasteboard(name: .find).string(forType: .string) }
        set {
            guard let newValue, newValue != sharedFindString else { return }
            let pasteboard = NSPasteboard(name: .find)
            pasteboard.clearContents()
            pasteboard.setString(newValue, forType: .string)
        }
    }
}

// MARK: - Source Find

extension NSTextView {
    /// Run a find-bar action. AppKit reads the action from the sender's `tag`,
    /// so it must be sent from an NSMenuItem-like object, not the raw enum.
    func performFindAction(_ action: NSTextFinder.Action) {
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        performFindPanelAction(sender)
    }
}

// MARK: - Page Scripts

enum PreviewScripts {

    /// In-page find: wraps matches in `<mark class="qs-find">`, tracks the
    /// current match, and scrolls it to the middle of the view.
    static let find = #"""
    (function() {
        var style = document.createElement('style');
        style.textContent =
            'mark.qs-find { background: rgba(255, 214, 10, 0.45); color: inherit; border-radius: 2px; }' +
            'mark.qs-find.qs-current { background: rgb(255, 159, 10); color: black; }';
        document.head.appendChild(style);

        var marks = [];
        var current = -1;

        function clear() {
            document.querySelectorAll('mark.qs-find').forEach(function(m) {
                var parent = m.parentNode;
                while (m.firstChild) { parent.insertBefore(m.firstChild, m); }
                parent.removeChild(m);
                parent.normalize();
            });
            marks = [];
            current = -1;
        }

        function result() { return { count: marks.length, index: current }; }

        function select(index) {
            if (current >= 0 && marks[current]) { marks[current].classList.remove('qs-current'); }
            current = index;
            if (current >= 0 && marks[current]) {
                marks[current].classList.add('qs-current');
                marks[current].scrollIntoView({ block: 'center', inline: 'nearest' });
            }
            return result();
        }

        function search(query) {
            clear();
            if (!query) { return result(); }
            var needle = query.toLocaleLowerCase();
            var root = document.querySelector('.markdown-body') || document.body;
            var walker = document.createTreeWalker(root, NodeFilter.SHOW_TEXT, {
                acceptNode: function(node) {
                    var tag = node.parentNode && node.parentNode.nodeName;
                    return (tag === 'SCRIPT' || tag === 'STYLE') ? NodeFilter.FILTER_REJECT : NodeFilter.FILTER_ACCEPT;
                }
            });
            var nodes = [];
            while (walker.nextNode()) { nodes.push(walker.currentNode); }
            nodes.forEach(function(node) {
                var text = node.nodeValue;
                var haystack = text.toLocaleLowerCase();
                if (haystack.length !== text.length) { return; } // case mapping changed offsets
                var at = haystack.indexOf(needle);
                while (at !== -1) {
                    var match = node.splitText(at);
                    node = match.splitText(needle.length);
                    var mark = document.createElement('mark');
                    mark.className = 'qs-find';
                    match.parentNode.insertBefore(mark, match);
                    mark.appendChild(match);
                    marks.push(mark);
                    text = node.nodeValue;
                    haystack = text.toLocaleLowerCase();
                    at = haystack.indexOf(needle);
                }
            });
            if (marks.length === 0) { return result(); }
            // Like Safari, start from the first match at or below the top of the view
            var first = marks.findIndex(function(m) { return m.getBoundingClientRect().top >= 0; });
            return select(first === -1 ? 0 : first);
        }

        function step(delta) {
            if (marks.length === 0) { return result(); }
            return select((current + delta + marks.length) % marks.length);
        }

        window.__qsFind = { search: search, step: step, clear: clear };
    })();
    """#

    /// Copy handler: replaces WebKit's default clipboard HTML (which inlines
    /// every computed style) with plain structural HTML, so pasting into
    /// Google Docs and similar editors carries only markdown-level formatting.
    static let cleanCopy = #"""
    (function() {
        var ALLOWED = {
            P: [], BR: [], H1: [], H2: [], H3: [], H4: [], H5: [], H6: [],
            STRONG: [], B: [], EM: [], I: [], DEL: [], S: [], CODE: [], PRE: [],
            UL: [], OL: ['start'], LI: [], BLOCKQUOTE: [], HR: [],
            A: ['href'], IMG: ['src', 'alt', 'title'],
            TABLE: [], THEAD: [], TBODY: [], TR: [],
            TH: ['align', 'colspan', 'rowspan'], TD: ['align', 'colspan', 'rowspan'],
            SUP: [], SUB: []
        };
        // Ancestors worth re-creating when the selection sits inside them
        var CONTEXT = { PRE: 1, CODE: 1, LI: 1, UL: 1, OL: 1, BLOCKQUOTE: 1, H1: 1, H2: 1, H3: 1,
                        H4: 1, H5: 1, H6: 1, STRONG: 1, EM: 1, DEL: 1, A: 1, TABLE: 1, TR: 1 };

        function unwrap(el) {
            var parent = el.parentNode;
            while (el.firstChild) { parent.insertBefore(el.firstChild, el); }
            parent.removeChild(el);
        }

        function clean(root) {
            // Math: keep the TeX source rather than KaTeX's layout markup
            root.querySelectorAll('.katex').forEach(function(k) {
                var tex = k.querySelector('annotation[encoding="application/x-tex"]');
                var display = k.closest('.katex-display');
                k.replaceWith(document.createTextNode(tex ? (display ? '$$' + tex.textContent + '$$' : '$' + tex.textContent + '$') : k.textContent));
            });
            root.querySelectorAll('input[type="checkbox"]').forEach(function(box) {
                box.replaceWith(document.createTextNode(box.checked ? '☑' : '☐'));
            });
            root.querySelectorAll('script, style, svg, .mermaid-diagram').forEach(function(el) { el.remove(); });
            // Bottom-up so unwrapping never skips nodes
            var all = Array.prototype.slice.call(root.querySelectorAll('*')).reverse();
            all.forEach(function(el) {
                var allowed = ALLOWED[el.nodeName];
                if (!allowed) { unwrap(el); return; }
                Array.prototype.slice.call(el.attributes).forEach(function(attr) {
                    if (allowed.indexOf(attr.name) === -1) { el.removeAttribute(attr.name); }
                });
            });
            return root;
        }

        document.addEventListener('copy', function(event) {
            var selection = window.getSelection();
            if (!selection || selection.rangeCount === 0 || selection.isCollapsed) { return; }
            var holder = document.createElement('div');
            for (var i = 0; i < selection.rangeCount; i++) {
                holder.appendChild(selection.getRangeAt(i).cloneContents());
            }
            // Re-create structure the selection is nested in (e.g. part of one code block)
            var node = selection.getRangeAt(0).commonAncestorContainer;
            if (node.nodeType !== 1) { node = node.parentNode; }
            while (node && !(node.classList && node.classList.contains('markdown-body')) && node !== document.body) {
                if (CONTEXT[node.nodeName]) {
                    var shell = node.cloneNode(false);
                    while (holder.firstChild) { shell.appendChild(holder.firstChild); }
                    holder.appendChild(shell);
                }
                node = node.parentNode;
            }
            clean(holder);
            event.clipboardData.setData('text/html', holder.innerHTML);
            event.clipboardData.setData('text/plain', selection.toString());
            event.preventDefault();
        });
    })();
    """#
}
