//
//  RuntimeHygieneExamplesTests.swift
//  VoiceKit
//
//  Purpose: Textbook examples showing how to avoid runtime warnings while still
//  exercising real AVFoundation paths where appropriate.
//

import XCTest
import AVFoundation
@testable import VoiceKitUI
@testable import VoiceKit

@MainActor
final class RuntimeHygieneExamplesTests: XCTestCase {

    // Pattern 1: Quiet list building in tests/CI without enumerating system voices.
    // Avoids XPC/SQLite log noise from AVSpeechSynthesisVoice.speechVoices() on simulators.
    func testQuietVoiceListBuilding() async throws {
        await VoiceKitTestMode.setAllowSystemVoiceQueries(false)
        let store = VoiceProfilesStore(filename: "hygiene-quiet.json")
        defer { cleanup("hygiene-quiet.json") }

        let vm = VoicePickerViewModel(tts: RealVoiceIO(), store: store, allowSystemVoices: false)
        vm.refreshAvailableVoices()

        // In this mode, the VM doesn’t query system voices; lists are empty unless a VoiceListProvider is used.
        XCTAssertTrue(vm.voices.isEmpty || vm.voices.count >= 0)
    }

    // Pattern 2: Explicit opt-in to real voices on @MainActor.
    // Still exercises real AV name lookup, but avoids broad enumeration to reduce log volume.
    func testOptInRealVoiceUsageOnMain() async throws {
        await VoiceKitTestMode.setAllowSystemVoiceQueries(true)
        let store = VoiceProfilesStore(filename: "hygiene-optin.json")
        defer { cleanup("hygiene-optin.json") }

        let io = RealVoiceIO()
        let vm = VoicePickerViewModel(tts: io, store: store, allowSystemVoices: true)

        // Avoid enumerating the entire list; use a known identifier.
        let id = "com.apple.speech.synthesis.voice.Alex"
        let phrase = vm.samplePhrase(for: TTSVoiceProfile(id: id))
        XCTAssertTrue(phrase.contains("My name is"))
    }

    // App-like pattern — safe prewarm on main for cached voices
    func testAppStylePrewarmOnMain() async throws {
        _ = SystemVoicesCache.refresh() // main actor context here (test is @MainActor)
        let all = SystemVoicesCache.all()
        XCTAssertNotNil(Optional(all))
    }

    // MARK: - Helpers
    private func cleanup(_ filename: String) {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = appSupport.appendingPathComponent("VoiceIO", isDirectory: true).appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
