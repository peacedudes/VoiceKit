//
//  ContentView.swift
//  ChorusLabApp
//
//  Root content view wrapping ChorusLabView in a NavigationStack.
//

import SwiftUI
import VoiceKit
import VoiceKitUI

/// Root view containing the Chorus Lab interface.
/// Wraps ChorusLabView in a NavigationStack for potential future expansion.
struct ContentView: View {
    var body: some View {
        NavigationStack {
            ChorusLabView()
                .navigationTitle("Chorus Lab")
        }
    }
}

#Preview {
    ContentView()
}
