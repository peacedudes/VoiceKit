//
//  ContentView.swift
//  ChorusLabApp
//
//  Created by robert on 11/17/25.
//

import SwiftUI
import VoiceKit
import VoiceKitUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ChorusLabView()
                .navigationTitle("Chorus Lab")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    ContentView()
}
