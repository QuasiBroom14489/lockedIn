import Foundation
import Combine
import FirebaseAuth

struct OnboardingClassSelection: Identifiable, Hashable {
    var classId: String
    var courseCode: String
    var term: String
    var displayName: String?
    var instructorName: String?

    var id: String { "\(classId)_\(term.uppercased())" }
}

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var suggestedClasses: [GlobalClass] = []
    @Published var suggestedTools: [GlobalTool] = []
    @Published var selectedToolIds = Set<String>()
    @Published var selectedToolNames: [String] = []
    @Published var selectedDorm: String = ""
    @Published var selectedClasses: [OnboardingClassSelection] = []

    @Published var classCodeInput: String = ""
    @Published var classTermInput: String = ""
    @Published var classNameInput: String = ""
    @Published var classTeacherInput: String = ""

    @Published var isLoading = false
    @Published var errorMessage: String?

    private let firebaseService = FirebaseService.shared
    private let defaultToolNames = [
        "Notion",
        "Google Docs",
        "Anki",
        "Quizlet",
        "ChatGPT",
        "Claude",
        "Perplexity",
        "VS Code",
        "Xcode",
        "Jupyter Notebook",
        "Canvas",
        "Goodnotes"
    ]

    func loadInitialData(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let user = try await firebaseService.getUser(id: userId)
            selectedDorm = user?.dorm ?? ""
            selectedToolNames = user?.primaryStudyTools.isEmpty == false
                ? user?.primaryStudyTools ?? []
                : user?.studyTools ?? []
            selectedToolIds = Set(selectedToolNames.map { GlobalTool.normalizedId(from: $0) }.filter(\.isNotEmpty))

            let memberships = try await firebaseService.getUserClassMemberships(userId: userId)
            let globals = try await firebaseService.getGlobalClassesByIds(memberships.map(\.classId))
            let globalsById = Dictionary(uniqueKeysWithValues: globals.map { ($0.id, $0) })
            selectedClasses = memberships.map { membership in
                let globalClass = globalsById[membership.classId]
                return OnboardingClassSelection(
                    classId: membership.classId,
                    courseCode: globalClass?.courseCode ?? membership.classId,
                    term: membership.term,
                    displayName: globalClass?.displayName,
                    instructorName: globalClass?.instructorName
                )
            }

            suggestedClasses = try await firebaseService.getSuggestedClassesForUserComposer(userId: userId, query: nil)
            suggestedTools = try await firebaseService.getSuggestedToolsForUserComposer(userId: userId, query: nil)
            if suggestedTools.isEmpty {
                suggestedTools = defaultTools(createdByUserId: userId, query: nil)
            }
            errorMessage = nil
        } catch {
            suggestedTools = defaultTools(createdByUserId: userId, query: nil)
            errorMessage = "Could not load onboarding suggestions."
        }
    }

    func searchClasses(query: String, userId: String) async {
        do {
            suggestedClasses = try await firebaseService.getSuggestedClassesForUserComposer(userId: userId, query: query)
            errorMessage = nil
        } catch {
            errorMessage = "Could not search classes."
        }
    }

    func searchTools(query: String, userId: String) async {
        do {
            suggestedTools = try await firebaseService.getSuggestedToolsForUserComposer(userId: userId, query: query)
            if suggestedTools.isEmpty {
                suggestedTools = defaultTools(createdByUserId: userId, query: query)
            }
            errorMessage = nil
        } catch {
            suggestedTools = defaultTools(createdByUserId: userId, query: query)
            errorMessage = "Could not search tools."
        }
    }

    func selectTool(_ tool: GlobalTool) {
        if selectedToolIds.contains(tool.id) {
            selectedToolIds.remove(tool.id)
            selectedToolNames.removeAll { GlobalTool.normalizedId(from: $0) == tool.id }
        } else {
            selectedToolIds.insert(tool.id)
            if !selectedToolNames.contains(where: { GlobalTool.normalizedId(from: $0) == tool.id }) {
                selectedToolNames.append(tool.displayName)
            }
        }
    }

    func addCustomTool(_ toolName: String, userId: String, category: String? = nil) async {
        let trimmed = toolName.trimmed
        guard trimmed.isNotEmpty else { return }

        // Optimistic local selection so onboarding never feels blocked.
        let localToolId = GlobalTool.normalizedId(from: trimmed)
        selectedToolIds.insert(localToolId)
        if !selectedToolNames.contains(where: { GlobalTool.normalizedId(from: $0) == localToolId }) {
            selectedToolNames.append(trimmed)
        }
        if !suggestedTools.contains(where: { $0.id == localToolId }) {
            suggestedTools.insert(
                GlobalTool(
                    id: localToolId,
                    displayName: trimmed,
                    aliases: GlobalTool.normalizedAliasKeys(from: trimmed),
                    category: category,
                    createdByUserId: userId,
                    usageCount: 0,
                    createdAt: Date(),
                    updatedAt: Date()
                ),
                at: 0
            )
        }

        do {
            let canonical = try await firebaseService.createGlobalToolIfNeeded(
                displayName: trimmed,
                category: category,
                createdByUserId: userId
            )
            selectedToolIds.insert(canonical.id)
            if !selectedToolNames.contains(where: { GlobalTool.normalizedId(from: $0) == canonical.id }) {
                selectedToolNames.append(canonical.displayName)
            }
            suggestedTools = try await firebaseService.getSuggestedToolsForUserComposer(userId: userId, query: nil)
            if suggestedTools.isEmpty {
                suggestedTools = defaultTools(createdByUserId: userId, query: nil)
            }
            errorMessage = nil
        } catch {
            // Keep optimistic selection and continue onboarding even if global sync fails.
            errorMessage = "Tool added locally. Global sync will retry later."
        }
    }

    func applySuggestedClassToForm(_ globalClass: GlobalClass) {
        classCodeInput = globalClass.courseCode
        if let displayName = globalClass.displayName, displayName.isNotEmpty {
            classNameInput = displayName
        }
        if classTeacherInput.trimmed.isEmpty, let instructor = globalClass.instructorName, instructor.isNotEmpty {
            classTeacherInput = instructor
        }
    }

    func addClassFromForm(userId: String) async -> Bool {
        let normalizedCode = GlobalClass.normalizedId(from: classCodeInput)
        let trimmedTerm = classTermInput.trimmed
        let trimmedClassName = classNameInput.trimmed
        let trimmedTeacher = classTeacherInput.trimmed
        let classNameValue: String? = trimmedClassName.isNotEmpty ? trimmedClassName : nil
        let teacherValue: String? = trimmedTeacher.isNotEmpty ? trimmedTeacher : nil
        guard normalizedCode.isNotEmpty else {
            errorMessage = "Class code is required."
            return false
        }
        guard trimmedTerm.isNotEmpty else {
            errorMessage = "Year/Semester taken is required."
            return false
        }

        do {
            let globalClass = try await firebaseService.createOrJoinClassForUser(
                userId: userId,
                courseCode: normalizedCode,
                term: trimmedTerm,
                displayName: classNameValue,
                instructorName: teacherValue
            )

            selectedClasses.removeAll {
                $0.classId == globalClass.id && $0.term.caseInsensitiveCompare(trimmedTerm) == .orderedSame
            }
            selectedClasses.insert(
                OnboardingClassSelection(
                    classId: globalClass.id,
                    courseCode: globalClass.courseCode,
                    term: trimmedTerm,
                    displayName: classNameValue ?? globalClass.displayName,
                    instructorName: teacherValue ?? globalClass.instructorName
                ),
                at: 0
            )
            suggestedClasses = try await firebaseService.getSuggestedClassesForUserComposer(userId: userId, query: nil)

            classCodeInput = ""
            classTermInput = ""
            classNameInput = ""
            classTeacherInput = ""
            errorMessage = nil
            return true
        } catch {
            errorMessage = "Could not add class. \(error.localizedDescription)"
            return false
        }
    }

    func removeSelectedClass(_ selection: OnboardingClassSelection) {
        selectedClasses.removeAll { $0.id == selection.id }
    }

    func completeRequiredProfile(userId: String) async throws {
        var user: User
        if let existingUser = try await firebaseService.getUser(id: userId) {
            user = existingUser
        } else {
            guard let authUser = Auth.auth().currentUser else {
                throw FirebaseError.userNotFound
            }
            let trimmedAuthName: String? = {
                let raw = authUser.displayName?.trimmed
                guard let value = raw, value.isNotEmpty else { return nil }
                return value
            }()

            let emailLocalPart: String? = authUser.email
                .flatMap { $0.split(separator: "@").first.map(String.init) }

            let fallbackDisplayName = trimmedAuthName ?? emailLocalPart ?? "Student"
            let newUser = User(
                id: userId,
                email: authUser.email ?? "",
                displayName: fallbackDisplayName
            )
            try await firebaseService.createUser(newUser)
            user = newUser
        }

        let uniqueTools = Array(Set(selectedToolNames.map(\.trimmed).filter(\.isNotEmpty))).sorted()
        user.dorm = selectedDorm.trimmed.isNotEmpty ? selectedDorm.trimmed : nil
        user.studyTools = uniqueTools
        user.primaryStudyTools = Array(uniqueTools.prefix(3))
        user.updatedAt = Date()

        try await firebaseService.updateUser(user)

        for toolName in uniqueTools {
            do {
                _ = try await firebaseService.createGlobalToolIfNeeded(
                    displayName: toolName,
                    category: nil,
                    createdByUserId: userId
                )
            } catch {
                // Library sync should not block required onboarding completion.
                print("Onboarding tool sync skipped for \(toolName): \(error.localizedDescription)")
            }
        }
    }

    private func defaultTools(createdByUserId: String, query: String?) -> [GlobalTool] {
        let trimmedQuery = query?.trimmed.lowercased() ?? ""
        return defaultToolNames
            .filter { tool in
                guard trimmedQuery.isNotEmpty else { return true }
                return tool.lowercased().contains(trimmedQuery)
            }
            .map { tool in
                GlobalTool(
                    id: GlobalTool.normalizedId(from: tool),
                    displayName: tool,
                    aliases: GlobalTool.normalizedAliasKeys(from: tool),
                    category: nil,
                    createdByUserId: createdByUserId,
                    usageCount: 0,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
    }
}

