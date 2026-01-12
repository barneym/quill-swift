import SwiftUI

/// Settings window for customizing QuillSwift appearance.
struct SettingsView: View {

    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        TabView {
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            EditorSettingsView()
                .tabItem {
                    Label("Editor", systemImage: "doc.text")
                }

            PreviewSettingsView()
                .tabItem {
                    Label("Preview", systemImage: "eye")
                }
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {

    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $themeManager.appearanceMode) {
                    ForEach(AppearanceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Color Scheme")
            }

            Section {
                Toggle("Show line numbers", isOn: $themeManager.showLineNumbers)
            } header: {
                Text("Display Options")
            }

            Section {
                HStack {
                    Button("Reset to Defaults") {
                        themeManager.resetToDefaults()
                    }

                    Spacer()

                    Button("Export Theme...") {
                        exportTheme()
                    }

                    Button("Import Theme...") {
                        importTheme()
                    }
                }
            } header: {
                Text("Theme Management")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func exportTheme() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "QuillSwift Theme.json"
        panel.allowedContentTypes = [.json]

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let data = try themeManager.exportTheme()
                try data.write(to: url)
            } catch {
                print("Failed to export theme: \(error)")
            }
        }
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }

            do {
                let data = try Data(contentsOf: url)
                try themeManager.importTheme(from: data)
            } catch {
                print("Failed to import theme: \(error)")
            }
        }
    }
}

// MARK: - Editor Settings

struct EditorSettingsView: View {

    @ObservedObject private var themeManager = ThemeManager.shared

    /// Available monospace fonts
    private var monospaceFonts: [String] {
        let fontManager = NSFontManager.shared
        var fonts: [String] = []

        // Get all fixed-pitch fonts
        if let fixedPitchFonts = fontManager.availableFontNames(with: .fixedPitchFontMask) {
            fonts = fixedPitchFonts.sorted()
        }

        // Ensure common programming fonts are at the top
        let preferredFonts = ["SF Mono", "Menlo", "Monaco", "Courier New", "JetBrains Mono", "Fira Code"]
        let preferred = preferredFonts.filter { fonts.contains($0) }
        let others = fonts.filter { !preferredFonts.contains($0) }

        return preferred + others
    }

    var body: some View {
        Form {
            Section {
                Picker("Font", selection: $themeManager.editorFontName) {
                    ForEach(monospaceFonts.prefix(20), id: \.self) { font in
                        Text(font)
                            .font(.custom(font, size: 12))
                            .tag(font)
                    }
                }

                HStack {
                    Text("Size")
                    Slider(value: $themeManager.editorFontSize, in: 10...24, step: 1)
                    Text("\(Int(themeManager.editorFontSize)) pt")
                        .monospacedDigit()
                        .frame(width: 50)
                }
            } header: {
                Text("Editor Font")
            }

            Section {
                Toggle("Live Preview Mode", isOn: $themeManager.livePreviewEnabled)
            } header: {
                Text("Editing Mode")
            } footer: {
                Text("Show formatted preview while editing. Syntax is revealed when the cursor enters a line.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section {
                // Preview of current font settings
                Text("The quick brown fox jumps over the lazy dog.")
                    .font(.custom(themeManager.editorFontName, size: themeManager.editorFontSize))
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
            } header: {
                Text("Preview")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Preview Settings

struct PreviewSettingsView: View {

    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var isEditingCSS = false

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Font Size")
                    Slider(value: $themeManager.previewFontSize, in: 12...24, step: 1)
                    Text("\(Int(themeManager.previewFontSize)) px")
                        .monospacedDigit()
                        .frame(width: 50)
                }

                HStack {
                    Text("Line Height")
                    Slider(value: $themeManager.previewLineHeight, in: 1.2...2.0, step: 0.1)
                    Text(String(format: "%.1f", themeManager.previewLineHeight))
                        .monospacedDigit()
                        .frame(width: 50)
                }
            } header: {
                Text("Typography")
            }

            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Custom CSS")
                        Spacer()
                        Button(themeManager.customCSS.isEmpty ? "Add" : "Edit") {
                            isEditingCSS = true
                        }
                    }

                    if !themeManager.customCSS.isEmpty {
                        Text("\(themeManager.customCSS.count) characters")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Advanced")
            } footer: {
                Text("Custom CSS is applied after the default theme styles. Use CSS variables (--qs-*) for best results.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $isEditingCSS) {
            CSSEditorSheet(css: $themeManager.customCSS)
        }
    }
}

// MARK: - CSS Editor Sheet

struct CSSEditorSheet: View {

    @Binding var css: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Custom CSS")
                    .font(.headline)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()

            Divider()

            // CSS Editor
            TextEditor(text: $css)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: .textBackgroundColor))

            Divider()

            // CSS Variables Reference
            DisclosureGroup("CSS Variables Reference") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("--qs-color-text: Text color")
                        Text("--qs-color-background: Background color")
                        Text("--qs-color-heading: Heading color")
                        Text("--qs-color-link: Link color")
                        Text("--qs-color-code-bg: Code block background")
                        Text("--qs-color-border: Border color")
                        Text("--qs-font-size: Base font size")
                        Text("--qs-line-height: Line height")
                        Text("--qs-font-body: Body font family")
                        Text("--qs-font-mono: Monospace font family")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                }
                .frame(height: 120)
            }
            .padding()
        }
        .frame(width: 500, height: 400)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
