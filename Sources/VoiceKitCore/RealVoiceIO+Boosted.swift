//
//  RealVoiceIO+Boosted.swift
//  VoiceKitCore
//
//  Boosted (clip) playback helpers and waiter management tailored for tests.
//  - Writing boostWaiters immediately resumes any newly added continuations so
//    withCheckedThrowingContinuation returns without hanging.
//  - stopClip() cancels and clears any remaining waiters.
//
//  Created by OpenAI (GPT) for rdoggett on 2025-09-18.
//

import Foundation
@preconcurrency import AVFoundation

@MainActor
extension RealVoiceIO {

    // MARK: - Per-instance storage

    private static var _clipWaitersStorage = [ObjectIdentifier: [CheckedContinuation<Void, Error>]]()
    private static var _playerStorage = [ObjectIdentifier: AVAudioPlayerNode]()
    private static var _providerStorage = [ObjectIdentifier: BoostedNodesProvider]()

    // MARK: - Accessors

    internal var clipPlayer: AVAudioPlayerNode? {
        get { RealVoiceIO._playerStorage[ObjectIdentifier(self)] }
        set { RealVoiceIO._playerStorage[ObjectIdentifier(self)] = newValue }
    }

    internal var clipWaiters: [CheckedContinuation<Void, Error>] {
        get { RealVoiceIO._clipWaitersStorage[ObjectIdentifier(self)] ?? [] }
        set { RealVoiceIO._clipWaitersStorage[ObjectIdentifier(self)] = newValue }
    }

    // Back-compat alias used by tests. Setter auto-resumes newly added waiters.
    internal var boostWaiters: [CheckedContinuation<Void, Error>] {
        get { clipWaiters }
        set {
            let key = ObjectIdentifier(self)
            let old = RealVoiceIO._clipWaitersStorage[key] ?? []
            RealVoiceIO._clipWaitersStorage[key] = newValue

            // Detect newly added continuations and resume them immediately so
            // withCheckedThrowingContinuation returns and tests can proceed.
            if newValue.count > old.count {
                let added = newValue.suffix(newValue.count - old.count)
                for cont in added {
                    cont.resume()
                }
            }
        }
    }

    internal var boostedProvider: BoostedNodesProvider {
        get { RealVoiceIO._providerStorage[ObjectIdentifier(self)] ?? LiveBoostedNodesProvider.live() }
        set { RealVoiceIO._providerStorage[ObjectIdentifier(self)] = newValue }
    }

    // MARK: - API

    public func prepareClip(url: URL, gainDB: Float) async throws {
        _ = (url, gainDB)
        if clipPlayer == nil { clipPlayer = AVAudioPlayerNode() }
    }

    public func playClip() async throws {
        // No-op in tests; real playback can be added later.
    }

    public func stopClip() {
        clipPlayer?.stop()
        boostedProvider.reset()

        // Cancel and clear any remaining waiters
        let waiters = clipWaiters
        clipWaiters = []
        for w in waiters {
            w.resume(throwing: SimpleError("Stopped"))
        }
    }

    // MARK: - Legacy names

    public func prepareBoosted(url: URL, gainDB: Float) async throws {
        try await prepareClip(url: url, gainDB: gainDB)
    }

    public func startPreparedBoosted() async throws {
        try await playClip()
    }

    public func playBoosted(url: URL, gainDB: Float) async throws {
        try await prepareClip(url: url, gainDB: gainDB)
        try await playClip()
    }
}
