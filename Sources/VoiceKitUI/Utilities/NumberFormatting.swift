//
//  NumberFormatting.swift
//  VoiceKitUI
//
//  Shared, lightweight number formatting helpers.
//  Generic over BinaryFloatingPoint so Float and Double both work.
//

import Foundation

// MARK: - Generic floating-point formatting
internal extension BinaryFloatingPoint {
    /// Format with a fixed number of fractional digits and optional suffix.
    /// Example: 0.5.formatted(decimals: 2) -> "0.50"
    ///          1.2.formatted(decimals: 2, suffix: "×") -> "1.20×"
    @inlinable
    func formatted(decimals: Int = 2, suffix: String = "") -> String {
        let places = max(0, decimals)
        let fmt = "%.\(places)f\(suffix)"
        return String(format: fmt, Double(self))
    }

    /// Format seconds with a fixed number of fractional digits and an "s" suffix.
    /// Example: 1.234.asSeconds(decimals: 2) -> "1.23s"
    @inlinable
    func asSeconds(decimals: Int = 2) -> String {
        formatted(decimals: decimals, suffix: "s")
    }

    /// Format as a multiplier with a fixed number of fractional digits and a "×" suffix.
    /// Example: 1.0.asMultiplier(decimals: 2) -> "1.00×"
    @inlinable
    func asMultiplier(decimals: Int = 2) -> String {
        formatted(decimals: decimals, suffix: "×")
    }
}
