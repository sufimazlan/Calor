//
//  EntryRow.swift
//  Calor
//

import SwiftUI

/// One food entry in the Today list. Photo thumbnails are added in milestone 3.
struct EntryRow: View {
    let entry: FoodEntry

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                if let portion = entry.portion {
                    Text(portion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text("\(entry.calories.formatted()) kcal")
                .font(.callout)
                .monospacedDigit()
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
    }
}
