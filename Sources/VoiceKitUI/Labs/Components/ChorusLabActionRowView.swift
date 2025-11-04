//
//  ChorusLabActionRowView.swift
//  VoiceKitUI
//
//  Extracted from ChorusLabView to reduce type length and improve clarity.
//

import SwiftUI

@MainActor
internal struct ChorusLabActionRowView: View {
    @Binding var isPlaying: Bool
    @Binding var isCalibrating: Bool
    var hasSelection: Bool
    var onPlay: () -> Void
    var onStop: () -> Void
    var onSync: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    if isPlaying || isCalibrating { onStop() } else { onPlay() }
                } label: {
                    HStack(spacing: 6) {
                        ZStack {
                            Image(systemName: "stop.fill")
                                .opacity((isPlaying || isCalibrating) ? 1 : 0)
                            Image(systemName: "play.fill")
                                .opacity((isPlaying || isCalibrating) ? 0 : 1)
                        }
                        ZStack {
                            Text("Stop")
                                .opacity((isPlaying || isCalibrating) ? 1 : 0)
                            Text("Play Chorus")
                                .opacity((isPlaying || isCalibrating) ? 0 : 1)
                        }
                        .frame(minWidth: 100, alignment: .leading) // stabilize width
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .accessibilityLabel((isPlaying || isCalibrating) ? "Stop" : "Play Chorus")
                    .accessibilityHint((isPlaying || isCalibrating) ?
                                       "Stop playback and calibration" : "Start playing all voices")
                    .accessibilityAddTraits(.isButton)
                }
                .buttonStyle(.borderedProminent)
                .tint((isPlaying || isCalibrating) ? .red : .blue)
                .controlSize(.regular)
                .disabled(!hasSelection && !(isPlaying || isCalibrating))

                if isCalibrating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Calibrating…").foregroundStyle(.secondary)
                    }
                } else if !isPlaying {
                    Button { onSync() } label: {
                        Label("Synchronize", systemImage: "metronome.fill")
                    }
                    .accessibilityIdentifier("vk.syncAll")
                    .buttonStyle(.bordered)
                    .tint(.secondary)
                    .controlSize(.small)
                    .accessibilityLabel("Synchronize all")
                    .accessibilityHint("Calibrate all voices to the target time")
                    .disabled(!hasSelection || isCalibrating || isPlaying)
                }
                Spacer()
            }
        }
    }
}
