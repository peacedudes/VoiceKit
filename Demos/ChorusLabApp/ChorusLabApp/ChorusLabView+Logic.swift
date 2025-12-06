//
//  ChorusLabView+Logic.swift
//  VoiceKitUI
//
//  Extracted non-visual helpers from ChorusLabView to reduce type body length.
//

import SwiftUI
import VoiceKit
import VoiceKitUI
@MainActor
internal extension ChorusLabView {
    // MARK: - Copy-to-clipboard (chorus setup)
    /// Build minimal Swift one-liners to recreate the current chorus’ voices exactly as tuned,
    /// copy to clipboard, and print to the console.
    func copyChorusSetup() {
        let snippet = makeChorusSnippet(for: vk_selectedProfiles)
        // Print nicely for immediate inspection in console
        print(snippet)
        // And copy to system clipboard
        copyToClipboard(snippet)
    }

    /// Copies text to the system clipboard (platform-aware).
    func copyToClipboard(_ text: String) {
        // Delegate to a small, standalone helper so all platform
        // conditionals live in one place (Clipboard.swift).
        Clipboard.set(text)
    }
}

@MainActor
internal extension ChorusLabView {
    // MARK: - Global adjustments and lookup
    func resolvedName(for id: String) -> String {
        if let voice = availableVoices().first(where: { $0.id == id }) {
            return voice.name
        }
        return "Voice"
    }

    // Apply global sliders to baseline -> effective profiles
    mutating func applyGlobalAdjustments() {
        // Single source of truth for chorus-wide tuning lives in ChorusMath.
        // This keeps the logic consistent between the ChorusLab view and tests.
        guard !vk_baseProfiles.isEmpty else { return }
        vk_selectedProfiles = ChorusMath.applyAdjustments(
            baseProfiles: vk_baseProfiles,
            rateScale: vk_rateScale,
            pitchOffset: vk_pitchOffset
        )
    }
}

@MainActor
internal extension ChorusLabView {
    // MARK: - Play/Stop/Sync
    mutating func startChorus() async {
        vk_isPlaying = true
        let t0 = Date()
        await chorus.speak(vk_customText, withVoiceProfiles: vk_selectedProfiles)
        let elapsed = Date().timeIntervalSince(t0)
        vk_lastChorusSeconds = elapsed
        vk_isPlaying = false
    }

    /// Cancel any in-flight calibration and stop the chorus immediately.
    mutating func stopAll() async {
        // Cancel calibration if running (if any legacy task exists)
        vk_calibrationTask?.cancel()
        vk_calibrationTask = nil
        vk_isCalibrating = false
        // Stop any ongoing chorus playback
        chorus.stop()
        // Reflect stop in UI immediately
        if vk_isPlaying { vk_isPlaying = false }
    }
}
