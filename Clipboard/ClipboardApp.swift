//
//  ClipboardApp.swift
//  Clipboard
//
//  Created by Muhammed Ali Can on 14.03.2024.
//

import SwiftUI

@main
struct ClipboardApp: App {
    var body: some Scene {
        MenuBarExtra("Clipboard", systemImage: "clipboard.fill") {
            ContentView()
        }.menuBarExtraStyle(.window)
    }
}
