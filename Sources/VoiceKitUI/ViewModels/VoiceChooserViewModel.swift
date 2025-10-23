//
//  VoiceChooserViewModel.swift
//  VoiceKitUI
//
//  Minimal ViewModel to support VoiceChooserView and UI tests.
//  Manages available voices, filtering, store updates, and simple preview.
//

import SwiftUI
import AVFoundation
import Foundation
import VoiceKit

@MainActor
public final class VoiceChooserViewModel: ObservableObject {
    public enum LanguageFilter: Equatable {
        case current
        case all
        case specific(String) // base code like "en"
    }

    // Inputs
    private let tts: TTSConfigurable
    private let allowSystemVoices: Bool
    @ObservedObject public private(set) var store: VoiceProfilesStore

    // Published state
    @Published public private(set) var voices: [TTSVoiceInfo] = []
    @Published public var languageFilter: LanguageFilter = .current
    @Published public var showHidden: Bool = false

    // Preview task
    private var previewTask: Task<Void, Never>?

    public init(tts: TTSConfigurable,
                store: VoiceProfilesStore,
                allowSystemVoices: Bool = false) {
        self.tts = tts
        self.store = store
        self.allowSystemVoices = allowSystemVoices
    }

    // Deterministic refresh when a provider is present; otherwise optional system cache.
    public func refreshAvailableVoices() {
        if let provider = tts as? VoiceListProvider {
            self.voices = provider.availableVoices()
            bootstrapProfilesIfNeeded()
            return
        }
        if allowSystemVoices {
            _ = SystemVoicesCache.refresh()
            self.voices = SystemVoicesCache.all()
            bootstrapProfilesIfNeeded()
        } else {
            self.voices = []
        }
    }

    // Filtered view
    public var filteredVoices: [TTSVoiceInfo] {
        let byLanguage: [TTSVoiceInfo] = {
            switch languageFilter {
            case .all:
                return voices
            case .current:
                let base = currentLanguageCode()
                return voices.filter { baseLanguageCode($0.language).lowercased() == base }
            case .specific(let code):
                let base = code.lowercased()
                return voices.filter { baseLanguageCode($0.language).lowercased() == base }
            }
        }()
        if showHidden { return byLanguage }
        let hidden = Set(store.hiddenVoiceIDs)
        return byLanguage.filter { !hidden.contains($0.id) }
    }

    // Store and TTS sync
    public func updateProfile(_ p: TTSVoiceProfile) {
        store.setProfile(p)
    }

    public func setDefaultVoice(id: String) {
        store.defaultVoiceID = id
    }

    public func updateMaster(_ m: TTSMasterControl, previewKind: String? = nil) {
        store.master = m
    }

    public func applyToTTS() {
        tts.setMasterControl(store.master)
        for p in store.profilesByID.values {
            tts.setVoiceProfile(p)
        }
        if let defID = store.defaultVoiceID,
           let def = store.profilesByID[defID] {
            tts.setDefaultVoiceProfile(def)
        }
    }

    // Samples and previews
    public func samplePhrase(for profile: TTSVoiceProfile, suffix: String? = nil) -> String {
        let name = systemDisplayName(for: profile.id) ?? "Voice"
        var s = "My name is \(name)."
        if let suffix { s += " \(suffix)" }
        return s
    }

    public func playPreview(phrase: String, voiceID: String) {
        stopPreview()
        previewTask = Task {
            await tts.speak(phrase, using: voiceID)
        }
    }

    public func stopPreview() {
        previewTask?.cancel()
        previewTask = nil
        if let io = tts as? VoiceIO {
            io.stopAll()
        }
    }

    // MARK: - Helpers
    private func baseLanguageCode(_ tag: String) -> String {
        if let dash = tag.firstIndex(of: "-") { return String(tag[..<dash]) }
        return tag
    }
    private func currentLanguageCode() -> String {
        let tag = Locale.preferredLanguages.first ?? Locale.current.identifier
        return baseLanguageCode(tag).lowercased()
    }

    private func systemDisplayName(for id: String) -> String? {
        AVSpeechSynthesisVoice(identifier: id)?.name
    }

    private func bootstrapProfilesIfNeeded() {
        for v in voices { _ = store.profile(for: v) }
        if store.defaultVoiceID == nil, let first = voices.first {
            store.defaultVoiceID = first.id
        }
    }
}

// Backward name used in tests
public typealias VoicePickerViewModel = VoiceChooserViewModel
