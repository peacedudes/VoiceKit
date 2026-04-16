//
//  ChorusLabAppApp.swift
//  ChorusLabApp
//
//  Entry point for the Chorus Lab demo application.
//

import SwiftUI

/// Main app entry point.
/// Presents a single WindowGroup containing the ContentView (ChorusLabView wrapped in a NavigationStack).
@main
struct ChorusLabAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
