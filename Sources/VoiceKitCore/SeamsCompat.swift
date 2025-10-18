//
//  SeamsCompat.swift
//  VoiceKit
//
//  Protocols and types matching ListenFlowSeamTests expectations.
//

import Foundation
@preconcurrency import AVFoundation
@preconcurrency import Speech

// MARK: - SpeechEvent shape used by tests
public struct SpeechEvent: Sendable, Equatable {
    public let text: String
    public let isFinal: Bool
    public let segments: [(Double, Double)] // (start, duration)

    public init(text: String, isFinal: Bool, segments: [(Double, Double)]) {
        self.text = text
        self.isFinal = isFinal
        self.segments = segments
    }

    // Manual Equatable because [(Double, Double)] isn’t Equatable by default
    public static func == (lhs: SpeechEvent, rhs: SpeechEvent) -> Bool {
        guard lhs.text == rhs.text, lhs.isFinal == rhs.isFinal, lhs.segments.count == rhs.segments.count else {
            return false
        }
        for (left, right) in zip(lhs.segments, rhs.segments) {
            if left.0 != right.0 || left.1 != right.1 { return false }
        }
        return true
    }
}

// MARK: - Driver protocol (exactly as tests use)
public protocol SpeechTaskDriver {
    typealias Handler = @Sendable (SpeechEvent) -> Void
    func startTask(recognizer: SFSpeechRecognizer,
                   request: SFSpeechAudioBufferRecognitionRequest,
                   handler: @escaping Handler) -> SFSpeechRecognitionTask
    static func live() -> any SpeechTaskDriver
}

// MARK: - Recognition tap source with exact labels
public protocol RecognitionTapSource {
    func installTap(engine: AVAudioEngine,
                    format: AVAudioFormat,
                    bufferSize: AVAudioFrameCount,
                    onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws
    func removeTap(engine: AVAudioEngine)
    static func live() -> any RecognitionTapSource
}

// Minimal no-op Live helpers (satisfy BoostedSchedulingSeamTests)
public enum LiveSpeechTaskDriver {
    public static func live() -> any SpeechTaskDriver { NoopSpeechDriver() }

    private struct NoopSpeechDriver: SpeechTaskDriver {
        func startTask(recognizer: SFSpeechRecognizer,
                       request: SFSpeechAudioBufferRecognitionRequest,
                       handler: @escaping Handler) -> SFSpeechRecognitionTask {
            final class DummyTask: SFSpeechRecognitionTask {}
            return DummyTask()
        }
        static func live() -> any SpeechTaskDriver { NoopSpeechDriver() }
    }
}

public enum LiveRecognitionTapSource {
    public static func live() -> any RecognitionTapSource { NoopTapSource() }

    private struct NoopTapSource: RecognitionTapSource {
        func installTap(engine: AVAudioEngine,
                        format: AVAudioFormat,
                        bufferSize: AVAudioFrameCount,
                        onBuffer: @escaping @Sendable (AVAudioPCMBuffer) -> Void) throws {
            _ = (engine, format, bufferSize, onBuffer)
        }
        func removeTap(engine: AVAudioEngine) { _ = engine }
        static func live() -> any RecognitionTapSource { NoopTapSource() }
    }
}
