import SwiftUI

struct CollapsibleStackItemsView: View {
    let items: [StudyStackItem]
    let collapsedCount: Int

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Study Stack")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.gold)

            ForEach(visibleItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(item.toolName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.textPrimary)

                        Spacer()

                        if let linkURL = item.linkURL,
                           let url = URL(string: linkURL),
                           linkURL.isNotEmpty {
                            Link(destination: url) {
                                Label("Open", systemImage: "arrow.up.right")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundColor(AppColors.gold)
                            }
                        }
                    }

                    if let usageNote = item.usageNote, usageNote.isNotEmpty {
                        Text(usageNote)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(AppColors.surface.opacity(0.7))
                )
            }

            if items.count > collapsedCount {
                Button(isExpanded ? "Show less" : "Show all tools") {
                    isExpanded.toggle()
                }
                .buttonStyle(.plain)
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.gold)
            }
        }
    }

    private var visibleItems: [StudyStackItem] {
        if isExpanded {
            return items
        }
        return Array(items.prefix(collapsedCount))
    }
}

#Preview {
    CollapsibleStackItemsView(items: StudyPost.preview.stackItems ?? [], collapsedCount: 2)
        .padding()
        .background(AppColors.background)
}
