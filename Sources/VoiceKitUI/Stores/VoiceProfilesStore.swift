//
//  VoiceProfilesStore.swift
//  VoiceKitUI
//
//  Originally extracted from the old VoicePickerView; now used by VoiceChooserView.
//  (The picker UI was removed; this store remains the shared persistence layer.)

import SwiftUI
import Foundation
import VoiceKitCore

public struct VoiceProfilesFile: Codable {
    public var defaultVoiceID: String?
    public var master: TTSMasterControl
    public var profilesByID: [String: TTSVoiceProfile]
    public var activeVoiceIDs: [String]
    public var hiddenVoiceIDs: [String]

    public init(defaultVoiceID: String? = nil,
                master: TTSMasterControl = .init(),
                profilesByID: [String: TTSVoiceProfile] = [:],
                activeVoiceIDs: [String] = [],
                hiddenVoiceIDs: [String] = []) {
        self.defaultVoiceID = defaultVoiceID
        self.master = master
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

    private struct MasterDTO: Codable {
        var rateVariation: Float
        var pitchVariation: Float
        var volume: Float
        init(_ m: TTSMasterControl) {
            rateVariation = m.rateVariation; pitchVariation = m.pitchVariation; volume = m.volume
        }
        func make() -> TTSMasterControl {
            TTSMasterControl(rateVariation: rateVariation, pitchVariation: pitchVariation, volume: volume)
        }
    }

    enum CodingKeys: String, CodingKey { case defaultVoiceID, master, profilesByID, activeVoiceIDs, hiddenVoiceIDs }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        defaultVoiceID = try c.decodeIfPresent(String.self, forKey: .defaultVoiceID)
        master = try c.decode(MasterDTO.self, forKey: .master).make()
        activeVoiceIDs = try c.decodeIfPresent([String].self, forKey: .activeVoiceIDs) ?? []
        hiddenVoiceIDs = try c.decodeIfPresent([String].self, forKey: .hiddenVoiceIDs) ?? []
        let dict = try c.decodeIfPresent([String: ProfileDTO].self, forKey: .profilesByID) ?? [:]
        profilesByID = dict.reduce(into: [:]) { acc, kv in
            acc[kv.key] = TTSVoiceProfile(
                id: kv.value.id,
                rate: kv.value.rate,
                pitch: kv.value.pitch,
                volume: kv.value.volume
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(defaultVoiceID, forKey: .defaultVoiceID)
        try c.encode(MasterDTO(master), forKey: .master)
        try c.encode(activeVoiceIDs, forKey: .activeVoiceIDs)
        try c.encode(hiddenVoiceIDs, forKey: .hiddenVoiceIDs)
        let dict = profilesByID.mapValues { ProfileDTO(id: $0.id, rate: $0.rate, pitch: $0.pitch, volume: $0.volume) }
        try c.encode(dict, forKey: .profilesByID)
    }
}

@MainActor
public final class VoiceProfilesStore: ObservableObject {
    @Published public var defaultVoiceID: String?
    @Published public var master: TTSMasterControl = .init()
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
            self.master = decoded.master
            self.profilesByID = decoded.profilesByID
            self.activeVoiceIDs = Set(decoded.activeVoiceIDs)
            self.hiddenVoiceIDs = Set(decoded.hiddenVoiceIDs)
        }
    }

    public func save() {
        let payload = VoiceProfilesFile(defaultVoiceID: defaultVoiceID, master: master, profilesByID: profilesByID, activeVoiceIDs: Array(activeVoiceIDs), hiddenVoiceIDs: Array(hiddenVoiceIDs))
        if let data = try? JSONEncoder().encode(payload) {
            try? data.write(to: fileURL, options: [.atomic])
        }
    }

    public func profile(for info: TTSVoiceInfo) -> TTSVoiceProfile {
        if let p = profilesByID[info.id] { return p }
        let p = TTSVoiceProfile(id: info.id, rate: 0.55, pitch: 1.0, volume: 0.9)
        profilesByID[info.id] = p
        return p
    }

    public func setProfile(_ p: TTSVoiceProfile) { profilesByID[p.id] = p }
    public func isActive(_ id: String) -> Bool { activeVoiceIDs.contains(id) }
    public func toggleActive(_ id: String) { if activeVoiceIDs.contains(id) { activeVoiceIDs.remove(id) } else { activeVoiceIDs.insert(id) }; save() }
    public func isHidden(_ id: String) -> Bool { hiddenVoiceIDs.contains(id) }
    public func setHidden(_ id: String, _ hidden: Bool) { if hidden { hiddenVoiceIDs.insert(id) } else { hiddenVoiceIDs.remove(id) }; save() }
}
