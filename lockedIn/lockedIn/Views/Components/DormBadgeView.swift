import SwiftUI

enum DormBadgeStyle {
    case full       // Icon + full name + background
    case compact    // Icon + short name
    case iconOnly   // Just the icon in a circle
}

struct DormBadgeView: View {
    let dorm: Dorm
    var style: DormBadgeStyle = .compact

    var body: some View {
        switch style {
        case .full:
            fullBadge
        case .compact:
            compactBadge
        case .iconOnly:
            iconOnlyBadge
        }
    }

    private var fullBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: dorm.icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(dorm.color)

            Text(dorm.displayName)
                .font(.subheadline.weight(.medium))
                .foregroundColor(AppColors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(dorm.color.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(dorm.color.opacity(0.3), lineWidth: 1)
        )
    }

    private var compactBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: dorm.icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(dorm.color)

            Text(dorm.shortName)
                .font(.caption.weight(.medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(dorm.color.opacity(0.1))
        )
    }

    private var iconOnlyBadge: some View {
        ZStack {
            Circle()
                .fill(dorm.color.opacity(0.15))
                .frame(width: 32, height: 32)

            Image(systemName: dorm.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(dorm.color)
        }
    }
}

// MARK: - Dorm Badge for Profile Header

struct ProfileDormBadge: View {
    let dormString: String?

    private var dorm: Dorm? {
        Dorm.from(string: dormString)
    }

    var body: some View {
        if let dorm = dorm {
            DormBadgeView(dorm: dorm, style: .compact)
        } else if let dormString = dormString, !dormString.isEmpty {
            // Fallback for unrecognized dorm strings
            HStack(spacing: 6) {
                Image(systemName: "building.2")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.textTertiary)

                Text(dormString)
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(AppColors.surface)
            )
        }
    }
}

// MARK: - Previews

#Preview("Badge Styles") {
    VStack(spacing: 20) {
        Text("Full Style")
            .font(.caption)
            .foregroundColor(.secondary)
        HStack(spacing: 12) {
            DormBadgeView(dorm: .dillon, style: .full)
            DormBadgeView(dorm: .lyons, style: .full)
        }

        Divider()

        Text("Compact Style")
            .font(.caption)
            .foregroundColor(.secondary)
        HStack(spacing: 12) {
            DormBadgeView(dorm: .dillon, style: .compact)
            DormBadgeView(dorm: .mcglinn, style: .compact)
            DormBadgeView(dorm: .siegfried, style: .compact)
        }

        Divider()

        Text("Icon Only")
            .font(.caption)
            .foregroundColor(.secondary)
        HStack(spacing: 12) {
            DormBadgeView(dorm: .sorin, style: .iconOnly)
            DormBadgeView(dorm: .keenan, style: .iconOnly)
            DormBadgeView(dorm: .fisher, style: .iconOnly)
            DormBadgeView(dorm: .gateway, style: .iconOnly)
        }
    }
    .padding()
    .background(AppColors.background)
}

#Preview("Profile Dorm Badge") {
    VStack(spacing: 16) {
        ProfileDormBadge(dormString: "Dillon Hall")
        ProfileDormBadge(dormString: "BP")
        ProfileDormBadge(dormString: "Some Unknown Dorm")
        ProfileDormBadge(dormString: nil)
    }
    .padding()
    .background(AppColors.background)
}
