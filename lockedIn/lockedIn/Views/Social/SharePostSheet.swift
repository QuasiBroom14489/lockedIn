import SwiftUI

private enum ComposerStep: Int, CaseIterable {
    case type
    case details
    case preview

    var title: String {
        switch self {
        case .type: return "Post Type"
        case .details: return "Details"
        case .preview: return "Preview"
        }
    }
}

struct SharePostSheet: View {
    @ObservedObject var viewModel: StudyFeedViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var step: ComposerStep = .type
    @State private var postType: StudyPostType = .tip
    @State private var title = ""
    @State private var content = ""
    @State private var tagsText = ""

    @State private var stackItems: [StudyStackItem] = [StudyStackItem(toolName: "", linkURL: nil, usageNote: nil)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        stepIndicator

                        switch step {
                        case .type:
                            typeStep
                        case .details:
                            detailsStep
                        case .preview:
                            previewStep
                        }
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

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(ComposerStep.allCases, id: \.self) { composerStep in
                let isActive = composerStep.rawValue == step.rawValue
                Text(composerStep.title)
                    .font(.caption)
                    .foregroundColor(isActive ? AppColors.background : AppColors.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(isActive ? AppColors.gold : AppColors.surface)
                    )
            }
        }
    }

    private var typeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose what you're sharing")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Picker("Post Type", selection: $postType) {
                Text("Stack").tag(StudyPostType.stack)
                Text("Suggestion").tag(StudyPostType.tip)
            }
            .pickerStyle(.segmented)

            Text(postType == .stack
                 ? "Stack posts show tools, links, and how each tool is used."
                 : "Suggestion posts focus on practical ideas with tags for discovery.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)

            Button("Continue") {
                step = .details
            }
            .primaryButtonStyle()
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Add your content")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
                TextField(postType == .stack ? "Example: Finals prep stack" : "Example: Study suggestion", text: $title)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(postType == .stack ? "Overview" : "Suggestion")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
                TextEditor(text: $content)
                    .frame(minHeight: 110)
                    .padding(6)
                    .background(AppColors.surface)
                    .cornerRadius(Constants.UI.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )
            }

            if postType == .stack {
                stackItemsEditor
            } else {
                suggestionTagsEditor
            }

            HStack(spacing: 10) {
                Button("Back") {
                    step = .type
                }
                .secondaryButtonStyle()

                Button("Preview") {
                    step = .preview
                }
                .primaryButtonStyle()
                .disabled(!isDetailsValid)
            }
        }
    }

    private var stackItemsEditor: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Stack Tools")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Button {
                    stackItems.append(StudyStackItem(toolName: "", linkURL: nil, usageNote: nil))
                } label: {
                    Label("Add Tool", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(AppColors.gold)
            }

            ForEach(Array(stackItems.enumerated()), id: \.element.id) { index, _ in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Tool \(index + 1)")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        if stackItems.count > 1 {
                            Button("Remove") {
                                stackItems.remove(at: index)
                            }
                            .font(.caption)
                            .foregroundColor(AppColors.error)
                        }
                    }

                    TextField("Tool name (required)", text: bindingForStackItem(at: index, keyPath: \.toolName))
                        .textFieldStyle(.roundedBorder)

                    TextField("Link URL (optional)", text: bindingForOptionalStackItem(at: index, keyPath: \.linkURL))
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)

                    TextField("How you use it (optional)", text: bindingForOptionalStackItem(at: index, keyPath: \.usageNote))
                        .textFieldStyle(.roundedBorder)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppColors.surfaceElevated)
                )
            }
        }
    }

    private var suggestionTagsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)
            TextField("active-recall, finals, writing", text: $tagsText)
                .textFieldStyle(.roundedBorder)
            Text("Use comma-separated tags to help others discover this suggestion.")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preview")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            StudyPostRow(
                post: previewPost,
                currentVote: .none,
                isFavorited: false
            )

            HStack(spacing: 10) {
                Button("Back") {
                    step = .details
                }
                .secondaryButtonStyle()

                Button {
                    Task { await submitPost() }
                } label: {
                    if viewModel.isSubmittingPost {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Post")
                    }
                }
                .primaryButtonStyle()
                .disabled(viewModel.isSubmittingPost || !isDetailsValid)
            }
        }
    }

    private var previewPost: StudyPost {
        StudyPost(
            authorId: "preview-author",
            authorName: "You",
            type: postType,
            title: title.trimmed,
            content: content.trimmed,
            stackItems: postType == .stack ? normalizedStackItems : nil,
            tools: postType == .stack ? normalizedStackItems.map(\.toolName) : [],
            tags: normalizedTags
        )
    }

    private var isDetailsValid: Bool {
        guard title.trimmed.isNotEmpty, content.trimmed.isNotEmpty else { return false }
        if postType == .stack {
            return !normalizedStackItems.isEmpty
        }
        return true
    }

    private var normalizedStackItems: [StudyStackItem] {
        stackItems.compactMap { item in
            let toolName = item.toolName.trimmed
            guard toolName.isNotEmpty else { return nil }
            let link = item.linkURL?.trimmed
            let note = item.usageNote?.trimmed
            return StudyStackItem(
                id: item.id,
                toolName: toolName,
                linkURL: link?.isEmpty == true ? nil : link,
                usageNote: note?.isEmpty == true ? nil : note
            )
        }
    }

    private var normalizedTags: [String] {
        tagsText
            .split(separator: ",")
            .map { String($0).trimmed.replacingOccurrences(of: "#", with: "") }
            .filter { $0.isNotEmpty }
    }

    private func submitPost() async {
        viewModel.clearErrorState()

        await viewModel.createPost(
            type: postType,
            title: title,
            content: content,
            stackItems: postType == .stack ? normalizedStackItems : nil,
            tools: postType == .stack ? normalizedStackItems.map(\.toolName) : [],
            tags: normalizedTags
        )

        if !viewModel.showError {
            dismiss()
        }
    }

    private func bindingForStackItem(
        at index: Int,
        keyPath: WritableKeyPath<StudyStackItem, String>
    ) -> Binding<String> {
        Binding(
            get: { stackItems[index][keyPath: keyPath] },
            set: { stackItems[index][keyPath: keyPath] = $0 }
        )
    }

    private func bindingForOptionalStackItem(
        at index: Int,
        keyPath: WritableKeyPath<StudyStackItem, String?>
    ) -> Binding<String> {
        Binding(
            get: { stackItems[index][keyPath: keyPath] ?? "" },
            set: {
                let trimmed = $0.trimmed
                stackItems[index][keyPath: keyPath] = trimmed.isEmpty ? nil : trimmed
            }
        )
    }
}

#Preview {
    SharePostSheet(viewModel: StudyFeedViewModel())
}
