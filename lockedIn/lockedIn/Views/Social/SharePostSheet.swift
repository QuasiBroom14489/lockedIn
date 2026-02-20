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
    @State private var tagTokens: [String] = []
    @State private var suggestedClasses: [GlobalClass] = []
    @State private var classSearchQuery = ""
    @State private var selectedClassKeys = Set<String>()
    @State private var isLoadingClasses = false
    @State private var classSelectionError: String?
    @State private var suggestedTools: [GlobalTool] = []
    @State private var popularTools: [GlobalTool] = []
    @State private var userTools: [String] = []
    @State private var toolSearchQuery = ""
    @State private var isLoadingTools = false
    @State private var toolSelectionError: String?

    @State private var stackItems: [StudyStackItem] = [StudyStackItem(toolName: "", linkURL: nil, usageNote: nil)]

    private let firebaseService = FirebaseService.shared
    private let authService = AuthService.shared

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
            .task {
                await loadAvailableClasses()
                await loadAvailableTools()
            }
        }
    }

    private var stepIndicator: some View {
        HStack(spacing: 8) {
            ForEach(ComposerStep.allCases, id: \.self) { composerStep in
                let isActive = composerStep.rawValue == step.rawValue
                Text(composerStep.title)
                    .font(.caption.weight(.semibold))
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

            HStack(spacing: 12) {
                typeSelectionCard(
                    type: .stack,
                    title: "Stack",
                    subtitle: "Structured workflow",
                    detail: "Best for tool-driven routines with short notes and links."
                )

                typeSelectionCard(
                    type: .tip,
                    title: "Suggestion",
                    subtitle: "Quick strategy",
                    detail: "Best for concise study ideas with tags for discovery."
                )
            }

            Text(postType == .stack
                 ? "Stack posts work best when each tool has a clear role in your flow."
                 : "Suggestion posts should be concise, practical, and easy to apply.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)

            Button("Continue") {
                step = .details
            }
            .primaryButtonStyle()
        }
    }

    private func typeSelectionCard(type: StudyPostType, title: String, subtitle: String, detail: String) -> some View {
        let isSelected = postType == type

        return Button {
            postType = type
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(AppColors.textPrimary)

                    Spacer(minLength: 0)

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isSelected ? AppColors.gold : AppColors.textTertiary)
                }

                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isSelected ? AppColors.gold : AppColors.textSecondary)

                Text(detail)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? AppColors.surfaceElevated : AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? AppColors.gold.opacity(0.7) : AppColors.borderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add your content")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            sectionCard(title: "Title", subtitle: "Required") {
                TextField(postType == .stack ? "Example: Finals prep stack" : "Example: Study suggestion", text: $title)
                    .modernInputField()
                if title.trimmed.isEmpty {
                    validationText("A title is required.")
                }
            }

            sectionCard(title: postType == .stack ? "Overview" : "Suggestion", subtitle: "Required") {
                TextEditor(text: $content)
                    .frame(minHeight: 120)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.surface)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )

                if content.trimmed.isEmpty {
                    validationText("Add the core idea before previewing.")
                }
            }

            if postType == .stack {
                stackItemsEditor
            } else {
                suggestionTagsEditor
            }

            classSelectorSection

            HStack(spacing: 10) {
                Button("Back") {
                    step = .type
                }
                .secondaryButtonStyle()

                Button("Preview") {
                    commitPendingTagInput()
                    step = .preview
                }
                .primaryButtonStyle()
                .disabled(!isDetailsValid)
            }
        }
    }

    private var stackItemsEditor: some View {
        sectionCard(title: "Stack Tools", subtitle: "At least one required") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Spacer()
                    Button {
                        stackItems.append(StudyStackItem(toolName: "", linkURL: nil, usageNote: nil))
                    } label: {
                        Label("Add Tool", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(AppColors.gold)
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 8) {
                    TextField("Search tools (e.g. Notion, Obsidian)", text: $toolSearchQuery)
                        .modernInputField()
                        .onChange(of: toolSearchQuery) { _, newValue in
                            Task { await loadAvailableTools(query: newValue) }
                        }

                    if isLoadingTools {
                        ProgressView()
                            .tint(AppColors.gold)
                    } else {
                        if !userTools.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Your Tools")
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.textSecondary)
                                FlowLayout(spacing: 8) {
                                    ForEach(userTools, id: \.self) { tool in
                                        toolChip(title: tool) {
                                            addToolToStack(tool)
                                        }
                                    }
                                }
                            }
                        }

                        if !popularTools.isEmpty && toolSearchQuery.trimmed.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Popular on lockedIn")
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.textSecondary)
                                FlowLayout(spacing: 8) {
                                    ForEach(popularTools.prefix(8), id: \.id) { tool in
                                        toolChip(title: tool.displayName) {
                                            addToolToStack(tool.displayName)
                                        }
                                    }
                                }
                            }
                        }

                        if !suggestedTools.isEmpty && toolSearchQuery.trimmed.isNotEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Search Results")
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.textSecondary)
                                FlowLayout(spacing: 8) {
                                    ForEach(suggestedTools, id: \.id) { tool in
                                        toolChip(title: tool.displayName) {
                                            addToolToStack(tool.displayName)
                                        }
                                    }
                                }
                            }
                        } else if toolSearchQuery.trimmed.isNotEmpty {
                            Button {
                                Task { await addCustomToolFromSearch() }
                            } label: {
                                Label("Add \"\(toolSearchQuery.trimmed)\" to stack", systemImage: "plus.circle.fill")
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.gold)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if let toolSelectionError, toolSelectionError.isNotEmpty {
                        validationText(toolSelectionError)
                    }
                }

                ForEach(Array(stackItems.enumerated()), id: \.element.id) { index, _ in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Tool \(index + 1)")
                                .font(.subheadline.weight(.semibold))
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

                        TextField("Tool name", text: bindingForStackItem(at: index, keyPath: \.toolName))
                            .modernInputField()

                        TextField("Link URL (Optional)", text: bindingForOptionalStackItem(at: index, keyPath: \.linkURL))
                            .modernInputField()
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)

                        TextField("How you use it (Optional)", text: bindingForOptionalStackItem(at: index, keyPath: \.usageNote))
                            .modernInputField()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.surface.opacity(0.75))
                    )
                }

                if normalizedStackItems.isEmpty {
                    validationText("Add at least one tool name.")
                }
            }
        }
    }

    private var suggestionTagsEditor: some View {
        sectionCard(title: "Tags", subtitle: "Optional") {
            TextField("Type a tag, then comma or return", text: $tagsText)
                .modernInputField()
                .submitLabel(.done)
                .onSubmit {
                    commitPendingTagInput()
                }
                .onChange(of: tagsText) { _, newValue in
                    guard newValue.contains(",") else { return }
                    commitPendingTagInput()
                }

            if !tagTokens.isEmpty {
                TagChipRowView(tags: tagTokens)
            }

            Text("Use tags to improve discovery in the feed.")
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
                isFavorited: false,
                enableExpandableContent: false
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
            tags: normalizedTags,
            classKeys: Array(selectedClassKeys).sorted()
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
        var combined = tagTokens
        let trailing = tagsText.trimmed.replacingOccurrences(of: "#", with: "")
        if trailing.isNotEmpty {
            combined.append(trailing)
        }
        return Array(Set(combined.map { $0.trimmed }.filter { $0.isNotEmpty })).sorted()
    }

    private func submitPost() async {
        commitPendingTagInput()
        viewModel.clearErrorState()

        await viewModel.createPost(
            type: postType,
            title: title,
            content: content,
            stackItems: postType == .stack ? normalizedStackItems : nil,
            tools: postType == .stack ? normalizedStackItems.map(\.toolName) : [],
            tags: normalizedTags,
            classKeys: Array(selectedClassKeys).sorted()
        )

        if !viewModel.showError {
            dismiss()
        }
    }

    private func commitPendingTagInput() {
        let candidates = tagsText
            .split(separator: ",")
            .map { String($0).trimmed.replacingOccurrences(of: "#", with: "") }
            .filter { $0.isNotEmpty }

        if !candidates.isEmpty {
            let combined = tagTokens + candidates
            tagTokens = Array(Set(combined)).sorted()
        }

        tagsText = ""
    }

    private var classSelectorSection: some View {
        sectionCard(title: "Class", subtitle: "Optional") {
            TextField("Search classes (e.g. CSE20312)", text: $classSearchQuery)
                .modernInputField()
                .onChange(of: classSearchQuery) { _, newValue in
                    Task { await loadAvailableClasses(query: newValue) }
                }

            if isLoadingClasses {
                ProgressView()
                    .tint(AppColors.gold)
            } else if suggestedClasses.isEmpty {
                Text("No classes found yet. Add one from Profile > Classes.")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(suggestedClasses, id: \.id) { globalClass in
                        let isSelected = selectedClassKeys.contains(globalClass.id)
                        Button {
                            if isSelected {
                                selectedClassKeys.remove(globalClass.id)
                            } else {
                                selectedClassKeys.insert(globalClass.id)
                            }
                        } label: {
                            Text(globalClass.courseCode)
                                .font(AppFonts.caption())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? AppColors.gold : AppColors.surface)
                                .foregroundColor(isSelected ? AppColors.background : AppColors.textSecondary)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let classSelectionError, classSelectionError.isNotEmpty {
                validationText(classSelectionError)
            }
        }
    }

    private func loadAvailableClasses() async {
        guard let userId = authService.currentUserId else { return }
        await loadAvailableClasses(query: classSearchQuery, userId: userId)
    }

    private func loadAvailableClasses(query: String, userId: String? = nil) async {
        guard let resolvedUserId = userId ?? authService.currentUserId else { return }
        isLoadingClasses = true
        defer { isLoadingClasses = false }

        do {
            suggestedClasses = try await firebaseService.getSuggestedClassesForUserComposer(
                userId: resolvedUserId,
                query: query
            )
            classSelectionError = nil
        } catch {
            classSelectionError = "Could not load classes."
        }
    }

    private func loadAvailableTools() async {
        guard let userId = authService.currentUserId else { return }
        await loadAvailableTools(query: toolSearchQuery, userId: userId)
    }

    private func loadAvailableTools(query: String, userId: String? = nil) async {
        guard let resolvedUserId = userId ?? authService.currentUserId else { return }
        isLoadingTools = true
        defer { isLoadingTools = false }

        do {
            let user = try await firebaseService.getUser(id: resolvedUserId)
            userTools = user?.primaryStudyTools.isEmpty == false
                ? user?.primaryStudyTools ?? []
                : user?.studyTools ?? []
            popularTools = try await firebaseService.getPopularGlobalTools(limit: 20)
            suggestedTools = try await firebaseService.getSuggestedToolsForUserComposer(
                userId: resolvedUserId,
                query: query
            )
            toolSelectionError = nil
        } catch {
            toolSelectionError = "Could not load tools."
        }
    }

    private func addToolToStack(_ toolName: String) {
        let trimmed = toolName.trimmed
        guard trimmed.isNotEmpty else { return }

        if let emptyIndex = stackItems.firstIndex(where: { $0.toolName.trimmed.isEmpty }) {
            stackItems[emptyIndex].toolName = trimmed
        } else if !normalizedCurrentToolNames.contains(GlobalTool.normalizedId(from: trimmed)) {
            stackItems.append(
                StudyStackItem(
                    toolName: trimmed,
                    linkURL: nil,
                    usageNote: nil
                )
            )
        }

        toolSearchQuery = ""
    }

    private func addCustomToolFromSearch() async {
        guard let userId = authService.currentUserId else { return }
        let trimmed = toolSearchQuery.trimmed
        guard trimmed.isNotEmpty else { return }

        do {
            let canonical = try await firebaseService.createGlobalToolIfNeeded(
                displayName: trimmed,
                category: nil,
                createdByUserId: userId
            )
            addToolToStack(canonical.displayName)
            await loadAvailableTools(query: "")
            toolSelectionError = nil
        } catch {
            toolSelectionError = "Could not add this tool."
        }
    }

    private func sectionCard<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.textTertiary)
            }

            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.surfaceElevated.opacity(0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
    }

    private func validationText(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundColor(AppColors.warning)
    }

    private func toolChip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppFonts.caption())
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.surface)
                .foregroundColor(AppColors.textSecondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
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

    private var normalizedCurrentToolNames: Set<String> {
        Set(stackItems.map { GlobalTool.normalizedId(from: $0.toolName) }.filter(\.isNotEmpty))
    }
}

private extension View {
    func modernInputField() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.surface.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            )
            .foregroundColor(AppColors.textPrimary)
    }
}

#Preview {
    SharePostSheet(viewModel: StudyFeedViewModel())
}
