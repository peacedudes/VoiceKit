//
//  VoicePickerPreviewSelectionTests.swift
//  VoiceKit
//
//  Deterministic FakeTTS voices; force .all; verify hidden toggle.
//

import XCTest
import VoiceKitCore
import VoiceKitUI

@MainActor
final class VoicePickerPreviewSelectionTests: XCTestCase {

    @MainActor
    final class FakeTTS: TTSConfigurable, VoiceListProvider {
        var voices: [TTSVoiceInfo] = []
        var lastSpeakText: String?
        var lastSpeakVoiceID: String?
        var profiles: [String: TTSVoiceProfile] = [:]
        var defaultProfile: TTSVoiceProfile?
        var master: TTSMasterControl = .init()
        nonisolated func availableVoices() -> [TTSVoiceInfo] { MainActor.assumeIsolated { voices } }
        func setVoiceProfile(_ profile: TTSVoiceProfile) { profiles[profile.id] = profile }
        func getVoiceProfile(id: String) -> TTSVoiceProfile? { profiles[id] }
        func setDefaultVoiceProfile(_ profile: TTSVoiceProfile) { defaultProfile = profile }
        func getDefaultVoiceProfile() -> TTSVoiceProfile? { defaultProfile }
        func setMasterControl(_ master: TTSMasterControl) { self.master = master }
        func getMasterControl() -> TTSMasterControl { master }
        func speak(_ text: String, using voiceID: String?) async { lastSpeakText = text; lastSpeakVoiceID = voiceID }
        func stopSpeakingNow() {}
    }

    func testShowHiddenAffectsFilteredVoices() {
        let tts = FakeTTS()
        tts.voices = [
            TTSVoiceInfo(id: "vh", name: "Hidden", language: "en-US"),
            TTSVoiceInfo(id: "vs", name: "Shown", language: "en-US")
        ]
        let store = VoiceProfilesStore(filename: "hidden-\(UUID().uuidString).json")
        let vm = VoicePickerViewModel(tts: tts, store: store)
        vm.refreshAvailableVoices()

        vm.languageFilter = .all
        store.setHidden("vh", true)

        XCTAssertEqual(vm.filteredVoices.map(\.id), ["vs"])

        vm.showHidden = true
        XCTAssertEqual(Set(vm.filteredVoices.map(\.id)), Set(["vh", "vs"]))
    }
}
