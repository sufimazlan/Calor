//
//  OnboardingIllustrations.swift
//  Calor
//

import SwiftUI
import UIKit

/// Phone mockup of the camera scanning a meal, for the welcome screen.
struct ScanMockup: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 44)
            .fill(
                LinearGradient(colors: [Color(red: 0.36, green: 0.27, blue: 0.20),
                                        Color(red: 0.16, green: 0.12, blue: 0.10)],
                               startPoint: .top, endPoint: .bottom)
            )
            .overlay {
                VStack(spacing: 18) {
                    Spacer()
                    Text("🍛")
                        .font(.system(size: 110))
                        .padding(28)
                        .overlay { ScanCorners().stroke(.white, style: StrokeStyle(lineWidth: 3, lineCap: .round)) }
                    Spacer()
                    HStack(spacing: 14) {
                        Label("Scan food", systemImage: "viewfinder")
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(.white, in: Capsule())
                            .foregroundStyle(.black)
                        Image(systemName: "photo")
                        Image(systemName: "square.and.pencil")
                    }
                    .foregroundStyle(.white)
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .frame(width: 58, height: 58)
                        .padding(.bottom, 24)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 44)
                    .stroke(Color.black, lineWidth: 10)
            }
            .frame(width: 240, height: 420)
            .shadow(color: .black.opacity(0.15), radius: 20, y: 10)
            .accessibilityHidden(true)
    }
}

/// Four corner brackets of a camera viewfinder.
private struct ScanCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let length = min(rect.width, rect.height) * 0.22
        var path = Path()
        for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0),
                                 (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                 (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0),
                                 (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
            path.move(to: CGPoint(x: corner.x, y: corner.y + dy * length))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x + dx * length, y: corner.y))
        }
        return path
    }
}

/// "Weight trend": steady line with Calor vs. a bounce-back line without a plan.
struct WeightTrendCard: View {
    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Weight trend")
                    .font(.title3.weight(.medium))
                ZStack(alignment: .topLeading) {
                    GeometryReader { geometry in
                        let w = geometry.size.width
                        let h = geometry.size.height
                        // Without a plan: dips, then climbs back above the start.
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: h * 0.12))
                            path.addCurve(to: CGPoint(x: w * 0.45, y: h * 0.55),
                                          control1: CGPoint(x: w * 0.2, y: h * 0.12),
                                          control2: CGPoint(x: w * 0.32, y: h * 0.6))
                            path.addCurve(to: CGPoint(x: w, y: 0),
                                          control1: CGPoint(x: w * 0.62, y: h * 0.45),
                                          control2: CGPoint(x: w * 0.8, y: 0))
                        }
                        .stroke(Color.red.opacity(0.6), lineWidth: 2)
                        // With Calor: steady decline.
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: h * 0.12))
                            path.addCurve(to: CGPoint(x: w, y: h * 0.9),
                                          control1: CGPoint(x: w * 0.45, y: h * 0.12),
                                          control2: CGPoint(x: w * 0.55, y: h * 0.9))
                        }
                        .stroke(Color.primary, lineWidth: 2.5)
                        Text("Without a plan")
                            .font(.caption)
                            .position(x: w * 0.78, y: h * 0.28)
                        Label("Calor", systemImage: "fork.knife")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemBackground), in: Capsule())
                            .position(x: w * 0.16, y: h * 0.82)
                    }
                }
                .frame(height: 150)
                HStack {
                    Text("Month 1")
                    Spacer()
                    Text("Month 6")
                }
                .font(.caption)
                Text("Track your habits and stay consistent over time.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weight trend: steady progress with Calor, weight bouncing back without a plan.")
    }
}

