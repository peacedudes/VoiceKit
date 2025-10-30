//
//  VoiceChooserFilteringTests.swift
//  VoiceKit
//
//  Deterministic FakeTTS voices; force .all to avoid locale dependence.
//

import XCTest
import VoiceKit
import VoiceKitUI

@MainActor
final class VoiceChooserFilteringTests: XCTestCase {

    @MainActor
    final class FakeTTS: TTSConfigurable, VoiceListProvider {
        var voices: [TTSVoiceInfo] = []

        nonisolated func availableVoices() -> [TTSVoiceInfo] { MainActor.assumeIsolated { voices } }
        func setVoiceProfile(_ profile: TTSVoiceProfile) {}
        func getVoiceProfile(id: String) -> TTSVoiceProfile? { nil }
        func setDefaultVoiceProfile(_ profile: TTSVoiceProfile) {}
        func getDefaultVoiceProfile() -> TTSVoiceProfile? { nil }
        func setTuning(_ tuning: Tuning) {}
        func getTuning() -> Tuning { .init() }
        func speak(_ text: String, using voiceID: String?) async {}
        func stopSpeakingNow() {}
    }

    func testLanguageFilterAndHidden() {
        let fake = FakeTTS()
        fake.voices = [
            TTSVoiceInfo(id: "v1", name: "Alpha", language: "en-US"),
            TTSVoiceInfo(id: "v2", name: "Beta", language: "en-GB"),
            TTSVoiceInfo(id: "v3", name: "Gamma", language: "fr-FR")
        ]

        let store = VoiceProfilesStore(filename: "filter-\(UUID().uuidString).json")
        let vm = VoiceChooserViewModel(tts: fake, store: store)
        vm.refreshAvailableVoices()

        vm.languageFilter = .all
        XCTAssertEqual(Set(vm.filteredVoices.map(\.id)), Set(["v1", "v2", "v3"]))

        store.setHidden("v2", true)
        XCTAssertEqual(Set(vm.filteredVoices.map(\.id)), Set(["v1", "v3"]))

        vm.showHidden = true
        XCTAssertEqual(Set(vm.filteredVoices.map(\.id)), Set(["v1", "v2", "v3"]))

        store.setHidden("v1", true)
        XCTAssertEqual(Set(vm.filteredVoices.map(\.id)), Set(["v1", "v2", "v3"]))

        vm.showHidden = false
        XCTAssertEqual(Set(vm.filteredVoices.map(\.id)), Set(["v3"]))
    }
}
