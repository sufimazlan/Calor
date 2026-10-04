//
//  RootView.swift
//  Calor
//

import SwiftUI

struct RootView: View {
    var body: some View {
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
