//
//  RootView.swift
//  Calor
//

import SwiftUI
import SwiftData

/// Shows the first-launch questions until a profile exists, then the main tabs.
struct RootView: View {
    enum AppTab: Hashable {
        case today, history, trends
    }

    @AppStorage(SettingsKey.profile) private var profileData: Data?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.modelContext) private var modelContext
    @State private var selectedTab = AppTab.today
    /// Goes up by one each time the logo is tapped, so Today scrolls to the top.
    @State private var homeRequests = 0

    var body: some View {
        Group {
            content
        }
        .task {
            // Profiles from before weigh-ins existed get a starting weigh-in and plan.
            WeightLog.preparePlan(context: modelContext)
            await ReinstallReminders.reschedule()
            await MealReminders.reschedule()
            await WeighInReminder.reschedule()
            BackupManager.backUpIfNeeded(context: modelContext, minimumAge: 20 * 60 * 60)
            await WeightLog.importFromHealth(context: modelContext)
        }
        .onChange(of: profileData == nil) { _, hasNoProfile in
            // Setup finished, or a backup was restored on the welcome screen.
            if !hasNoProfile {
                WeightLog.preparePlan(context: modelContext)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                // A reinstall from Xcode may bring a new expiry date.
                Task {
                    await ReinstallReminders.reschedule()
                    await MealReminders.reschedule()
                    await WeightLog.importFromHealth(context: modelContext)
                }
                BackupManager.backUpIfNeeded(context: modelContext, minimumAge: 20 * 60 * 60)
            case .background:
                // Capture meals logged since the last backup.
                BackupManager.backUpOnLeave(context: modelContext)
            default:
                break
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if Profile(data: profileData) == nil {
            OnboardingView()
        } else {
            TabView(selection: $selectedTab) {
                Tab("Today", systemImage: "fork.knife", value: AppTab.today) {
                    TodayView(homeRequests: homeRequests, goHome: goHome)
                }
                Tab("History", systemImage: "calendar", value: AppTab.history) {
                    HistoryView(goHome: goHome)
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
