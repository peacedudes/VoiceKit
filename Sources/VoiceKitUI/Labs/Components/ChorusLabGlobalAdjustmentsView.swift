//
//  ChorusLabGlobalAdjustmentsView.swift
//  VoiceKitUI
//
//  Extracted from ChorusLabView. Parameterized to avoid depending on private Metrics.
//

import SwiftUI

@MainActor
internal struct ChorusLabGlobalAdjustmentsView: View {
    @Binding var rateScale: Double
    @Binding var pitchOffset: Double
    var speedRange: ClosedRange<Double>
    var pitchOffsetRange: ClosedRange<Double>
    var sliderStep: Double
    var onChange: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            TunerSliderRow(
                title: "Speed",
                systemImage: "speedometer",
                value: $rateScale,
                range: speedRange,
                step: sliderStep,
                formatted: { value in value.asMultiplier() }
            )
            .onChange(of: rateScale) { _, _ in onChange() }

            TunerSliderRow(
                title: "Pitch",
                systemImage: "waveform.path.ecg",
                value: $pitchOffset,
                range: pitchOffsetRange,
                step: sliderStep,
                formatted: { off in (1.0 + off).formatted() }
            )
            .onChange(of: pitchOffset) { _, _ in onChange() }
        }
    }
}
