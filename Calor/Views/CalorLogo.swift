//
//  CalorLogo.swift
//  Calor
//

import SwiftUI

/// The Calor photo logo and name, shown at the top left of each tab.
/// Tapping it goes to the top of the Today screen.
struct CalorLogoButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image("Logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 28, height: 28)
                    .clipShape(Circle())
                Text("Calor")
                    .font(.headline)
                    .foregroundStyle(.primary)
            }
        }
        .accessibilityLabel("Calor, go to Today")
    }
}

#Preview {
    CalorLogoButton {}
}
