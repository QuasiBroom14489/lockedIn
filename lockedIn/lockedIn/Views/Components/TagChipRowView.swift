import SwiftUI

struct TagChipRowView: View {
    let tags: [String]

    var body: some View {
        if !tags.isEmpty {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 8)], alignment: .leading, spacing: 8) {
                ForEach(tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .modernCapsuleChipStyle(
                            foreground: AppColors.textSecondary,
                            background: AppColors.surface.opacity(0.85)
                        )
                }
            }
        }
    }
}

#Preview {
    TagChipRowView(tags: ["focus", "midterms", "active-recall", "math"])
        .padding()
        .background(AppColors.background)
}
