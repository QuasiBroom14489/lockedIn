import SwiftUI
import FirebaseAuth

struct OnboardingFlowView: View {
    private enum CompletionDestination: Int {
        case focus = 0
        case leaderboard = 1
        case feed = 2
        case profile = 3
    }

    @EnvironmentObject private var authViewModel: AuthViewModel
    @AppStorage("app.selectedTab") private var selectedTab = CompletionDestination.focus.rawValue
    @AppStorage("onboarding.currentStep") private var persistedStepRawValue = OnboardingStep.welcome.rawValue
    @StateObject private var viewModel = OnboardingViewModel()

    @State private var step: OnboardingStep = .welcome
    @State private var toolQuery = ""
    @State private var customToolInput = ""
    @State private var selectedSemester = "Spring"
    @State private var selectedClassYear = Calendar.current.component(.year, from: Date())
    @State private var isCompleting = false

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
                        if viewModel.isLoading {
                            ProgressView("Loading your onboarding setup...")
                                .frame(maxWidth: .infinity, minHeight: 320)
                                .tint(AppColors.gold)
                        } else {
                            currentStepView
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

                if step != .completion {
                    footer
                }
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
            .task(id: activeUserId) {
                guard let userId = activeUserId else { return }
                await viewModel.loadInitialData(userId: userId)
                restoreProgress()
            }
            .onChange(of: step) { _, newValue in
                persistedStepRawValue = newValue.rawValue
            }
        }
    }

    private var currentStepView: some View {
        Group {
            switch step {
            case .welcome:
                welcomeStep
            case .profileBasics:
                OnboardingProfileBasicsStep(viewModel: viewModel)
            case .dorm:
                dormStep
            case .focusIntro:
                OnboardingFocusIntroStep()
            case .tierIntro:
                OnboardingTierIntroStep()
            case .tools:
                toolsStep
            case .classes:
                classesStep
            case .feedIntro:
                OnboardingFeedIntroStep()
            case .leaderboardIntro:
                OnboardingLeaderboardIntroStep()
            case .completion:
                completionStep
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

            Text("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textTertiary)

            HStack(spacing: 6) {
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
        VStack(alignment: .leading, spacing: 16) {
            Text("Welcome to lockedIn")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("Build a profile, connect your classes and tools, and learn how the app helps you focus, share better workflows, and compete with your dorm.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)

            VStack(spacing: 12) {
                OnboardingFeatureCard(
                    icon: "timer",
                    title: "Focus with proof",
                    description: "Run verified study sessions and earn points for real consistency."
                )
                OnboardingFeatureCard(
                    icon: "rectangle.stack.fill.badge.plus",
                    title: "Build your study stack",
                    description: "Save the tools and class context behind what actually works."
                )
                OnboardingFeatureCard(
                    icon: "trophy.fill",
                    title: "Climb with your dorm",
                    description: "Turn individual progress into social momentum on the leaderboard."
                )
            }
        }
        .focusCardStyle()
    }

    private var dormStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Your Dorm")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("Dorm identity matters in lockedIn. Your sessions help power dorm competition and campus rankings.")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)

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
                    viewModel.errorMessage = nil
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
        VStack(alignment: .leading, spacing: 12) {
            Text("Build Your Study Stack")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("Pick the tools you actually use. This shapes recommendations and makes your future Study Stacks instantly more useful.")
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)

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
                        viewModel.errorMessage = nil
                    }
                } isSelected: { label in
                    viewModel.selectedToolIds.contains(GlobalTool.normalizedId(from: label))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Add a custom tool")
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
                Text("Selected tools")
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

            OnboardingFeatureCard(
                icon: "square.stack.3d.up.fill",
                title: "Study Stacks use these tools",
                description: "When you share a workflow later, lockedIn uses your stack to help other students find the same setup faster."
            )
        }
    }

    private var classesFormValid: Bool {
        viewModel.classCodeInput.trimmed.isNotEmpty && !computedClassTerm.trimmed.isEmpty
    }

    private var computedClassTerm: String {
        "\(selectedSemester) \(selectedClassYear)"
    }

    private var classesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Your First Class")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text("Classes unlock more relevant tips, tools, and workflows. Add at least one to continue.")
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

                Text("Selected term: \(computedClassTerm)")
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
                Text("Added classes")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                VStack(spacing: 8) {
                    ForEach(viewModel.selectedClasses) { selection in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(selection.courseCode)
                                    .font(AppFonts.body())
                                    .foregroundColor(AppColors.textPrimary)
                                Text(selection.term)
                                    .font(AppFonts.caption())
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            Button {
                                viewModel.removeSelectedClass(selection)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                                .fill(AppColors.surface)
                        )
                    }
                }
            }

            OnboardingFeatureCard(
                icon: "books.vertical.fill",
                title: "Class-specific discovery",
                description: "Class membership helps lockedIn surface better feed posts, resources, and stack ideas for the courses you actually take."
            )
        }
    }

    private var completionStep: some View {
        OnboardingCompletionStep(
            displayName: viewModel.displayName.trimmed,
            major: viewModel.major.trimmed,
            year: viewModel.year.trimmed,
            dorm: viewModel.selectedDorm.trimmed,
            toolsCount: viewModel.selectedToolNames.count,
            classesCount: viewModel.selectedClasses.count,
            onStartFocus: {
                selectedTab = CompletionDestination.focus.rawValue
                Task { await finishOnboarding() }
            },
            onExploreFeed: {
                selectedTab = CompletionDestination.feed.rawValue
                Task { await finishOnboarding() }
            }
        )
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step != .welcome {
                Button("Back") {
                    withAnimation { step = step.previous }
                }
                .secondaryButtonStyle()
                .disabled(isCompleting)
            }

            Button(primaryButtonTitle) {
                Task { await handlePrimaryAction() }
            }
            .primaryButtonStyle()
            .disabled(primaryDisabled)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 18)
    }

    private var primaryButtonTitle: String {
        switch step {
        case .welcome: return "Get Started"
        case .profileBasics: return "Continue"
        case .dorm: return "Continue"
        case .focusIntro: return "Continue"
        case .tierIntro: return "Continue"
        case .tools: return "Continue"
        case .classes: return "Continue"
        case .feedIntro: return "Continue"
        case .leaderboardIntro: return "Continue"
        case .completion: return "Finish"
        }
    }

    private var primaryDisabled: Bool {
        if isCompleting || viewModel.isLoading {
            return true
        }

        switch step {
        case .profileBasics:
            return !viewModel.isProfileBasicsValid
        case .dorm:
            return !viewModel.isDormValid
        case .tools:
            return !viewModel.isToolsValid
        case .classes:
            return !viewModel.isClassesValid
        case .completion:
            return true
        default:
            return false
        }
    }

    private func handlePrimaryAction() async {
        viewModel.errorMessage = nil

        switch step {
        case .welcome:
            withAnimation { step = .profileBasics }
        case .profileBasics:
            guard viewModel.validateProfileBasics() else { return }
            withAnimation { step = .dorm }
        case .dorm:
            guard viewModel.validateDorm() else { return }
            withAnimation { step = .focusIntro }
        case .focusIntro:
            withAnimation { step = .tierIntro }
        case .tierIntro:
            withAnimation { step = .tools }
        case .tools:
            guard viewModel.validateTools() else { return }
            withAnimation { step = .classes }
        case .classes:
            guard viewModel.validateClasses() else { return }
            withAnimation { step = .feedIntro }
        case .feedIntro:
            withAnimation { step = .leaderboardIntro }
        case .leaderboardIntro:
            withAnimation { step = .completion }
        case .completion:
            await finishOnboarding()
        }
    }

    private func finishOnboarding() async {
        guard let userId = activeUserId, !isCompleting else { return }
        isCompleting = true
        defer { isCompleting = false }

        guard viewModel.validateProfileBasics(),
              viewModel.validateDorm(),
              viewModel.validateTools(),
              viewModel.validateClasses()
        else {
            restoreProgress()
            return
        }

        do {
            try await viewModel.completeRequiredProfile(userId: userId)
            persistedStepRawValue = OnboardingStep.welcome.rawValue
            await authViewModel.completeOnboarding()
            onComplete()
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    private func restoreProgress() {
        let fallbackStep = firstIncompleteRequiredStep()
        let persistedStep = OnboardingStep(rawValue: persistedStepRawValue) ?? fallbackStep
        step = canResume(at: persistedStep) ? persistedStep : fallbackStep
    }

    private func firstIncompleteRequiredStep() -> OnboardingStep {
        if !viewModel.isProfileBasicsValid {
            return .profileBasics
        }
        if !viewModel.isDormValid {
            return .dorm
        }
        if !viewModel.isToolsValid {
            return .tools
        }
        if !viewModel.isClassesValid {
            return .classes
        }
        return .completion
    }

    private func canResume(at step: OnboardingStep) -> Bool {
        switch step {
        case .welcome, .profileBasics:
            return true
        case .dorm:
            return viewModel.isProfileBasicsValid
        case .focusIntro, .tierIntro, .tools:
            return viewModel.isProfileBasicsValid && viewModel.isDormValid
        case .classes:
            return viewModel.isProfileBasicsValid && viewModel.isDormValid && viewModel.isToolsValid
        case .feedIntro, .leaderboardIntro, .completion:
            return viewModel.isProfileBasicsValid &&
                viewModel.isDormValid &&
                viewModel.isToolsValid &&
                viewModel.isClassesValid
        }
    }

    private func suggestionClassLabel(for globalClass: GlobalClass) -> String {
        if let displayName = globalClass.displayName, displayName.isNotEmpty {
            return "\(globalClass.courseCode) - \(displayName)"
        }
        return globalClass.courseCode
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
    case profileBasics
    case dorm
    case focusIntro
    case tierIntro
    case tools
    case classes
    case feedIntro
    case leaderboardIntro
    case completion

    var subtitle: String {
        switch self {
        case .welcome: return "Welcome to lockedIn"
        case .profileBasics: return "Required"
        case .dorm: return "Required"
        case .focusIntro: return "How you earn points"
        case .tierIntro: return "Your study prestige"
        case .tools: return "Required"
        case .classes: return "Required"
        case .feedIntro: return "Discover and share"
        case .leaderboardIntro: return "Compete and climb"
        case .completion: return "You're all set!"
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
