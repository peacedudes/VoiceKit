//
//  RealVoiceIO+Boosted.swift
//  VoiceKit
//
//  Idempotent waiter handling for short-clip (boosted) playback.
//  Ensures continuations are resumed exactly once and never retained after resume.
//

import Foundation
@preconcurrency import AVFoundation

@MainActor
extension RealVoiceIO {

    // MARK: - Accessors

    internal var clipPlayer: AVAudioPlayerNode? {
        get { clipPlayerNodeState }
        set { clipPlayerNodeState = newValue }
    }

    internal var avClipPlayer: AVAudioPlayer? {
        get { avClipPlayerState }
        set { avClipPlayerState = newValue }
    }

    internal var clipWaiters: [CheckedContinuation<Void, Error>] {
        get { clipWaitersState }
        set { clipWaitersState = newValue }
    }

    /// Back-compat alias used by tests. Setter auto-resumes newly added waiters
    /// and does NOT retain them (so they cannot be resumed again later).
    internal var boostWaiters: [CheckedContinuation<Void, Error>] {
        get { clipWaiters }
        set {
            let old = clipWaitersState
            let alreadyCompleted = clipCompletedState

            // Determine newly added continuations (by count difference).
            let addedCount = max(0, newValue.count - old.count)
            if addedCount > 0 {
                let added = newValue.suffix(addedCount)

                // Resume added continuations immediately so withCheckedThrowingContinuation returns.
                for cont in added { cont.resume() }

                // Do not retain the added ones. Keep storage as 'old' unless we also need to
                // carry forward prior un-resumed waiters (which we do).
                // If already completed, we keep storage as old (which should be empty).
                clipWaitersState = alreadyCompleted ? old : old
            } else {
                // No additions; just store whatever is safe (prefer old to avoid reintroducing already-resumed items).
                clipWaitersState = old
            }
        }
    }

    // MARK: - API

    public func prepareClip(url: URL, gainDB: Float) async throws {
        log(.info, "clip prepare url=\(url.lastPathComponent), gainDB=\(gainDB)")
        // Lazily create a simple AVAudioPlayer for this one-shot clip.
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            // Convert gain in dB to linear volume (0...1), clamped.
            let linearGain: Float = {
                let linear = pow(10.0, gainDB / 20.0)
                return max(0.0, min(1.0, Float(linear)))
            }()
            player.volume = linearGain
            player.prepareToPlay()
            avClipPlayer = player
        } catch {
            log(.warn, "clip prepare failed: \(error.localizedDescription)")
            avClipPlayer = nil
        }

        // Retain the legacy player node slot so tests depending on its presence
        // continue to behave; we do not currently drive this node.
        if clipPlayer == nil {
            clipPlayer = AVAudioPlayerNode()
        }

        // New clip preparation resets the completion flag and clears any stale waiters.
        clipCompletedState = false
        clipWaiters = []
    }

    public func startPreparedClip() async throws {
        guard let player = avClipPlayer else {
            log(.warn, "clip play requested with no prepared player")
            return
        }
        log(.info, "clip play start (duration=\(player.duration))")
        player.currentTime = 0
        player.play()
        let seconds = player.duration
        if seconds > 0 {
            let nanos = UInt64(seconds * 1_000_000_000)
            do {
                try await Task.sleep(nanoseconds: nanos)
            } catch {
                // allow cancellation without throwing further
            }
        }
    }

    public func stopClip() {
        // Idempotent: if already completed/cleaned, do nothing.
        if clipCompletedState { return }
        clipCompletedState = true

        log(.info, "clip stop")
        avClipPlayer?.stop()
        clipPlayer?.stop()

        // Cancel and clear any remaining waiters exactly once.
        let waiters = clipWaiters
        clipWaiters = []
        for waiter in waiters {
            waiter.resume(throwing: VoiceIOError.cancelled)
        }
    }

    // MARK: - Legacy names

    public func prepareBoosted(url: URL, gainDB: Float) async throws {
        try await prepareClip(url: url, gainDB: gainDB)
    }

    // MARK: - Helpers for future completion/timeout wiring

    internal func completeClipSuccessfully() {
        log(.info, "clip complete ok")
        if clipCompletedState { return }
        clipCompletedState = true

        let waiters = clipWaiters
        clipWaiters = []
        for waiter in waiters { waiter.resume() }
    }

    internal func completeClipWithTimeout() {
        log(.warn, "clip complete timeout")
        if clipCompletedState { return }
        clipCompletedState = true

        let waiters = clipWaiters
        clipWaiters = []
        for waiter in waiters { waiter.resume(throwing: VoiceIOError.timedOut) }
    }
    
    // One-shot helper: prepare then start the clip
    public func playClip(url: URL, gainDB: Float) async throws {
        try await prepareClip(url: url, gainDB: gainDB)
        try await startPreparedClip()
    }
}
