//
//  VoiceChorusConvenienceTests.swift
//  VoiceKitUITests
//

import XCTest
@testable import VoiceKitUI
import VoiceKit

@MainActor
final class VoiceChorusConvenienceTests: XCTestCase {

    func testDefaultInit() {
        // Ensure the convenience init is available and links correctly.
        let chorus = VoiceChorus()
        // Just smoke-check a trivial async call path compiles; no audio is executed here.
        _ = chorus // silence unused warning
    }

    func testRealStaticFactory() {
        let chorus = VoiceChorus.real()
        _ = chorus
    }

    func testRealFactoryWithCustom() {
        // Use a closure that constructs a RealVoiceIO, validating the API surface exists.
        // This doesn't touch audio in tests; merely validates the convenience wrapper.
        let chorus = VoiceChorus.real(factory: { RealVoiceIO() })
        _ = chorus
    }
}
