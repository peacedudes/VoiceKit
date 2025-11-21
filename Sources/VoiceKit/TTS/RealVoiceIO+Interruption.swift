//
//  RealVoiceIO+Interruption.swift
//  VoiceKit
//
//  iOS/tvOS/watchOS-only AVAudioSession interruption handling.
//  Entirely excluded on macOS where AVAudioSession is unavailable.
//

#if canImport(AVFAudio) && !os(macOS)

import Foundation
import AVFoundation

@MainActor
extension RealVoiceIO {

    // MARK: - Associated flags (objc storage keeps it simple)

    private static var _wasInterruptedKey: UInt8 = 0
    private static var _wasPlayingClipKey: UInt8 = 0

    private var wasInterrupted: Bool {
        get {
            (objc_getAssociatedObject(self, &RealVoiceIO._wasInterruptedKey) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &RealVoiceIO._wasInterruptedKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    private var wasPlayingClip: Bool {
        get {
            (objc_getAssociatedObject(self, &RealVoiceIO._wasPlayingClipKey) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &RealVoiceIO._wasPlayingClipKey,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    // MARK: - Public wiring

    public func startObservingInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let (typeRaw, optionRaw) = RealVoiceIO.extractInterruption(note.userInfo ?? [:])
            guard let self else { return }
            Task { @MainActor in
                self.handleInterruption(typeRaw: typeRaw, optionRaw: optionRaw)
            }
        }

        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance(),
            queue: .main
        ) { [weak self] note in
            let reasonRaw = RealVoiceIO.extractRouteChange(note.userInfo ?? [:])
            guard let self else { return }
            Task { @MainActor in
                self.handleRouteChange(reasonRaw: reasonRaw)
            }
        }
    }

    public func stopObservingInterruptions() {
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.interruptionNotification, object: AVAudioSession.sharedInstance())
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: AVAudioSession.sharedInstance())
    }

    nonisolated private static func extractInterruption(_ userInfo: [AnyHashable: Any]) -> (type: UInt?, option: UInt?) {
        let type = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt
        let option = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
        return (type, option)
    }

    nonisolated private static func extractRouteChange(_ userInfo: [AnyHashable: Any]) -> UInt? {
        return userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt
    }

    // MARK: - Handlers

    private func handleInterruption(typeRaw: UInt?, optionRaw: UInt?) {
        guard let typeRaw, let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }

        switch type {
        case .began:
            wasInterrupted = true
            wasPlayingClip = (clipPlayer?.isPlaying ?? false)
            if wasPlayingClip { clipPlayer?.stop() }
            synthesizer?.stopSpeaking(at: .immediate)

        case .ended:
            let shouldResume = optionRaw.map { AVAudioSession.InterruptionOptions(rawValue: $0).contains(.shouldResume) } ?? false
            if wasInterrupted {
                wasInterrupted = false
                if shouldResume {
                    try? AVAudioSession.sharedInstance().setActive(true)
                    if wasPlayingClip { clipPlayer?.play() }
                }
                wasPlayingClip = false
            }

        @unknown default:
            break
        }
    }

    private func handleRouteChange(reasonRaw: UInt?) {
        guard let reasonRaw,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }

        if reason == .oldDeviceUnavailable {
            if clipPlayer?.isPlaying == true {
                clipPlayer?.stop()
                boostedProvider.reset()
                let waiters = clipWaiters
                clipWaiters.removeAll()
                for waiter in waiters {
                    waiter.resume(throwing: SimpleError("Route changed"))
                }
            }
        }
    }
}

#endif
