//
//  WeightRuler.swift
//  Calor
//

import SwiftUI

/// Horizontal ruler you swipe to pick a weight, with a tick every 0.1
/// and a fixed marker in the middle.
struct WeightRuler: View {
    /// Weight in the units shown on the ruler (kg or lb).
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step = 0.1

    @State private var index: Int?

    private let tickSpacing: CGFloat = 9

    init(value: Binding<Double>, range: ClosedRange<Double>, step: Double = 0.1) {
        _value = value
        self.range = range
        self.step = step
        let clamped = min(max(value.wrappedValue, range.lowerBound), range.upperBound)
        _index = State(initialValue: Int(((clamped - range.lowerBound) / step).rounded()))
    }

    private var tickCount: Int {
        Int(((range.upperBound - range.lowerBound) / step).rounded())
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .bottom, spacing: 0) {
                    ForEach(0...tickCount, id: \.self) { tick in
                        Rectangle()
                            .fill(Color.secondary)
                            .frame(width: tick % 10 == 0 ? 1.5 : 1,
                                   height: tick % 10 == 0 ? 44 : (tick % 5 == 0 ? 32 : 22))
                            .frame(width: tickSpacing, height: 56, alignment: .bottom)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, geometry.size.width / 2 - tickSpacing / 2, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $index, anchor: .center)
            .overlay(alignment: .bottom) {
                Capsule()
                    .fill(Color.primary)
                    .frame(width: 3, height: 64)
                    .allowsHitTesting(false)
            }
        }
        .frame(height: 64)
        .sensoryFeedback(.selection, trigger: index)
        .onChange(of: index) { _, newIndex in
            guard let newIndex else { return }
            value = range.lowerBound + Double(newIndex) * step
        }
        .accessibilityElement()
        .accessibilityLabel("Weight")
        .accessibilityValue(value.formatted(.number.precision(.fractionLength(1))))
        .accessibilityAdjustableAction { direction in
            let current = index ?? 0
            index = direction == .increment ? min(current + 1, tickCount) : max(current - 1, 0)
        }
    }
}

#Preview {
    @Previewable @State var weight = 90.0
    VStack {
        Text(weight, format: .number.precision(.fractionLength(1)))
            .font(.largeTitle.bold())
        WeightRuler(value: $weight, range: 30...250)
    }
}
