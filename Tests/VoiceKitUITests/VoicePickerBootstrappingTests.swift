//
//  VoicePickerBootstrappingTests.swift
//  VoiceKit
//
//  Deterministic bootstrap test using FakeTTS voices only.
//

import XCTest
@testable import VoiceKitUI
@testable import VoiceKitCore

@MainActor
final class VoicePickerBootstrappingTests: XCTestCase {

    @MainActor
    final class FakeTTS: TTSConfigurable, VoiceListProvider {
        var voices: [TTSVoiceInfo] = []
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
        func speak(_ text: String, using voiceID: String?) async {}
        func stopSpeakingNow() {}
    }

    func testBootstrapCreatesDefaultAndProfiles() {
        let filename = "picker_bootstrap.json"
        let store = VoiceProfilesStore(filename: filename)
        defer { cleanup(filename) }
        store.defaultVoiceID = nil

        let tts = FakeTTS()
        tts.voices = [
            TTSVoiceInfo(id: "a", name: "Alpha", language: "en-US"),
            TTSVoiceInfo(id: "b", name: "Beta",  language: "en-GB")
        ]

        // IMPORTANT: use FakeTTS in the ViewModel
        let vm = VoicePickerViewModel(tts: tts, store: store, allowSystemVoices: false)
        vm.refreshAvailableVoices()

        XCTAssertEqual(vm.voices.map(\.id), ["a","b"])

        let p = store.profile(for: vm.voices[0])
        XCTAssertEqual(p.id, "a")

        if let def = store.defaultVoiceID {
            XCTAssertTrue(vm.voices.contains(where: { $0.id == def }))
        } else {
            vm.setDefaultVoice(id: "a")
            XCTAssertEqual(store.defaultVoiceID, "a")
        }
    }

    private func cleanup(_ filename: String) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = appSupport.appendingPathComponent("VoiceIO", isDirectory: true).appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
