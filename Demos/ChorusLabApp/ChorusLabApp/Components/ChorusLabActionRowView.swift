//
//  ChorusLabActionRowView.swift
//  VoiceKitUI
//
//  Extracted from ChorusLabView to reduce type length and improve clarity.
//

import SwiftUI

/// Control row for chorus playback and rate synchronization.
///
/// Displays a prominent Play/Stop button on the left and a Synchronize button on the right.
/// During calibration, replaces the Sync button with a progress spinner.
/// Handles accessibility labels and state-driven button coloring (blue for play, red for stop).
@MainActor
public struct ChorusLabActionRowView: View {
    /// Whether the chorus is currently playing. Controls button label and color.
    @Binding var isPlaying: Bool
    /// Whether rate calibration is in progress. Controls button label and progress spinner visibility.
    @Binding var isCalibrating: Bool
    /// Whether there are voices in the chorus. Disables buttons if false.
    var hasSelection: Bool
    /// Callback when the user taps Play (only called when not playing or calibrating).
    var onPlay: () -> Void
    /// Callback when the user taps Stop (only called when playing or calibrating).
    var onStop: () -> Void
    /// Callback when the user taps Synchronize (only called when idle and voices are selected).
    var onSync: () -> Void

    public var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                // Left: Play / Stop, centered in its half
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
                            Text("Play all")
                                .opacity((isPlaying || isCalibrating) ? 0 : 1)
                        }
                        .frame(minWidth: 100, alignment: .leading) // stabilize width
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 4)
                    .accessibilityLabel((isPlaying || isCalibrating) ? "Stop" : "Play all")
                    .accessibilityHint((isPlaying || isCalibrating) ?
                                       "Stop playback and calibration" : "Start playing all voices in the chorus")
                    .accessibilityAddTraits(.isButton)
                }
                .buttonStyle(.borderedProminent)
                .tint((isPlaying || isCalibrating) ? .red : .blue)
                .controlSize(.regular)
                .disabled(!hasSelection && !(isPlaying || isCalibrating))
                .frame(maxWidth: .infinity, alignment: .center)

                // Right: Sync/progress, centered in its half
                if isCalibrating {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Calibrating...").foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
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
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    Spacer().frame(maxWidth: .infinity)
                }
            }
        }
    }
}
