//
//  VoiceListProvider.swift
//  VoiceKitCore
//
//  Tiny protocol for supplying available TTS voices deterministically (used in UI tests).
//

import Foundation

@MainActor
public protocol VoiceListProvider {
    func availableVoices() -> [TTSVoiceInfo]
}
