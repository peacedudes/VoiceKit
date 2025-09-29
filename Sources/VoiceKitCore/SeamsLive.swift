//
//  SeamsLive.swift
//  VoiceKit
//
//  Single source of truth for seam types used by RealVoiceIO.
//

import Foundation

public protocol BoostedNodesProvider {
    func reset()
    static func live() -> BoostedNodesProvider
}

public struct LiveBoostedNodesProvider: BoostedNodesProvider {
    public static func live() -> BoostedNodesProvider { LiveBoostedNodesProvider() }
    public func reset() {}
}
