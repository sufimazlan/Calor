//
//  CalorApp.swift
//  Calor
//
//  Created by Sufi Mazlan on 04/10/2026.
//

import SwiftUI
import SwiftData

@main
struct CalorApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: FoodEntry.self)
    }
}
