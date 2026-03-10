//
//  VoiceTempoCalibrator.swift
//  VoiceKit
//
//  Calibrates a voice's speaking rate to fit a target duration for a sample phrase.
//

import Foundation

// MARK: - Calibration interface

/// Seam for types that can measure speaking time and configure voice profiles.
/// Abstracts away RealVoiceIO specifics, enabling testability.
@MainActor
public protocol TempoMeasurable: TTSConfigurable {
    /// Speak text using the given voice and return measured duration (wall-clock from didStart to didFinish).
    /// CI/fallback paths may return 0.
    func speakAndMeasure(_ text: String, using voiceID: String?) async -> TimeInterval
    /// Stop any in-flight speech immediately.
    func stopAll()
}

@MainActor
public enum VoiceTempoCalibrator {

    /// Adjusts the rate of the specified voice so that speaking `phrase` takes close to `targetSeconds`.
    ///
    /// **Note on punctuation**: AVSpeechSynthesis resets rate/pitch after sentence-ending punctuation (.!?),
    /// causing post-punctuation text to ignore calibration. This is handled transparently by RealVoiceIO's
    /// speakAndMeasure() method, which normalizes punctuation automatically for all utterances.
    ///
    /// - Parameters:
    ///   - io: Any type conforming to TempoMeasurable (e.g., RealVoiceIO).
    ///   - voiceID: System voice identifier to calibrate.
    ///   - phrase: Sample text used for measurement (keep this fixed across voices).
    ///   - targetSeconds: Desired duration in seconds (e.g., 5.0).
    ///   - tolerance: Allowed absolute error in seconds before stopping (default 0.05).
    ///   - maxIterations: Max adjustment passes (default 3).
    ///   - bounds: Allowed rate bounds (default 0...1).
    /// - Returns: (finalRate, measuredDuration)
    /// - onIteration: Optional progress callback invoked once per iteration with:
    ///   (iterationIndex, measuredSeconds, nextRateCandidate).
    @discardableResult
    public static func fitRate(
        io: some TempoMeasurable,
        voiceID: String,
        phrase: String,
        targetSeconds: TimeInterval,
        tolerance: TimeInterval = 0.05,
        maxIterations: Int = 3,
        bounds: ClosedRange<Double> = 0.0...1.0,
        onIteration: ((Int, TimeInterval, Double) -> Void)? = nil
    ) async -> (finalRate: Double, measured: TimeInterval) {

        // Current profile (or a new one) for this voice
        var profile = io.getVoiceProfile(id: voiceID) ?? {
            // Seed from default if present; otherwise a reasonable mid value
            let seed = io.getDefaultVoiceProfile()?.rate ?? 0.55
            return TTSVoiceProfile(id: voiceID, rate: seed, pitch: 1.0, volume: 1.0)
        }()
        io.setVoiceProfile(profile)

        var lastMeasured: TimeInterval = 0
        // Track history for linear interpolation (learned rate prediction)
        var history: [(rate: Double, measured: TimeInterval)] = []

        for i in 0..<maxIterations {
            // Allow callers to cancel calibration (e.g. a "Stop" button).
            if Task.isCancelled {
                io.stopAll()
                break
            }

            // Measure
            lastMeasured = await io.speakAndMeasure(phrase, using: voiceID)
            if Task.isCancelled { break }

            // CI / fallback safety: if measurement is zero, stop adjustments
            if lastMeasured <= 0 {
                onIteration?(i, lastMeasured, profile.rate)
                break
            }

            // Add to history for learning
            history.append((profile.rate, lastMeasured))

            // Compute next rate candidate relative to target
            let current = profile.rate
            var nextRate = current

            // Check tolerance
            if abs(lastMeasured - targetSeconds) <= tolerance {
                onIteration?(i, lastMeasured, current)
                break
            }

            // Smart rate prediction using history (learned linear relationship).
            // If we have 2+ measurements, use linear interpolation to predict the needed rate.
            var candidateRate: Double
            var hasInterpolation = false

            if history.count >= 2 {
                let prev = history[history.count - 2]
                let curr = history[history.count - 1]
                let rateChange = curr.rate - prev.rate
                let measuredChange = curr.measured - prev.measured

                // Linear model: measured ≈ a + b*rate
                // Slope = how much duration changes per unit rate change
                if abs(rateChange) > 0.0001 && abs(measuredChange) > 0.0001 {
                    let slope = measuredChange / rateChange
                    // Predict: solve for rate where measured = targetSeconds
                    // targetSeconds = curr.measured + slope * (rate - curr.rate)
                    // rate = curr.rate + (targetSeconds - curr.measured) / slope
                    let predicted = curr.rate + (targetSeconds - curr.measured) / slope
                    // Use predicted rate, but blend with proportional for stability
                    let proportional = current * (lastMeasured / max(targetSeconds, 0.0001))
                    candidateRate = predicted * 0.6 + proportional * 0.4
                    hasInterpolation = true
                } else {
                    // Rates or measurements haven’t changed; use proportional
                    candidateRate = current * (lastMeasured / max(targetSeconds, 0.0001))
                }
            } else {
                // First iteration: use simple proportional (full strength, no damping)
                candidateRate = current * (lastMeasured / max(targetSeconds, 0.0001))
            }

            // Apply gentle damping only when we have interpolation history (prevents oscillation).
            // On iteration 1, use full candidate (no damping needed).
            if hasInterpolation {
                // Blend: stay 60% toward current, move 40% toward candidate
                nextRate = current * 0.6 + candidateRate * 0.4
            } else {
                // First iteration or no good history: use candidate at full strength
                nextRate = candidateRate
            }

            // Clamp and safety
            if nextRate.isNaN || !nextRate.isFinite { nextRate = current }
            nextRate = min(max(nextRate, bounds.lowerBound), bounds.upperBound)

            // If the change is negligible, stop to avoid micro-churn
            if abs(nextRate - current) < 0.001 {
                onIteration?(i, lastMeasured, current)
                break
            }

            // Report progress this pass (with the candidate we’ll use next)
            onIteration?(i, lastMeasured, nextRate)

            // Apply and try again
            profile.rate = nextRate
            io.setVoiceProfile(profile)
        }

        return (profile.rate, lastMeasured)
    }
}
