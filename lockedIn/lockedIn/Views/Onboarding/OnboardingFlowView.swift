import SwiftUI
import FirebaseAuth

struct OnboardingFlowView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel = OnboardingViewModel()

    @State private var step: OnboardingStep = .welcome
    @State private var toolQuery = ""
    @State private var customToolInput = ""
    @State private var selectedSemester = "Spring"
    @State private var selectedClassYear = Calendar.current.component(.year, from: Date())

    private let onComplete: () -> Void
    private var activeUserId: String? { authViewModel.currentUser?.id ?? Auth.auth().currentUser?.uid }
    private var availableClassYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((2018...currentYear).reversed())
    }

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                stepHeader

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        switch step {
                        case .welcome:
                            welcomeStep
                        case .dorm:
                            dormStep
                        case .tools:
                            toolsStep
                        case .classes:
                            classesStep
                        case .posting:
                            postingStep
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 10)
                }

                if let error = viewModel.errorMessage, error.isNotEmpty {
                    Text(error)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.warning)
                        .padding(.horizontal, 18)
                }

                footer
            }
            .background(
                LinearGradient(
                    colors: [AppColors.background, AppColors.backgroundSecondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .ambientBackgroundLayer()
            )
            .task {
                guard let userId = activeUserId else { return }
                await viewModel.loadInitialData(userId: userId)
            }
        }
    }

    private var stepHeader: some View {
        VStack(spacing: 10) {
            Text("Set Up lockedIn")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text(step.subtitle)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 8) {
                ForEach(OnboardingStep.allCases, id: \.self) { current in
                    Capsule()
                        .fill(current.rawValue <= step.rawValue ? AppColors.gold : AppColors.surface)
                        .frame(height: 6)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.top, 24)
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Build your profile once")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("We use your dorm and main tools to personalize class and post recommendations.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)

            Text("Required: Dorm and Main Stack. Optional: Classes and quick post walkthrough.")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textTertiary)
        }
        .focusCardStyle()
    }

    private var dormStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Select Your Dorm")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            GroupBox("Men's Dorms") {
                dormGrid(dorms: Dorm.mensDorms)
            }

            GroupBox("Women's Dorms") {
                dormGrid(dorms: Dorm.womensDorms)
            }

            if !Dorm.otherDorms.isEmpty {
                GroupBox("Other") {
                    dormGrid(dorms: Dorm.otherDorms)
                }
            }
        }
        .groupBoxStyle(.automatic)
    }

    private func dormGrid(dorms: [Dorm]) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 2), spacing: 8) {
            ForEach(dorms) { dorm in
                let isSelected = viewModel.selectedDorm == dorm.displayName
                Button {
                    viewModel.selectedDorm = dorm.displayName
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: dorm.icon)
                        Text(dorm.shortName)
                            .lineLimit(1)
                    }
                    .font(AppFonts.caption())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(isSelected ? AppColors.gold : AppColors.surface)
                    .foregroundColor(isSelected ? AppColors.background : AppColors.textSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var toolsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Choose Main Stack")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            TextField("Search tools", text: $toolQuery)
                .modernInputField()
                .onChange(of: toolQuery) { _, newValue in
                    Task {
                        guard let userId = activeUserId else { return }
                        await viewModel.searchTools(query: newValue, userId: userId)
                    }
                }

            if !viewModel.suggestedTools.isEmpty {
                chipGrid(items: viewModel.suggestedTools.map(\.displayName)) { label in
                    if let tool = viewModel.suggestedTools.first(where: { $0.displayName == label }) {
                        viewModel.selectTool(tool)
                    }
                } isSelected: { label in
                    viewModel.selectedToolIds.contains(GlobalTool.normalizedId(from: label))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Add custom tool")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: 8) {
                    TextField("e.g. Obsidian", text: $customToolInput)
                        .modernInputField()

                    Button("Add") {
                        Task {
                            guard let userId = activeUserId else { return }
                            await viewModel.addCustomTool(customToolInput, userId: userId)
                            customToolInput = ""
                        }
                    }
                    .secondaryButtonStyle()
                    .frame(width: 90)
                    .disabled(customToolInput.trimmed.isEmpty)
                }
            }

            if !viewModel.selectedToolNames.isEmpty {
                Text("Selected")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                chipGrid(items: viewModel.selectedToolNames) { label in
                    if let tool = viewModel.suggestedTools.first(where: { GlobalTool.normalizedId(from: $0.displayName) == GlobalTool.normalizedId(from: label) }) {
                        viewModel.selectTool(tool)
                    } else {
                        viewModel.selectedToolNames.removeAll { GlobalTool.normalizedId(from: $0) == GlobalTool.normalizedId(from: label) }
                        viewModel.selectedToolIds.remove(GlobalTool.normalizedId(from: label))
                    }
                } isSelected: { _ in
                    true
                }
            }
        }
    }

    private var classesFormValid: Bool {
        viewModel.classCodeInput.trimmed.isNotEmpty && !computedClassTerm.trimmed.isEmpty
    }

    private var computedClassTerm: String {
        "\(selectedSemester) \(selectedClassYear)"
    }

    private var classesStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Classes (Optional)")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("Class Code and Year/Semester are required to add a class.")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)

            TextField("Search class code or class name", text: $viewModel.classCodeInput)
                .modernInputField()
                .onChange(of: viewModel.classCodeInput) { _, newValue in
                    Task {
                        guard let userId = activeUserId else { return }
                        await viewModel.searchClasses(query: newValue, userId: userId)
                    }
                }

            if !viewModel.suggestedClasses.isEmpty {
                chipGrid(items: viewModel.suggestedClasses.map { suggestionClassLabel(for: $0) }) { selectedLabel in
                    if let globalClass = viewModel.suggestedClasses.first(where: { suggestionClassLabel(for: $0) == selectedLabel }) {
                        viewModel.applySuggestedClassToForm(globalClass)
                    }
                }
            }

            TextField("Year/Semester Taken (e.g. Fall 2025)", text: $viewModel.classTermInput)
                .hidden()
                .frame(height: 0)

            VStack(alignment: .leading, spacing: 8) {
                Text("Semester")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                Picker("Semester", selection: $selectedSemester) {
                    Text("Spring").tag("Spring")
                    Text("Fall").tag("Fall")
                }
                .pickerStyle(.segmented)

                Text("Year")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                Menu {
                    ForEach(availableClassYears, id: \.self) { year in
                        Button(String(year)) {
                            selectedClassYear = year
                        }
                    }
                } label: {
                    HStack {
                        Text(String(selectedClassYear))
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.textPrimary)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppColors.textSecondary)
                    }
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
                }

                Text("Selected: \(computedClassTerm)")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.gold)
            }
            TextField("Class Name (Optional)", text: $viewModel.classNameInput)
                .modernInputField()
            TextField("Teacher (Optional)", text: $viewModel.classTeacherInput)
                .modernInputField()

            Button {
                Task {
                    guard let userId = activeUserId else { return }
                    viewModel.classTermInput = computedClassTerm
                    _ = await viewModel.addClassFromForm(userId: userId)
                }
            } label: {
                Label("Add Class", systemImage: "plus.circle.fill")
                    .font(AppFonts.caption())
                    .foregroundColor(classesFormValid ? AppColors.background : AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(classesFormValid ? AppColors.gold : AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(!classesFormValid)

            if !viewModel.selectedClasses.isEmpty {
                Text("Selected Classes")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                chipGrid(items: viewModel.selectedClasses.map(classSelectionLabel)) { _ in
                    // Display-only: classes are persisted on add.
                } isSelected: { _ in
                    true
                }
            }
        }
    }

    private var postingStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How Posting Works")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: 8) {
                Text("Stack Post")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.gold)
                Text("Share your exact workflow and tools so other students can replicate it.")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                Text("Suggestion Post")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.gold)
                Text("Share concise tips and tag them so students can find them quickly.")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
            .focusCardStyle()

            Text("You can start posting from the Study Feed tab after finishing onboarding.")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textTertiary)
        }
    }

    private var footer: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                if step != .welcome {
                    Button("Back") {
                        withAnimation { step = step.previous }
                    }
                    .secondaryButtonStyle()
                }

                Button(primaryButtonTitle) {
                    Task { await handlePrimaryAction() }
                }
                .primaryButtonStyle()
                .disabled(primaryDisabled)
            }

            if step == .classes {
                Button("Skip classes for now") {
                    withAnimation { step = .posting }
                }
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome: return "Get Started"
        case .dorm: return "Continue"
        case .tools: return "Continue"
        case .classes: return "Continue"
        case .posting: return "Finish"
        }
    }

    private var primaryDisabled: Bool {
        switch step {
        case .dorm:
            return viewModel.selectedDorm.trimmed.isEmpty
        case .tools:
            return viewModel.selectedToolNames.isEmpty
        default:
            return false
        }
    }

    private func handlePrimaryAction() async {
        switch step {
        case .welcome:
            withAnimation { step = .dorm }
        case .dorm:
            withAnimation { step = .tools }
        case .tools:
            withAnimation { step = .classes }
        case .classes:
            viewModel.classTermInput = computedClassTerm
            withAnimation { step = .posting }
        case .posting:
            guard let userId = activeUserId else { return }
            do {
                try await viewModel.completeRequiredProfile(userId: userId)
                await authViewModel.completeOnboarding()
                onComplete()
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        }
    }

    private func suggestionClassLabel(for globalClass: GlobalClass) -> String {
        if let displayName = globalClass.displayName, displayName.isNotEmpty {
            return "\(globalClass.courseCode) • \(displayName)"
        }
        return globalClass.courseCode
    }

    private func classSelectionLabel(_ selection: OnboardingClassSelection) -> String {
        "\(selection.courseCode) • \(selection.term)"
    }

    private func chipGrid(
        items: [String],
        onTap: @escaping (String) -> Void,
        isSelected: @escaping (String) -> Bool = { _ in false }
    ) -> some View {
        let columns = [GridItem(.adaptive(minimum: 120), spacing: 8)]

        return LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { label in
                let selected = isSelected(label)
                Button {
                    onTap(label)
                } label: {
                    Text(label)
                        .font(AppFonts.caption())
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(selected ? AppColors.gold : AppColors.surface)
                        .foregroundColor(selected ? AppColors.background : AppColors.textSecondary)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private enum OnboardingStep: Int, CaseIterable {
    case welcome
    case dorm
    case tools
    case classes
    case posting

    var subtitle: String {
        switch self {
        case .welcome: return "Quick setup takes about 1 minute"
        case .dorm: return "Required"
        case .tools: return "Required"
        case .classes: return "Optional"
        case .posting: return "Optional"
        }
    }

    var previous: OnboardingStep {
        OnboardingStep(rawValue: max(0, rawValue - 1)) ?? .welcome
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
    OnboardingFlowView(onComplete: {})
        .environmentObject(AuthViewModel())
}
