//
//  RealVoiceIO+TTSConformance.swift
//  VoiceKitCore
//
//  Declares AVSpeechSynthesizerDelegate conformance in a plain (nonisolated) extension.
//  Implementations live in RealVoiceIO+TTSImpl.swift and marshal to @MainActor.
//
//  Created by OpenAI (GPT) for rdoggett on 2025-09-18.
//

import Foundation
@preconcurrency import AVFoundation

extension RealVoiceIO: AVSpeechSynthesizerDelegate {}
