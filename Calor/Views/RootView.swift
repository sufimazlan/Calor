//
//  RootView.swift
//  Calor
//

import SwiftUI

/// Shows the first-launch questions until a profile exists, then the main tabs.
struct RootView: View {
    enum AppTab: Hashable {
        case today, trends
    }

    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @State private var selectedTab = AppTab.today
    /// Goes up by one each time the logo is tapped, so Today scrolls to the top.
    @State private var homeRequests = 0

    var body: some View {
        if Profile(data: profileData) == nil {
            OnboardingView()
        } else {
            TabView(selection: $selectedTab) {
                Tab("Today", systemImage: "fork.knife", value: AppTab.today) {
                    TodayView(homeRequests: homeRequests, goHome: goHome)
                }
                Tab("Trends", systemImage: "chart.bar.xaxis", value: AppTab.trends) {
                    TrendsView(goHome: goHome)
                }
            }
        }
    }

    private func goHome() {
        selectedTab = .today
        homeRequests += 1
    }
}
