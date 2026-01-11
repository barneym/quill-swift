# Security Fixtures

## Purpose

Test HTML sanitization and security policies.

## Features Tested

- [ ] Script tag removal
- [ ] Event handler removal (onclick, onerror, etc.)
- [ ] Style attribute removal
- [ ] Dangerous URL scheme blocking (javascript:, vbscript:, etc.)
- [ ] Data URI validation and limits
- [ ] SVG sanitization
- [ ] iframe/embed/object blocking
- [ ] meta/link tag blocking

## Fixtures

| File | Tests | Forbidden |
|------|-------|-----------|
| `xss-basic.input.md` | Basic XSS vectors | `<script`, `javascript:` |
| `script-injection.input.md` | Script tag variants | All script tags |
| `event-handlers.input.md` | onclick, onerror, etc. | `on` event attributes |
| `url-schemes.input.md` | Dangerous URL schemes | `javascript:`, `vbscript:` |
| `data-uri.input.md` | Data URI abuse | Large data URIs, SVG |
| `svg-xss.input.md` | SVG-based attacks | SVG with scripts |
| `style-injection.input.md` | CSS-based attacks | `style` attribute |

## Test Format

Security fixtures define what must NOT appear in output:

```markdown
<!-- FORBIDDEN: <script, javascript:, onclick -->

# Heading

<script>alert('xss')</script>

[Click me](javascript:alert('xss'))
```

## Sanitization Policy

See Design.md §5 for full security policy.

**Always removed:**
- `<script>`, `<style>`, `<iframe>`, `<object>`, `<embed>`
- `on*` event handlers
- `javascript:`, `vbscript:`, `data:` (except allowed images)
- `style` attributes

**Allowed with restrictions:**
- `<img>` — local and remote (with placeholder)
- `<a>` — safe schemes only
- `data:image/*` — size limited, no SVG

## Notes

Security tests should never pass if output contains forbidden patterns.
CI blocks on any security fixture failure.
