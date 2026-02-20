import Foundation
import SwiftUI

// MARK: - View Extensions

extension View {
    func cardStyle() -> some View {
        self
            .padding()
            .background(AppColors.surface)
            .cornerRadius(Constants.UI.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            )
            .shadow(color: AppColors.greenMuted.opacity(0.1), radius: 4, x: 0, y: 2)
    }

    func primaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(AppColors.background)
            .frame(maxWidth: .infinity)
            .frame(height: Constants.UI.buttonHeight)
            .background(AppColors.gold)
            .cornerRadius(Constants.UI.cornerRadius)
            .shadow(color: AppColors.gold.opacity(0.3), radius: 8, x: 0, y: 2)
    }

    func secondaryButtonStyle() -> some View {
        self
            .font(.headline)
            .foregroundColor(AppColors.gold)
            .frame(maxWidth: .infinity)
            .frame(height: Constants.UI.buttonHeight)
            .background(AppColors.surface)
            .cornerRadius(Constants.UI.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(AppColors.gold, lineWidth: 1.5)
            )
    }

    func postCardStyle() -> some View {
        self
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: Constants.UI.postCardCornerRadius)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.surfaceElevated.opacity(0.92), AppColors.surface.opacity(0.96)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: Constants.UI.postCardCornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [AppColors.gold.opacity(0.24), AppColors.borderSubtle.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.1
                        )
                }
            )
            .shadow(color: AppColors.backgroundSecondary.opacity(0.35), radius: 12, x: 0, y: 6)
    }

    func modernCapsuleChipStyle(
        foreground: Color = AppColors.textSecondary,
        background: Color = AppColors.surfaceElevated
    ) -> some View {
        self
            .font(.caption2)
            .foregroundColor(foreground)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(background)
            )
    }

    func focusCardStyle() -> some View {
        self
            .padding(Constants.UI.focusHeroPadding)
            .background(
                RoundedRectangle(cornerRadius: Constants.UI.focusCardCornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.surfaceElevated.opacity(0.92), AppColors.surface.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.focusCardCornerRadius)
                    .stroke(
                        LinearGradient(
                            colors: [AppColors.gold.opacity(0.28), AppColors.borderSubtle],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: AppColors.backgroundSecondary.opacity(0.4), radius: 16, x: 0, y: 8)
    }

    func ambientBackgroundLayer() -> some View {
        self
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(AppColors.gold.opacity(Constants.UI.focusAmbientOpacity))
                    .blur(radius: 80)
                    .offset(x: -40, y: -120)
            }
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(AppColors.greenMuted.opacity(Constants.UI.focusAmbientOpacity))
                    .blur(radius: 90)
                    .offset(x: 60, y: 120)
            }
    }

    func goldGlow(radius: CGFloat = 8, opacity: Double = 0.3) -> some View {
        self.shadow(color: AppColors.gold.opacity(opacity), radius: radius, x: 0, y: 0)
    }

    func greenGlow(radius: CGFloat = 4, opacity: Double = 0.1) -> some View {
        self.shadow(color: AppColors.greenMuted.opacity(opacity), radius: radius, x: 0, y: 0)
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - String Extensions

extension String {
    var isValidEmail: Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: self)
    }

    var isNotEmpty: Bool {
        !self.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Date Extensions

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var startOfWeek: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return calendar.date(from: components) ?? self
    }

    var startOfMonth: Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }

    func timeAgoString() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

// MARK: - Int Extensions (Time Formatting)

extension Int {
    var formattedAsTime: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var formattedAsDuration: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Color Extensions

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Optional Extensions

extension Optional where Wrapped == String {
    var orEmpty: String {
        self ?? ""
    }
}

// MARK: - Array Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return [] }

        var chunks: [[Element]] = []
        chunks.reserveCapacity((count + size - 1) / size)

        var index = startIndex
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<end]))
            index = end
        }

        return chunks
    }
}
