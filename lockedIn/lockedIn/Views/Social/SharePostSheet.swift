import SwiftUI

struct SharePostSheet: View {
    @ObservedObject var viewModel: StudyFeedViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var postType: StudyPostType = .tip
    @State private var title = ""
    @State private var content = ""
    @State private var toolsText = ""
    @State private var tagsText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Post Type", selection: $postType) {
                            ForEach(StudyPostType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Title")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.textSecondary)
                            TextField("Example: My finals prep stack", text: $title)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("What worked for you?")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.textSecondary)
                            TextEditor(text: $content)
                                .frame(minHeight: 120)
                                .padding(6)
                                .background(AppColors.surface)
                                .cornerRadius(Constants.UI.cornerRadius)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                                        .stroke(AppColors.borderSubtle, lineWidth: 1)
                                )
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tools (comma separated)")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.textSecondary)
                            TextField("Anki, Notion, Google Docs", text: $toolsText)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tags (comma separated)")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.textSecondary)
                            TextField("finals, deep-work, active-recall", text: $tagsText)
                                .textFieldStyle(.roundedBorder)
                        }

                        Button {
                            Task { await submitPost() }
                        } label: {
                            if viewModel.isSubmittingPost {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Share Post")
                            }
                        }
                        .primaryButtonStyle()
                        .disabled(viewModel.isSubmittingPost || content.trimmed.isEmpty)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("Share to Feed")
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func submitPost() async {
        viewModel.clearErrorState()

        let tools = toolsText
            .split(separator: ",")
            .map { String($0).trimmed }
            .filter { $0.isNotEmpty }
        let tags = tagsText
            .split(separator: ",")
            .map { String($0).trimmed.replacingOccurrences(of: "#", with: "") }
            .filter { $0.isNotEmpty }

        await viewModel.createPost(
            type: postType,
            title: title,
            content: content,
            tools: tools,
            tags: tags
        )

        if !viewModel.showError {
            dismiss()
        }
    }
}

#Preview {
    SharePostSheet(viewModel: StudyFeedViewModel())
}
