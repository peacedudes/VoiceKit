//
//  ChorusLabSelectedVoiceRow.swift
//  VoiceKitUI
//
//  Extracted from ChorusLabView. Includes small helper cells.
//

import SwiftUI

@MainActor
internal struct ChorusLabSelectedVoiceRow: View {
    let name: String
    let rate: Double
    let pitch: Float
    let volume: Float
    let duration: TimeInterval?
    let isCalibrating: Bool
    let timingCellWidth: CGFloat

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            // Name (left)
            Text(name)
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
                .allowsTightening(true)
                .truncationMode(.tail)
                .layoutPriority(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityLabel("Voice name")
                .accessibilityValue(Text(name))

            Spacer(minLength: 0)

            // Details (middle)
            DetailsCell(rate: rate, pitch: pitch, volume: volume)
                .accessibilityLabel("Voice settings")
                .accessibilityValue(Text(String(format: "Speed %.2f, Pitch %.2f, Volume %.2f",
                                                rate, pitch, volume)))

            // Timing (right)
            DurationCell(duration: duration, isHighlighted: isCalibrating, width: timingCellWidth)
                .accessibilityLabel("Last duration")
                .accessibilityValue(Text(duration.map { String(format: "%.2fs", $0) } ?? "Not measured"))

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(width: 6, alignment: .trailing)
                .accessibilityHidden(true)
        }
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Small helper cells
@MainActor
private struct DetailsCell: View {
    let rate: Double
    let pitch: Float
    let volume: Float
    var body: some View {
        Text(String(format: "Speed %.2f · Pitch %.2f · Vol %.2f",
                    rate, pitch, volume))
            .font(.caption2)
            .foregroundStyle(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.9)
            .allowsTightening(true)
            .truncationMode(.tail)
            .frame(width: 190, alignment: .trailing)
    }
}

@MainActor
private struct DurationCell: View {
    let duration: TimeInterval?
    let isHighlighted: Bool
    let width: CGFloat
    var body: some View {
        let text = duration.map { String(format: "%.2fs", $0) } ?? ""
        Text(text)
            .font(.footnote)
            .monospacedDigit()
            .foregroundStyle(duration == nil ? .secondary : .primary)
            .frame(width: width, alignment: .trailing)
            .padding(.vertical, 2)
            .background {
                if isHighlighted {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.green.opacity(0.18))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isHighlighted)
    }
}
