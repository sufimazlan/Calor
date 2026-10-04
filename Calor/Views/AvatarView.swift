//
//  AvatarView.swift
//  Calor
//

import SwiftUI
import UIKit

/// The user's round profile photo. Falls back to their first initial,
/// then to a generic person icon.
struct AvatarView: View {
    let imageData: Data?
    let name: String
    var size: CGFloat = 28

    var body: some View {
        Group {
            if let imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if let initial = name.trimmingCharacters(in: .whitespaces).first {
                Text(String(initial).uppercased())
                    .font(.system(size: size * 0.45, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.accentColor)
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}

/// Avatar and first name, shown at the top right of Today. Opens the profile.
struct UserButton: View {
    @AppStorage(SettingsKey.userName) private var userName = ""
    @AppStorage(SettingsKey.avatarJPEG) private var avatarData: Data?
    let action: () -> Void

    private var firstName: String {
        userName.split(separator: " ").first.map(String.init) ?? ""
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                AvatarView(imageData: avatarData, name: userName, size: 28)
                if !firstName.isEmpty {
                    Text(firstName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
            }
        }
        .accessibilityLabel("Your profile")
    }
}

#Preview {
    HStack(spacing: 20) {
        AvatarView(imageData: nil, name: "", size: 60)
        AvatarView(imageData: nil, name: "Sufi", size: 60)
    }
}
