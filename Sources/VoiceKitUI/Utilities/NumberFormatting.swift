//
//  NumberFormatting.swift
//  VoiceKitUI
//
//  Shared, lightweight number formatting helpers.
//  Generic over BinaryFloatingPoint so Float and Double both work.
//

import Foundation

// MARK: - Generic floating-point formatting
public extension BinaryFloatingPoint {
    /// Format with a fixed number of fractional digits and optional suffix.
    /// Example: 0.5.display(decimals: 2) -> "0.5"
    ///          1.2.display(decimals: 2, suffix: "×") -> "1.2×"
    @inlinable
    func display(decimals: Int = 2, suffix: String = "") -> String {
        let places = max(0, decimals)
        // Use a stable English POSIX locale for the numeric part,
        // then trim trailing zeros and any trailing dot, and finally
        // append the suffix (e.g., "s", "×").
        let base = String(
            format: "%.\(places)f",
            locale: Locale(identifier: "en_US_POSIX"),
            Double(self)
        )
        let trimmed = base.replacingOccurrences(
            of: "\\.?0*$", with: "", options: .regularExpression
        )
        return trimmed + suffix
    }
}
