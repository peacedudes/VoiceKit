// Copyright (c) VoiceKit contributors
// SPDX-License-Identifier: MIT
//
// Shared clamp helper for numeric-like values.

import Foundation

extension Comparable {
    /// Returns the value limited to the provided closed range.
    /// Example: (1.2).clamped(to: 0.0...1.0) == 1.0
    @inlinable
    public func clamped(to limits: ClosedRange<Self>) -> Self {
        max(limits.lowerBound, min(limits.upperBound, self))
    }
}
