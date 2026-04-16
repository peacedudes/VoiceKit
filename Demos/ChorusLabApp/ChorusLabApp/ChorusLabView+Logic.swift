//
//  ChorusLabView+Logic.swift
//  VoiceKitUI
//
//  Extracted non-visual helpers from ChorusLabView to reduce type body length.
//  Grouped by semantic category: clipboard export, voice lookup, global adjustments, playback control.
//

import SwiftUI
import VoiceKit
import VoiceKitUI

/// Export and clipboard helpers for sharing chorus setups.
@MainActor
internal extension ChorusLabView {
    // MARK: - Copy-to-clipboard (chorus setup export)

    /// Generate a Swift code snippet for the current chorus and copy it to the clipboard.
    /// Useful for embedding tuned chorus setups in apps. The snippet includes phrase,
    /// voice profiles, and exact rate, pitch, and volume values.
    func copyChorusSetup() {
        let snippet = makeChorusSnippet(for: vkSelectedProfiles)
        print(snippet)
        copyToClipboard(snippet)
    }

    /// Copy text to the system clipboard in a platform-aware manner.
    /// - Parameter text: String to copy.
    /// - Note: Delegates to Clipboard.swift so all platform conditionals are centralized.
    func copyToClipboard(_ text: String) {
        Clipboard.set(text)
    }
}

/// Voice lookup and global tuning helpers.
@MainActor
internal extension ChorusLabView {
    // MARK: - Voice lookup and global adjustments

    /// Resolve a voice ID to its human-readable display name.
    /// Looks up the ID in the available voices; falls back to "Voice" if not found.
    /// - Parameter id: TTSVoiceInfo.id.
    /// - Returns: Display name (e.g., "Alex", "Victoria"), or "Voice" if unrecognized.
    func resolvedName(for id: String) -> String {
        if let voice = availableVoices().first(where: { $0.id == id }) {
            return voice.name
        }
        return "Voice"
    }

    /// Recompute effective voice profiles by applying global rate scale and pitch offset to baselines.
    /// This is the single source of truth for chorus-wide tuning; all slider changes flow through this.
    /// The logic is centralized in ChorusMath for testability and consistency.
    mutating func applyGlobalAdjustments() {
        guard !vkBaseProfiles.isEmpty else { return }
        vkSelectedProfiles = ChorusMath.applyAdjustments(
            baseProfiles: vkBaseProfiles,
            rateScale: vkRateScale,
            pitchOffset: vkPitchOffset
        )
    }
}

/// Playback control: start, stop, and synchronization.
@MainActor
internal extension ChorusLabView {
    // MARK: - Playback control

    /// Start playing the chorus with the current voice profiles.
    /// Measures the elapsed time and updates lastChorusSeconds upon completion.
    /// Sets isPlaying=true before speaking and false after.
    mutating func startChorus() async {
        vkIsPlaying = true
        let startTime = Date()
        await chorus.speak(vkCustomText, withVoiceProfiles: vkSelectedProfiles)
        let elapsed = Date().timeIntervalSince(startTime)
        vkLastChorusSeconds = elapsed
        vkIsPlaying = false
    }

    /// Stop the chorus and cancel any in-flight calibration.
    /// Cancels the calibrationTask if running and immediately stops chorus playback via chorus.stop().
    /// Clears all playback and calibration state flags.
    mutating func stopAll() async {
        vkCalibrationTask?.cancel()
        vkCalibrationTask = nil
        vkIsCalibrating = false
        chorus.stop()
        if vkIsPlaying { vkIsPlaying = false }
    }
}
