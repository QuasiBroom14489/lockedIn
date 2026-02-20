import SwiftUI

struct ToolChipRowView: View {
    let tools: [String]

    var body: some View {
        if !tools.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tools, id: \.self) { tool in
                        Text(tool)
                            .modernCapsuleChipStyle(
                                foreground: AppColors.greenLight,
                                background: AppColors.greenMuted.opacity(0.22)
                            )
                    }
                }
            }
        }
    }
}

#Preview {
    ToolChipRowView(tools: ["Anki", "Notion", "Forest"])
        .padding()
        .background(AppColors.background)
}
