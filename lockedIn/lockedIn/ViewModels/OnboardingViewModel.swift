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
    @Published var displayName: String = ""
    @Published var major: String = ""
    @Published var year: String = ""
    @Published var displayNameError: String?
    @Published var majorError: String?
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

    let yearOptions = ["Freshman", "Sophomore", "Junior", "Senior", "Graduate"]

    let commonMajors = [
        "Accounting", "Aerospace Engineering", "American Studies", "Anthropology",
        "Applied Mathematics", "Architecture", "Art History", "Biology",
        "Business Analytics", "Chemical Engineering", "Chemistry", "Civil Engineering",
        "Classics", "Computer Engineering", "Computer Science", "Design",
        "Economics", "Electrical Engineering", "English", "Environmental Engineering",
        "Film, Television, and Theatre", "Finance", "French", "German",
        "Global Affairs", "History", "Information Technology", "Irish Studies",
        "Management", "Marketing", "Mathematics", "Mechanical Engineering",
        "Music", "Neuroscience", "Philosophy", "Physics", "Political Science",
        "Pre-Professional Studies", "Psychology", "Romance Languages", "Sociology",
        "Spanish", "Statistics", "Theology"
    ]

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
            try await loadInitialProfileData(userId: userId)
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
            syncValidationErrors()
            errorMessage = nil
        } catch {
            suggestedTools = defaultTools(createdByUserId: userId, query: nil)
            errorMessage = "Could not load onboarding suggestions."
        }
    }

    func loadInitialProfileData(userId: String) async throws {
        let user = try await firebaseService.getUser(id: userId)
        if let user {
            displayName = user.displayName.trimmed
            major = user.major?.trimmed ?? ""
            year = user.year?.trimmed ?? ""
        }

        if displayName.isEmpty, let authDisplayName = Auth.auth().currentUser?.displayName?.trimmed, authDisplayName.isNotEmpty {
            displayName = authDisplayName
        }

        if displayName.isEmpty,
           let emailLocalPart = Auth.auth().currentUser?.email?.split(separator: "@").first.map(String.init),
           emailLocalPart.isNotEmpty {
            displayName = emailLocalPart
        }

        syncValidationErrors()
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

    func validateProfileBasics() -> Bool {
        let trimmedName = displayName.trimmed
        let trimmedMajor = major.trimmed
        let trimmedYear = year.trimmed
        displayNameError = nil
        majorError = nil

        guard trimmedName.count >= 2, trimmedName.count <= 50 else {
            displayNameError = "Display name must be 2-50 characters."
            errorMessage = displayNameError
            return false
        }

        guard trimmedMajor.count >= 2, trimmedMajor.count <= 100 else {
            majorError = "Major must be 2-100 characters."
            errorMessage = majorError
            return false
        }

        guard yearOptions.contains(trimmedYear) else {
            errorMessage = "Please select your academic year"
            return false
        }

        errorMessage = nil
        return true
    }

    func validateDorm() -> Bool {
        guard selectedDorm.trimmed.isNotEmpty else {
            errorMessage = "Please select your dorm"
            return false
        }
        errorMessage = nil
        return true
    }

    func validateTools() -> Bool {
        guard !selectedToolNames.isEmpty else {
            errorMessage = "Add at least 1 study tool to continue"
            return false
        }
        errorMessage = nil
        return true
    }

    func validateClasses() -> Bool {
        guard !selectedClasses.isEmpty else {
            errorMessage = "Add at least 1 class to continue"
            return false
        }
        errorMessage = nil
        return true
    }

    var isProfileBasicsValid: Bool {
        let trimmedName = displayName.trimmed
        let trimmedMajor = major.trimmed
        return trimmedName.count >= 2 && trimmedName.count <= 50 &&
               trimmedMajor.count >= 2 && trimmedMajor.count <= 100 &&
               yearOptions.contains(year.trimmed)
    }

    var isDormValid: Bool {
        selectedDorm.trimmed.isNotEmpty
    }

    var isToolsValid: Bool {
        !selectedToolNames.isEmpty
    }

    var isClassesValid: Bool {
        !selectedClasses.isEmpty
    }

    func filteredMajors(query: String) -> [String] {
        let trimmed = query.trimmed.lowercased()
        guard trimmed.isNotEmpty else { return commonMajors }
        return commonMajors.filter { $0.lowercased().contains(trimmed) }
    }

    func syncValidationErrors() {
        displayNameError = nil
        majorError = nil

        let trimmedName = displayName.trimmed
        let trimmedMajor = major.trimmed

        if trimmedName.isNotEmpty && !(2...50).contains(trimmedName.count) {
            displayNameError = "Display name must be 2-50 characters."
        }

        if trimmedMajor.isNotEmpty && !(2...100).contains(trimmedMajor.count) {
            majorError = "Major must be 2-100 characters."
        }
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

        user.displayName = displayName.trimmed
        user.major = major.trimmed.isNotEmpty ? major.trimmed : nil
        user.year = year.trimmed.isNotEmpty ? year.trimmed : nil

        let uniqueTools = Array(Set(selectedToolNames.map(\.trimmed).filter(\.isNotEmpty))).sorted()
        user.dorm = selectedDorm.trimmed.isNotEmpty ? selectedDorm.trimmed : nil
        user.studyTools = uniqueTools
        user.primaryStudyTools = Array(uniqueTools.prefix(3))

        user.onboardingCompletedAt = Date()
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

        for selection in selectedClasses {
            do {
                _ = try await firebaseService.createOrJoinClassForUser(
                    userId: userId,
                    courseCode: selection.courseCode,
                    term: selection.term,
                    displayName: selection.displayName,
                    instructorName: selection.instructorName
                )
            } catch {
                print("Onboarding class sync skipped for \(selection.courseCode): \(error.localizedDescription)")
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