/// "Without Calor" vs "With Calor" bars.
struct SimplerWayCard: View {
    var body: some View {
        SoftCard {
            VStack(spacing: 20) {
                HStack(alignment: .bottom, spacing: 18) {
                    column(title: "Without\nCalor", height: 70, filled: false)
                    column(title: "With\nCalor", height: 170, filled: true)
                }
                Label("Small daily actions lead to progress", systemImage: "checkmark")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("With Calor, small daily actions lead to more progress.")
    }

    private func column(title: String, height: CGFloat, filled: Bool) -> some View {
        VStack(spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .multilineTextAlignment(.center)
            RoundedRectangle(cornerRadius: 16)
                .fill(filled ? Color.primary : Color(.systemGray4))
                .frame(width: 96, height: height)
                .overlay(alignment: .bottom) {
                    Image(systemName: filled ? "person.badge.shield.checkmark" : "person")
                        .font(.title3)
                        .foregroundStyle(filled ? Color(.systemBackground) : .primary)
                        .padding(.bottom, 14)
                }
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.8), in: .rect(cornerRadius: 20))
    }
}

/// "Your weight transition": slow start, then picking up, with a trophy at the end.
struct WeightTransitionCard: View {
    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Your weight transition")
                    .font(.title3.weight(.medium))
                GeometryReader { geometry in
                    let w = geometry.size.width
                    let h = geometry.size.height
                    let points = [CGPoint(x: 0, y: h * 0.75), CGPoint(x: w * 0.27, y: h * 0.7),
                                  CGPoint(x: w * 0.53, y: h * 0.38), CGPoint(x: w, y: h * 0.02)]
                    let curve = Path { path in
                        path.move(to: points[0])
                        path.addLine(to: points[1])
                        path.addCurve(to: points[2], control1: CGPoint(x: w * 0.38, y: h * 0.7),
                                      control2: CGPoint(x: w * 0.42, y: h * 0.45))
                        path.addCurve(to: points[3], control1: CGPoint(x: w * 0.7, y: h * 0.25),
                                      control2: CGPoint(x: w * 0.85, y: h * 0.05))
                    }
                    ZStack {
                        curve
                            .stroke(OnboardingStyle.accent, lineWidth: 2.5)
                        ForEach(0..<3) { index in
                            Circle()
                                .fill(Color(.systemBackground))
                                .overlay(Circle().stroke(Color.primary, lineWidth: 1.5))
                                .frame(width: 12, height: 12)
                                .position(points[index])
                        }
                        Image(systemName: "trophy.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(OnboardingStyle.accent, in: Circle())
                            .position(points[3])
                    }
                }
                .frame(height: 150)
                HStack {
                    Text("3 days")
                    Spacer()
                    Text("7 days")
                    Spacer()
                    Text("30 days")
                }
                .font(.caption)
                Text("Weight change takes time. Consistency in the early weeks matters most.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Progress starts slowly and picks up after the first weeks.")
    }
}

/// Yesterday's leftover calories carried into today.
struct RolloverIllustration: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            card(day: "Yesterday", eaten: 1450, goal: 1600, extra: nil)
            card(day: "Today", eaten: 1450, goal: 1600, extra: 150)
                .padding(.top, 50)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("150 calories left yesterday are added to today.")
    }

    private func card(day: String, eaten: Int, goal: Int, extra: Int?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(day, systemImage: "flame.fill")
                .font(.subheadline)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(eaten.formatted())
                    .font(.title.bold())
                Text("/\(goal.formatted())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let extra {
                Label("+\(extra)", systemImage: "arrow.uturn.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.12), in: Capsule())
            }
            Text(extra == nil ? "150 left" : "150 + \(extra ?? 0) left")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.black, in: .rect(cornerRadius: 8))
        }
        .padding(16)
        .frame(width: 160, alignment: .leading)
        .background(Color(.systemBackground), in: .rect(cornerRadius: 20))
        .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
    }
}

/// Mock notification prompt for the reminders screen.
struct ReminderMockup: View {
    var body: some View {
        VStack(spacing: 14) {
            Text("Calor would like to send you reminders to log your meals")
                .font(.headline)
                .multilineTextAlignment(.center)
            HStack(spacing: 10) {
                Text("Don't Allow")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5), in: Capsule())
                Text("Allow")
                    .bold()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray5), in: Capsule())
                    .overlay(alignment: .bottomTrailing) {
                        Text("👆").font(.title).offset(x: 6, y: 26)
                    }
            }
            .font(.subheadline)
        }
        .padding(22)
        .background(.regularMaterial, in: .rect(cornerRadius: 28))
        .shadow(color: .black.opacity(0.12), radius: 20, y: 8)
        .padding(.horizontal, 24)
        .accessibilityHidden(true)
    }
}

/// A hand-drawn style badge for the "all done" screen.
struct CelebrationBadge: View {
    var body: some View {
        ZStack {
            Circle()
                .stroke(
                    AngularGradient(colors: [.pink.opacity(0.3), .blue.opacity(0.3), .pink.opacity(0.3)],
                                    center: .center),
                    lineWidth: 26
                )
            Image(systemName: "hands.clap")
                .font(.system(size: 72, weight: .light))
        }
        .frame(width: 200, height: 200)
        .accessibilityHidden(true)
    }
}

/// Estimated progress from today's weight to the target, for the plan screen.
struct GoalCurveCard: View {
    let startLabel: String
    let endLabel: String
    let targetText: String
    let isLosing: Bool

    var body: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Estimated progress")
                    .font(.headline)
                GeometryReader { geometry in
                    let w = geometry.size.width
                    let h = geometry.size.height
                    let start = CGPoint(x: 6, y: isLosing ? h * 0.08 : h * 0.92)
                    let end = CGPoint(x: w - 6, y: isLosing ? h * 0.92 : h * 0.08)
                    let curve = Path { path in
                        path.move(to: start)
                        path.addCurve(to: end, control1: CGPoint(x: w * 0.45, y: start.y),
                                      control2: CGPoint(x: w * 0.6, y: end.y))
                    }
                    ZStack {
                        curve
                            .stroke(Color.primary, lineWidth: 2)
                        Circle().fill(Color(.systemBackground))
                            .overlay(Circle().stroke(Color.primary, lineWidth: 1.5))
                            .frame(width: 12, height: 12)
                            .position(start)
                        Circle().fill(Color(.systemBackground))
                            .overlay(Circle().stroke(Color.primary, lineWidth: 1.5))
                            .frame(width: 12, height: 12)
                            .position(end)
                        VStack(spacing: 0) {
                            Text("Target")
                            Text(targetText).bold()
                        }
                        .font(.caption)
                        .padding(6)
                        .background(Color(.systemBackground), in: .rect(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary, lineWidth: 1))
                        .position(x: end.x - 40, y: isLosing ? end.y - 34 : end.y + 34)
                    }
                }
                .frame(height: 120)
                HStack {
                    Text(startLabel)
                    Spacer()
                    Text(endLabel)
                }
                .font(.caption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estimated progress from \(startLabel) to \(targetText) by \(endLabel).")
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 24) {
            ScanMockup()
            WeightTrendCard()
            SimplerWayCard()
            WeightTransitionCard()
            RolloverIllustration()
            ReminderMockup()
            CelebrationBadge()
            GoalCurveCard(startLabel: "Now", endLabel: "20 Dec", targetText: "80 kg", isLosing: true)
        }
        .padding()
    }
}
