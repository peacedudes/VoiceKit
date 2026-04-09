//
//  VoiceProfilesStore.swift
//  VoiceKitUI
//
//  Originally extracted from the old VoicePickerView; now used by VoiceChooserView.
//  (The picker UI was removed; this store remains the shared persistence layer.)

import SwiftUI
import Foundation
import VoiceKit

public struct VoiceProfilesFile: Codable {
    public var defaultVoiceID: String?
    public var tuning: Tuning
    public var profilesByID: [String: TTSVoiceProfile]
    public var activeVoiceIDs: [String]
    public var hiddenVoiceIDs: [String]

    public init(defaultVoiceID: String? = nil,
                tuning: Tuning = .init(),
                profilesByID: [String: TTSVoiceProfile] = [:],
                activeVoiceIDs: [String] = [],
                hiddenVoiceIDs: [String] = []) {
        self.defaultVoiceID = defaultVoiceID
        self.tuning = tuning
        self.profilesByID = profilesByID
        self.activeVoiceIDs = activeVoiceIDs
        self.hiddenVoiceIDs = hiddenVoiceIDs
    }

    private struct ProfileDTO: Codable {
        var id: String
        var rate: Double
        var pitch: Float
        var volume: Float
    }

    private enum CodingKeys: String, CodingKey {
        case defaultVoiceID, tuning, profilesByID, activeVoiceIDs, hiddenVoiceIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        defaultVoiceID = try container.decodeIfPresent(String.self, forKey: .defaultVoiceID)
        tuning = try container.decode(Tuning.self, forKey: .tuning)
        activeVoiceIDs = try container.decodeIfPresent([String].self, forKey: .activeVoiceIDs) ?? []
        hiddenVoiceIDs = try container.decodeIfPresent([String].self, forKey: .hiddenVoiceIDs) ?? []
        let profileDTOs = try container.decodeIfPresent([String: ProfileDTO].self, forKey: .profilesByID) ?? [:]
        profilesByID = profileDTOs.reduce(into: [:]) { result, entry in
            result[entry.key] = TTSVoiceProfile(
                id: entry.value.id,
                rate: entry.value.rate,
                pitch: entry.value.pitch,
                volume: entry.value.volume
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(defaultVoiceID, forKey: .defaultVoiceID)
        try container.encode(tuning, forKey: .tuning)
        try container.encode(activeVoiceIDs, forKey: .activeVoiceIDs)
        try container.encode(hiddenVoiceIDs, forKey: .hiddenVoiceIDs)
        let dtoByID = profilesByID.mapValues { ProfileDTO(id: $0.id, rate: $0.rate, pitch: $0.pitch, volume: $0.volume) }
        try container.encode(dtoByID, forKey: .profilesByID)
    }
}

/// Persisted voice configuration state.
/// Stores voice profiles, tuning, and UI state (default voice, active/hidden lists).
/// All state is automatically persisted to a JSON file in the app support directory.
@MainActor
public final class VoiceProfilesStore: ObservableObject {
    /// ID of the currently selected default voice (used when speak() is called without a voice id).
    @Published public var defaultVoiceID: String?

    /// Global TTS tuning (rate/pitch/volume variation and scaling).
    @Published public var tuning: Tuning = .init()

    /// All stored voice profiles, keyed by voice id.
    /// Apps typically populate this with system voices or custom voice configurations.
    @Published public var profilesByID: [String: TTSVoiceProfile] = [:]

    /// Set of voice ids marked as "active" (for multi-voice synthesis, e.g., VoiceChorus).
    /// Note: Use reassignment (not direct mutation) to ensure @Published triggers updates.
    @Published public var activeVoiceIDs: Set<String> = []

    /// Set of voice ids marked as "hidden" (filtered out from most UI lists).
    /// Note: Use reassignment (not direct mutation) to ensure @Published triggers updates.
    @Published public var hiddenVoiceIDs: Set<String> = []

    private let fileURL: URL

    /// Initialize the store, creating the app support directory if needed.
    /// Automatically loads persisted state from the file (if it exists).
    ///
    /// - Parameter filename: Name of the JSON file to load/save (default: "voices.json").
    public init(filename: String = "voices.json") {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("VoiceIO", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(filename)
        load()
    }

    /// Load state from the persisted JSON file.
    /// Called automatically on init. Safe to call again to reload (e.g., after external updates).
    public func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(VoiceProfilesFile.self, from: data) {
            self.defaultVoiceID = decoded.defaultVoiceID
            self.tuning = decoded.tuning
            self.profilesByID = decoded.profilesByID
            self.activeVoiceIDs = Set(decoded.activeVoiceIDs)
            self.hiddenVoiceIDs = Set(decoded.hiddenVoiceIDs)
        }
    }

    /// Persist current state to the JSON file atomically.
    /// Called automatically by mutation methods (setProfile, toggleActive, setHidden).
    public func save() {
        let payload = VoiceProfilesFile(
            defaultVoiceID: defaultVoiceID,
            tuning: tuning,
            profilesByID: profilesByID,
            activeVoiceIDs: Array(activeVoiceIDs),
            hiddenVoiceIDs: Array(hiddenVoiceIDs)
        )
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    /// Get or create a voice profile for the given voice info.
    /// If a profile already exists, returns it; otherwise creates one with application defaults
    /// (rate 0.55, pitch 1.0, volume 0.9) and stores it.
    public func profile(for info: TTSVoiceInfo) -> TTSVoiceProfile {
        if let profile = profilesByID[info.id] { return profile }
        let profile = TTSVoiceProfile(id: info.id, rate: 0.55, pitch: 1.0, volume: 0.9)
        profilesByID[info.id] = profile
        return profile
    }

    /// Store or update a voice profile and persist the change.
    public func setProfile(_ profile: TTSVoiceProfile) {
        profilesByID[profile.id] = profile
        save()
    }

    /// Check if a voice id is marked active.
    public func isActive(_ id: String) -> Bool { activeVoiceIDs.contains(id) }

    /// Toggle the active status of a voice id and persist the change.
    /// Note: Mutations use reassignment pattern to ensure @Published triggers updates.
    public func toggleActive(_ id: String) {
        var updated = activeVoiceIDs
        if updated.contains(id) { updated.remove(id) } else { updated.insert(id) }
        activeVoiceIDs = updated
        save()
    }

    /// Check if a voice id is marked hidden.
    public func isHidden(_ id: String) -> Bool { hiddenVoiceIDs.contains(id) }

    /// Set the hidden status of a voice id and persist the change.
    /// Note: Mutations use reassignment pattern to ensure @Published triggers updates.
    public func setHidden(_ id: String, _ hidden: Bool) {
        var updated = hiddenVoiceIDs
        if hidden { updated.insert(id) } else { updated.remove(id) }
        hiddenVoiceIDs = updated
        save()
    }
}
