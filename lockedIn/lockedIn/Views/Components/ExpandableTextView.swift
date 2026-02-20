import SwiftUI

struct ExpandableTextView: View {
    let text: String
    let lineLimit: Int

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(text)
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(isExpanded ? nil : lineLimit)

            if shouldShowToggle {
                Button(isExpanded ? "Show less" : "Read more") {
                    isExpanded.toggle()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppColors.gold)
            }
        }
    }

    private var shouldShowToggle: Bool {
        text.count > 180
    }
}

#Preview {
    ExpandableTextView(
        text: "This is a long post body to preview expandable text behavior. Keep writing long enough so read more appears and the expanded state can be toggled.",
        lineLimit: 3
    )
    .padding()
    .background(AppColors.background)
}
