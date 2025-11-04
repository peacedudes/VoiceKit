//
//  VoiceLanguagePicker.swift
//  VoiceKitUI
//
//  Compact toggle that expands one-way to a full language picker.
//  Extracted from VoiceChooserView to reduce type length and enable reuse.
//

import SwiftUI

@MainActor
internal struct VoiceLanguagePicker: View {
    // State bindings
    @Binding var showFullLanguagePicker: Bool
    @Binding var selection: String // "_current", "_all", or base code like "en"

    // Data
    var currentLanguageName: String
    var languageOptions: [(code: String, name: String)]

    // Intents (parent handles effects)
    var onSetCurrent: () -> Void
    var onExpandToAll: () -> Void

    init(
        showFullLanguagePicker: Binding<Bool>,
        selection: Binding<String>,
        currentLanguageName: String,
        languageOptions: [(code: String, name: String)],
        onSetCurrent: @escaping () -> Void,
        onExpandToAll: @escaping () -> Void
    ) {
        self._showFullLanguagePicker = showFullLanguagePicker
        self._selection = selection
        self.currentLanguageName = currentLanguageName
        self.languageOptions = languageOptions
        self.onSetCurrent = onSetCurrent
        self.onExpandToAll = onExpandToAll
    }

    var body: some View {
        Group {
            if showFullLanguagePicker == false {
                Toggle("\(currentLanguageName) voices", isOn: Binding(
                    get: {
                        // Consider "current" when not expanded.
                        selection == "_current"
                    },
                    set: { newVal in
                        if newVal {
                            // Stick to current language
                            selection = "_current"
                            onSetCurrent()
                        } else {
                            // One-way expansion to full picker; default to All
                            showFullLanguagePicker = true
                            selection = "_all"
                            onExpandToAll()
                        }
                    }
                ))
                #if os(macOS)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                #endif
            } else {
                // Full language picker (same style/padding as voice picker)
                Picker("Language", selection: $selection) {
                    Text(currentLanguageName).tag("_current")
                    Text("All languages").tag("_all")
                    ForEach(languageOptions, id: \.code) { opt in
                        Text(opt.name).tag(opt.code)
                    }
                }
                .pickerStyle(pickerStylePlatform())
                .frame(maxHeight: pickerMaxHeight())
                #if os(macOS)
                .controlSize(.small)
                #endif
            }
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Local platform helpers (mirror VoiceChooserView behavior)
extension VoiceLanguagePicker {
    fileprivate func pickerStylePlatform() -> some PickerStyle {
        #if os(iOS)
        return WheelPickerStyle()
        #else
        return DefaultPickerStyle()
        #endif
    }
    fileprivate func pickerMaxHeight() -> CGFloat? {
        #if os(iOS)
        return 180
        #else
        return nil
        #endif
    }
}

// MARK: - Preview
#if DEBUG
@MainActor
internal struct VoiceLanguagePicker_Previews: PreviewProvider {
    internal static var previews: some View {
        PreviewContainer()
            .frame(width: 420)
            .padding(.vertical, 12)
    }

    private struct PreviewContainer: View {
        @State var showFull: Bool = false
        @State var selection: String = "_current"
        let options: [(code: String, name: String)] = [
            ("en", "English"),
            ("es", "Spanish"),
            ("fr", "French")
        ]
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                VoiceLanguagePicker(
                    showFullLanguagePicker: $showFull,
                    selection: $selection,
                    currentLanguageName: "English",
                    languageOptions: options,
                    onSetCurrent: { /* no-op in preview */ },
                    onExpandToAll: { /* no-op in preview */ }
                )
                Divider()
                Text("Selection: \(selection)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
