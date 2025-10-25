//
//  VoiceChorus+Convenience.swift
//  VoiceKitUI
//
//  Tiny sugar to avoid repeating the existential cast for RealVoiceIO.
//

import Foundation
import VoiceKit

public extension VoiceChorus {
    /// Sensible default: create a chorus that uses a new RealVoiceIO per channel.
    /// Hides the factory closure and protocol cast for casual use.
    @MainActor
    convenience init() {
        self.init(makeEngine: { RealVoiceIO() as (any TTSConfigurable & VoiceIO) })
    }

    /// Create a chorus that uses a new RealVoiceIO per channel.
    @MainActor
    static func real() -> VoiceChorus {
        VoiceChorus(makeEngine: { RealVoiceIO() as (any TTSConfigurable & VoiceIO) })
    }

    /// Create a chorus with your own RealVoiceIO factory (still hiding the existential).
    @MainActor
    static func real(factory: @escaping () -> RealVoiceIO) -> VoiceChorus {
        VoiceChorus(makeEngine: { factory() as (any TTSConfigurable & VoiceIO) })
    }
}
