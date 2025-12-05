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
    // MARK: - Tuner integration
    /// Present the voice tuner to add a new voice.
    /// Seeds the tuner with a random voice from the user's preferred language.
    private mutating func presentAddVoice() {
        vk_editingIndex = nil
        // Use the injected engine factory for testability and consistency.
        vk_tunerEngine = engineFactory()
        // Prefer a random voice from the user’s preferred language; fall back to any.
        let baseLang: String = {
            let tag = Locale.preferredLanguages.first ?? Locale.current.identifier
            if let dash = tag.firstIndex(of: "-") { return String(tag[..<dash]).lowercased() }
            return tag.lowercased()
        }()
        let sameLang = availableVoices().filter {
            let lang = $0.language
            let code: String = {
                if let dash = lang.firstIndex(of: "-") { return String(lang[..<dash]).lowercased() }
                return lang.lowercased()
            }()
            return code == baseLang
        }
        let pool = sameLang.isEmpty ? availableVoices() : sameLang
        if let pick = pool.randomElement() {
            vk_tunerSelection = pick.id
            let seed = TTSVoiceProfile(id: pick.id, rate: _defaultsRate, pitch: _defaultsPitch, volume: _defaultsVolume)
            vk_tunerEngine.setVoiceProfile(seed)
            vk_tunerEngine.setDefaultVoiceProfile(seed)
        } else {
            vk_tunerSelection = nil
        }
        vk_showTuner = true
    }

    private mutating func presentEditVoice(index: Int) {
        guard vk_selectedProfiles.indices.contains(index) else { return }
        vk_editingIndex = index
        vk_tunerEngine = engineFactory()
        // Seed tuner with current profile
        let prof = vk_selectedProfiles[index]
        vk_tunerEngine.setVoiceProfile(prof)
        vk_tunerEngine.setDefaultVoiceProfile(prof) // ensure sliders reflect the current row exactly
        vk_tunerSelection = prof.id
        vk_showTuner = true
    }

    private mutating func applyTunerSelection() {
        guard let id = vk_tunerSelection else { return }
        // Prefer the specific profile returned by the tuner engine; fall back to its default;
        // finally, seed a mid profile if neither is available yet.
        var tuned: TTSVoiceProfile? = vk_tunerEngine.getVoiceProfile(id: id)
        if tuned == nil, let def = vk_tunerEngine.getDefaultVoiceProfile() {
            tuned = TTSVoiceProfile(id: id, rate: def.rate, pitch: def.pitch, volume: def.volume)
        }
        if tuned == nil {
            tuned = TTSVoiceProfile(id: id, rate: _defaultsRate, pitch: _defaultsPitch, volume: _defaultsVolume)
        }
        guard let tuned else { return }
        if let idx = vk_editingIndex, vk_selectedProfiles.indices.contains(idx) {
            // Editing an existing row updates only that row
            vk_selectedProfiles[idx] = tuned
        } else {
            // Always allow duplicates when adding
            vk_selectedProfiles.append(tuned)
        }
        // Clear edit state
        vk_editingIndex = nil
        vk_tunerSelection = nil
        // Keep baseline aligned to effective list
        vk_baseProfiles = vk_selectedProfiles
        // Only re-apply global adjustments if sliders are not at identity.
        // This avoids washing out the very first per-voice edit when the chorus
        // is still at its default global scaling.
        let hasGlobalAdjustments = (vk_rateScale != 1.0) || (vk_pitchOffset != 0.0)
        if hasGlobalAdjustments {
            applyGlobalAdjustments()
        }
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
