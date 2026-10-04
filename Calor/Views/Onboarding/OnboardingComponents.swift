//
//  OnboardingComponents.swift
//  Calor
//

import SwiftUI
import UIKit

/// Shared look for the setup screens: black and white, big bold titles,
/// outlined option cards and a black pill button.
enum OnboardingStyle {
    /// Warm highlight for "Recommended", goal amounts and months.
    static let accent = Color(red: 0.80, green: 0.56, blue: 0.40)
    static let cardBorder = Color(.systemGray5)
    static let softFill = Color(.systemGray6)
}

/// Round back button and thin progress line at the top of each setup screen.
struct OnboardingTopBar: View {
    let progress: Double
    let showsBack: Bool
    let onBack: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                Image(systemName: "arrow.left")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(OnboardingStyle.softFill, in: Circle())
            }
            .opacity(showsBack ? 1 : 0)
            .disabled(!showsBack)
            .accessibilityLabel("Back")

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5))
                    Capsule().fill(Color.primary)
                        .frame(width: geometry.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 3)
            .animation(.easeInOut, value: progress)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

/// Big bold title with an optional grey subtitle.
struct OnboardingTitle: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 32, weight: .bold))
                .fixedSize(horizontal: false, vertical: true)
            if let subtitle {
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Full-width black pill. Grey while disabled.
struct PrimaryPillButton: View {
    let title: String
    var systemImage: String?
    var isEnabled = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.headline)
            .foregroundStyle(isEnabled ? Color(.systemBackground) : .white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(isEnabled ? Color.primary : Color(.systemGray3), in: Capsule())
        }
        .disabled(!isEnabled)
    }
}

/// Outlined option with an icon in a grey circle and a radio button.
struct OptionCard<Icon: View>: View {
    let title: String
    var detail: String?
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                icon()
                    .frame(width: 44, height: 44)
                    .background(OnboardingStyle.softFill, in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .multilineTextAlignment(.leading)
                    if let detail {
                        Text(detail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
                    }
                }
                Spacer(minLength: 8)
                RadioDot(isSelected: isSelected)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemBackground), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.primary : OnboardingStyle.cardBorder,
                            lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

extension OptionCard where Icon == SymbolIcon {
    /// Option card with an SF Symbol icon.
    init(title: String, detail: String? = nil, symbol: String, isSelected: Bool, action: @escaping () -> Void) {
        self.init(title: title, detail: detail, isSelected: isSelected, action: action) {
            SymbolIcon(name: symbol)
        }
    }
}

struct SymbolIcon: View {
    let name: String

    var body: some View {
        Image(systemName: name)
            .font(.body)
            .foregroundStyle(.primary)
    }
}

struct RadioDot: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Color.primary : Color(.systemGray3), lineWidth: 1.5)
            if isSelected {
                Circle().fill(Color.primary)
                Circle().fill(Color(.systemBackground)).padding(8)
            }
        }
        .frame(width: 24, height: 24)
    }
}

/// 1, 3 or 6 dots, for the workouts-per-week options.
struct DotsIcon: View {
    let count: Int

    var body: some View {
        let dot = Circle().fill(Color.primary)
        switch count {
        case 1:
            dot.frame(width: 10, height: 10)
        case 3:
            VStack(spacing: 2) {
                dot.frame(width: 7, height: 7)
                HStack(spacing: 4) {
                    dot.frame(width: 7, height: 7)
                    dot.frame(width: 7, height: 7)
                }
            }
        default:
            Grid(horizontalSpacing: 4, verticalSpacing: 3) {
                ForEach(0..<min(count, 6) / 2, id: \.self) { _ in
                    GridRow {
                        dot.frame(width: 5, height: 5)
                        dot.frame(width: 5, height: 5)
                    }
                }
            }
        }
    }
}

/// Small segmented control for unit choices, e.g. "ft, in" | "cm".
struct UnitToggle: View {
    let left: String
    let right: String
    @Binding var isLeft: Bool

    var body: some View {
        Picker("Units", selection: $isLeft) {
            Text(left).tag(true)
            Text(right).tag(false)
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
        .frame(maxWidth: .infinity)
    }
}

/// Rounded grey card used for illustrations and summaries.
struct SoftCard<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(OnboardingStyle.softFill.opacity(0.7), in: .rect(cornerRadius: 24))
    }
}
