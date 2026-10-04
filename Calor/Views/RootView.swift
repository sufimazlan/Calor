//
//  RootView.swift
//  Calor
//

import SwiftUI

/// Shows the first-launch questions until a profile exists, then the main tabs.
struct RootView: View {
    @AppStorage(SettingsKey.profile) private var profileData: Data?

    var body: some View {
        if Profile(data: profileData) == nil {
            OnboardingView()
        } else {
            TabView {
                Tab("Today", systemImage: "fork.knife") {
                    TodayView()
                }
                Tab("Trends", systemImage: "chart.bar.xaxis") {
                    TrendsView()
                }
            }
        }
    }
}
