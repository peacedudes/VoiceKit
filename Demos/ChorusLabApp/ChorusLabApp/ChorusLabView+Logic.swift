//
//  ChorusLabView+Logic.swift
//  VoiceKitUI
//
//  Extracted non-visual helpers from ChorusLabView to reduce type body length.
//

import SwiftUI
import VoiceKit
import VoiceKitUI

#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

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
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #elseif canImport(AppKit)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        #endif
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
        guard !vk_baseProfiles.isEmpty else { return }
        vk_selectedProfiles = vk_baseProfiles.map { base in
            var profile = base
            // Amplified relative mapping (Double)
            let baseRate: Double = profile.rate
            let newRate: Double = {
                if vk_rateScale >= 1.0 {
                    // 1.0→2.0 maps to t: 0…1, push toward 1.0 by headroom
                    let factor = max(0.0, min(1.0, vk_rateScale - 1.0))
                    return (baseRate + (1.0 - baseRate) * factor).clamped(to: 0.0...1.0)
                } else {
                    // 1.0→0.25 maps to t: 0…1, pull toward 0.0 by fraction of current
                    let factor = max(0.0, min(1.0, (1.0 - vk_rateScale) / _slowRange))
                    return (baseRate - baseRate * factor).clamped(to: 0.0...1.0)
                }
            }()
            profile.rate = newRate
            profile.pitch = (profile.pitch + Float(vk_pitchOffset)).clamped(to: _pitchClampLo..._pitchClampHi)
            return profile
        }
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
        // Keep baseline aligned to effective list, then re-apply globals
        vk_baseProfiles = vk_selectedProfiles
        // Re-apply global adjustments so effective profiles reflect sliders
        applyGlobalAdjustments()
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
