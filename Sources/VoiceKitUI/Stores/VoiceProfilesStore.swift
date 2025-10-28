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

    private enum CodingKeys: String, CodingKey { case defaultVoiceID, tuning, profilesByID, activeVoiceIDs, hiddenVoiceIDs }

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

@MainActor
public final class VoiceProfilesStore: ObservableObject {
    @Published public var defaultVoiceID: String?
    @Published public var master: Tuning = .init()
    @Published public var profilesByID: [String: TTSVoiceProfile] = [:]
    @Published public var activeVoiceIDs: Set<String> = []
    @Published public var hiddenVoiceIDs: Set<String> = []

    private let fileURL: URL

    public init(filename: String = "voices.json") {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("VoiceIO", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent(filename)
        load()
    }

    public func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let decoded = try? JSONDecoder().decode(VoiceProfilesFile.self, from: data) {
            self.defaultVoiceID = decoded.defaultVoiceID
            self.master = decoded.tuning
            self.profilesByID = decoded.profilesByID
            self.activeVoiceIDs = Set(decoded.activeVoiceIDs)
            self.hiddenVoiceIDs = Set(decoded.hiddenVoiceIDs)
        }
    }

    // Transitional convenience: prefer 'tuning' from call sites.
    // Proxies to 'master' until the persistence and API are renamed.
    public var tuning: Tuning {
        get { master }
        set { master = newValue }
    }

    public func save() {
        let payload = VoiceProfilesFile(defaultVoiceID: defaultVoiceID, tuning: master, profilesByID: profilesByID, activeVoiceIDs: Array(activeVoiceIDs), hiddenVoiceIDs: Array(hiddenVoiceIDs))
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    public func profile(for info: TTSVoiceInfo) -> TTSVoiceProfile {
        if let profile = profilesByID[info.id] { return profile }
        let profile = TTSVoiceProfile(id: info.id, rate: 0.55, pitch: 1.0, volume: 0.9)
        profilesByID[info.id] = profile
        return profile
    }

    public func setProfile(_ profile: TTSVoiceProfile) { profilesByID[profile.id] = profile }
    public func isActive(_ id: String) -> Bool { activeVoiceIDs.contains(id) }
    public func toggleActive(_ id: String) { if activeVoiceIDs.contains(id) { activeVoiceIDs.remove(id) } else { activeVoiceIDs.insert(id) }; save() }
    public func isHidden(_ id: String) -> Bool { hiddenVoiceIDs.contains(id) }
    public func setHidden(_ id: String, _ hidden: Bool) { if hidden { hiddenVoiceIDs.insert(id) } else { hiddenVoiceIDs.remove(id) }; save() }
}
