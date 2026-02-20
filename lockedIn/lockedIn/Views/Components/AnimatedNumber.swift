import SwiftUI

enum NumberFormat {
    case plain
    case time           // e.g., "2h 30m"
    case abbreviated    // e.g., "1.2K"
    case points         // e.g., "1,234 pts"
    case percentage     // e.g., "75%"
}

struct AnimatedNumber: View {
    let value: Int
    var format: NumberFormat = .plain
    var duration: Double = 1.0
    var font: Font = .title2.bold()
    var color: Color = AppColors.textPrimary

    @State private var displayValue: Int = 0
    @State private var hasAnimated = false

    var body: some View {
        Text(formattedValue)
            .font(font)
            .foregroundColor(color)
            .contentTransition(.numericText())
            .onAppear {
                guard !hasAnimated else { return }
                hasAnimated = true
                animateValue()
            }
            .onChange(of: value) { _, newValue in
                animateValue(to: newValue)
            }
    }

    private var formattedValue: String {
        switch format {
        case .plain:
            return displayValue.formatted()
        case .time:
            return displayValue.formattedAsDuration
        case .abbreviated:
            return abbreviatedNumber(displayValue)
        case .points:
            return "\(displayValue.formatted()) pts"
        case .percentage:
            return "\(displayValue)%"
        }
    }

    private func animateValue(to targetValue: Int? = nil) {
        let target = targetValue ?? value
        let steps = 30
        let stepDuration = duration / Double(steps)

        for step in 0...steps {
            let progress = easeOutQuad(Double(step) / Double(steps))
            let currentValue = Int(Double(target) * progress)

            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(step)) {
                withAnimation(.easeOut(duration: stepDuration)) {
                    displayValue = currentValue
                }
            }
        }
    }

    private func easeOutQuad(_ t: Double) -> Double {
        return 1 - (1 - t) * (1 - t)
    }

    private func abbreviatedNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            return String(format: "%.1fM", Double(num) / 1_000_000)
        } else if num >= 1_000 {
            return String(format: "%.1fK", Double(num) / 1_000)
        }
        return num.formatted()
    }
}

// MARK: - Animated Stat Item

struct AnimatedStatItem: View {
    let icon: String
    let value: Int
    let label: String
    var format: NumberFormat = .plain
    var iconColor: Color = AppColors.gold

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(iconColor)

                AnimatedNumber(
                    value: value,
                    format: format,
                    font: .title2.bold(),
                    color: AppColors.textPrimary
                )
            }

            Text(label)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Previews

#Preview("Animated Numbers") {
    VStack(spacing: 30) {
        AnimatedNumber(value: 12345, format: .plain)
        AnimatedNumber(value: 7200, format: .time)
        AnimatedNumber(value: 15600, format: .abbreviated)
        AnimatedNumber(value: 2500, format: .points)
        AnimatedNumber(value: 75, format: .percentage)
    }
    .padding()
    .background(AppColors.background)
}

#Preview("Stat Items") {
    HStack(spacing: 40) {
        AnimatedStatItem(
            icon: "clock.fill",
            value: 3600,
            label: "Total Time",
            format: .time
        )

        AnimatedStatItem(
            icon: "flame.fill",
            value: 42,
            label: "Hours"
        )
    }
    .padding()
    .background(AppColors.background)
}
