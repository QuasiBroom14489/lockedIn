import SwiftUI

struct ClassSummaryCard: View {
    let item: ProfileClassItem
    let dashboard: ClassDashboard?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(item.global.courseCode)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                Text("\(item.global.memberCount) members")
                    .modernCapsuleChipStyle(foreground: AppColors.gold, background: AppColors.gold.opacity(0.16))
            }

            if let displayName = item.global.displayName, displayName.isNotEmpty {
                Text(displayName)
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)
            }

            if let instructorName = item.global.instructorName, instructorName.isNotEmpty {
                Label(instructorName, systemImage: "person.text.rectangle")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)
            }

            HStack(spacing: 12) {
                Label("\(dashboard?.postCount ?? 0) posts", systemImage: "doc.text")
                Label("\(dashboard?.stackCount ?? 0) stacks", systemImage: "square.stack.3d.up")
                Label("\(dashboard?.tipCount ?? 0) tips", systemImage: "lightbulb")
            }
            .font(AppFonts.caption())
            .foregroundColor(AppColors.textSecondary)
        }
        .postCardStyle()
    }
}

struct ClassDashboardSection: View {
    let dashboard: ClassDashboard

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Class Dashboard")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            if dashboard.postCount == 0 {
                Text("No tagged posts yet for this class.")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Tools")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textSecondary)
                    FlowLayout(spacing: 8) {
                        ForEach(dashboard.topTools.prefix(8)) { stat in
                            Text("\(stat.tool) • \(stat.count)x")
                                .modernCapsuleChipStyle(foreground: AppColors.gold, background: AppColors.surface)
                        }
                    }
                }

                if !dashboard.topStackPatterns.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Stack Patterns")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                        ForEach(dashboard.topStackPatterns.prefix(3)) { pattern in
                            Text("\(pattern.pattern) (\(pattern.count)x)")
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.textSecondary)
                        }
                    }
                }

                if !dashboard.topTipTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Top Tip Tags")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(AppColors.textSecondary)
                        FlowLayout(spacing: 8) {
                            ForEach(dashboard.topTipTags.prefix(8)) { tag in
                                Text("#\(tag.tag) • \(tag.count)x")
                                    .modernCapsuleChipStyle()
                            }
                        }
                    }
                }
            }
        }
        .cardStyle()
    }
}

struct ClassDetailSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let item: ProfileClassItem
    let isEditable: Bool
    let dashboard: ClassDashboard?
    let isLoadingDashboard: Bool
    let classErrorMessage: String?
    let period: ClassDashboardPeriod
    let userPosts: [StudyPost]
    let isLoadingUserPosts: Bool
    let isValidSpotifyURL: (String) -> Bool
    let onPeriodChanged: (ClassDashboardPeriod) -> Void
    let onRefreshDashboard: () -> Void
    let onSave: (ProfileClassItem) -> Void
    let onDelete: (() -> Void)?

    @State private var teacherReview: String
    @State private var teacherRating: Int
    @State private var spotifyLinks: [SpotifyLink]
    @State private var helpfulWebsites: [HelpfulLink]
    @State private var selectedPeriod: ClassDashboardPeriod

    @State private var newSpotifyURL = ""
    @State private var newWebsiteTitle = ""
    @State private var newWebsiteURL = ""
    @State private var localError: String?

    init(
        item: ProfileClassItem,
        isEditable: Bool,
        dashboard: ClassDashboard?,
        isLoadingDashboard: Bool,
        classErrorMessage: String?,
        period: ClassDashboardPeriod,
        userPosts: [StudyPost],
        isLoadingUserPosts: Bool,
        isValidSpotifyURL: @escaping (String) -> Bool,
        onPeriodChanged: @escaping (ClassDashboardPeriod) -> Void,
        onRefreshDashboard: @escaping () -> Void,
        onSave: @escaping (ProfileClassItem) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        self.item = item
        self.isEditable = isEditable
        self.dashboard = dashboard
        self.isLoadingDashboard = isLoadingDashboard
        self.classErrorMessage = classErrorMessage
        self.period = period
        self.userPosts = userPosts
        self.isLoadingUserPosts = isLoadingUserPosts
        self.isValidSpotifyURL = isValidSpotifyURL
        self.onPeriodChanged = onPeriodChanged
        self.onRefreshDashboard = onRefreshDashboard
        self.onSave = onSave
        self.onDelete = onDelete

        _teacherReview = State(initialValue: item.membership.teacherReview)
        _teacherRating = State(initialValue: item.membership.teacherRating ?? 0)
        _spotifyLinks = State(initialValue: item.membership.spotifyLinks)
        _helpfulWebsites = State(initialValue: item.membership.helpfulWebsites)
        _selectedPeriod = State(initialValue: period)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ClassSummaryCard(item: editedItemPreview, dashboard: dashboard)

                    Picker("Dashboard Period", selection: $selectedPeriod) {
                        ForEach(ClassDashboardPeriod.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedPeriod) { _, newValue in
                        onPeriodChanged(newValue)
                    }

                    if isLoadingDashboard {
                        ProgressView()
                            .tint(AppColors.gold)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else if let dashboard {
                        ClassDashboardSection(dashboard: dashboard)
                    }

                    userPostsSection
                    reviewSection
                    spotifySection
                    helpfulSitesSection

                    if let classErrorMessage, classErrorMessage.isNotEmpty {
                        Text(classErrorMessage)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let localError, localError.isNotEmpty {
                        Text(localError)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.warning)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle(item.global.courseCode)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }

                if isEditable {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave(editedItemPreview)
                            dismiss()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isEditable, let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                        dismiss()
                    } label: {
                        Text("Leave Class")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(AppColors.surface)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            }
            .task {
                onRefreshDashboard()
            }
        }
    }

    private var userPostsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This User's Posts For This Class")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            if isLoadingUserPosts {
                ProgressView()
                    .tint(AppColors.gold)
            } else if userPosts.isEmpty {
                Text("No stacks or study tips for this class yet.")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)
            } else {
                PostsListView(posts: userPosts)
            }
        }
        .cardStyle()
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Teacher Review")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            if isEditable {
                Stepper("Rating: \(teacherRating == 0 ? "Not set" : "\(teacherRating)/5")", value: $teacherRating, in: 0...5)
                    .foregroundColor(AppColors.textSecondary)

                TextEditor(text: $teacherReview)
                    .frame(minHeight: 90)
                    .padding(8)
                    .background(AppColors.surface.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )
                    .foregroundColor(AppColors.textPrimary)
            } else {
                if let rating = item.membership.teacherRating {
                    Text("Rating: \(rating)/5")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.gold)
                }
                Text(item.membership.teacherReview.isEmpty ? "No review yet." : item.membership.teacherReview)
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .cardStyle()
    }

    private var spotifySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spotify Study Links")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            ForEach(spotifyLinks) { link in
                HStack {
                    Link(destination: URL(string: link.url) ?? URL(string: "https://open.spotify.com")!) {
                        Text(link.title?.isEmpty == false ? link.title! : link.url)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.gold)
                            .lineLimit(1)
                    }
                    Spacer()
                    if isEditable {
                        Button {
                            spotifyLinks.removeAll { $0.id == link.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(AppColors.error)
                        }
                    }
                }
            }

            if isEditable {
                TextField("https://open.spotify.com/...", text: $newSpotifyURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .modernClassInputField()

                Button("Add Spotify Link") {
                    let trimmed = newSpotifyURL.trimmed
                    guard trimmed.isNotEmpty else { return }
                    guard isValidSpotifyURL(trimmed) else {
                        localError = "Only Spotify links are allowed here."
                        return
                    }
                    spotifyLinks.append(SpotifyLink(url: trimmed))
                    newSpotifyURL = ""
                    localError = nil
                }
                .secondaryButtonStyle()
            }
        }
        .cardStyle()
    }

    private var helpfulSitesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Helpful Websites")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            ForEach(helpfulWebsites) { website in
                HStack {
                    Link(destination: URL(string: website.url) ?? URL(string: "https://example.com")!) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(website.title)
                                .font(AppFonts.body())
                                .foregroundColor(AppColors.textSecondary)
                            Text(website.url)
                                .font(AppFonts.caption())
                                .foregroundColor(AppColors.gold)
                                .lineLimit(1)
                        }
                    }
                    Spacer()
                    if isEditable {
                        Button {
                            helpfulWebsites.removeAll { $0.id == website.id }
                        } label: {
                            Image(systemName: "trash")
                                .foregroundColor(AppColors.error)
                        }
                    }
                }
            }

            if isEditable {
                TextField("Website title", text: $newWebsiteTitle)
                    .modernClassInputField()

                TextField("https://...", text: $newWebsiteURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    .modernClassInputField()

                Button("Add Helpful Website") {
                    let title = newWebsiteTitle.trimmed
                    let url = newWebsiteURL.trimmed
                    guard title.isNotEmpty, url.isNotEmpty else { return }
                    helpfulWebsites.append(HelpfulLink(url: url, title: title))
                    newWebsiteTitle = ""
                    newWebsiteURL = ""
                }
                .secondaryButtonStyle()
            }
        }
        .cardStyle()
    }

    private var editedItemPreview: ProfileClassItem {
        ProfileClassItem(
            global: item.global,
            membership: UserClassMembership(
                id: item.global.id,
                classId: item.global.id,
                teacherReview: teacherReview.trimmed,
                teacherRating: teacherRating == 0 ? nil : teacherRating,
                spotifyLinks: spotifyLinks,
                helpfulWebsites: helpfulWebsites,
                joinedAt: item.membership.joinedAt,
                updatedAt: Date()
            )
        )
    }
}

struct AddClassSheetView: View {
    @Environment(\.dismiss) private var dismiss
    let suggestions: [GlobalClass]
    let onSearchChanged: (String) -> Void
    let onCreate: (String, String, String?, String?) async -> Bool
    let onJoinExisting: (GlobalClass, String) async -> Bool

    @State private var courseCode = ""
    @State private var displayName = ""
    @State private var instructorName = ""
    @State private var selectedSemester = "Spring"
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var isSubmitting = false
    @State private var localErrorMessage: String?

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((2018...currentYear).reversed())
    }

    private var selectedTerm: String {
        "\(selectedSemester) \(selectedYear)"
    }

    private var isCreateDisabled: Bool {
        courseCode.trimmed.isEmpty || isSubmitting
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Add Class")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.textPrimary)

                    TextField("Class code (e.g. CSE20312)", text: $courseCode)
                        .disabled(isSubmitting)
                        .modernClassInputField()
                        .onChange(of: courseCode) { _, newValue in
                            onSearchChanged(newValue)
                        }

                    HStack(spacing: 8) {
                        Picker("Semester", selection: $selectedSemester) {
                            Text("Spring").tag("Spring")
                            Text("Fall").tag("Fall")
                        }
                        .pickerStyle(.segmented)
                        .disabled(isSubmitting)

                        Menu {
                            ForEach(availableYears, id: \.self) { year in
                                Button(String(year)) {
                                    selectedYear = year
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(String(selectedYear))
                                    .font(AppFonts.caption())
                                Image(systemName: "chevron.down")
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(AppColors.surface.opacity(0.88))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(AppColors.borderSubtle, lineWidth: 1)
                            )
                        }
                        .disabled(isSubmitting)
                    }

                    Text("Selected term: \(selectedTerm)")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.gold)

                    TextField("Class name (Optional)", text: $displayName)
                        .disabled(isSubmitting)
                        .modernClassInputField()
                    TextField("Teacher (Optional)", text: $instructorName)
                        .disabled(isSubmitting)
                        .modernClassInputField()

                    Button {
                        Task {
                            await submitClass()
                        }
                    } label: {
                        Label("Create & Join", systemImage: "plus.circle.fill")
                            .font(.headline)
                            .foregroundColor(isCreateDisabled ? AppColors.textSecondary : AppColors.background)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isCreateDisabled ? AppColors.surface : AppColors.gold)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isCreateDisabled)

                    if !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Suggestions")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.textSecondary)

                            ForEach(suggestions, id: \.id) { suggestion in
                                Button {
                                    Task {
                                        await joinExisting(suggestion)
                                    }
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(suggestion.courseCode)
                                                .font(AppFonts.body())
                                                .foregroundColor(AppColors.textPrimary)
                                            if let name = suggestion.displayName, name.isNotEmpty {
                                                Text(name)
                                                    .font(AppFonts.caption())
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                        }
                                        Spacer()
                                        Text("Join")
                                            .font(AppFonts.caption())
                                            .foregroundColor(AppColors.gold)
                                    }
                                    .padding(10)
                                    .background(AppColors.surface.opacity(0.85))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                .disabled(isSubmitting)
                            }
                        }
                    }

                    if let localErrorMessage, localErrorMessage.isNotEmpty {
                        Text(localErrorMessage)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.warning)
                    }
                }
                .padding()
            }
            .background(AppColors.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
            }
        }
    }

    private func submitClass() async {
        isSubmitting = true
        defer { isSubmitting = false }

        let normalizedCourseCode = GlobalClass.normalizedId(from: courseCode)
        let didSave = await onCreate(
            normalizedCourseCode,
            selectedTerm,
            displayName.isNotEmpty ? displayName.trimmed : nil,
            instructorName.isNotEmpty ? instructorName.trimmed : nil
        )

        if didSave {
            localErrorMessage = nil
            dismiss()
        } else {
            localErrorMessage = "Could not add class. Check your connection/permissions and try again."
        }
    }

    private func joinExisting(_ globalClass: GlobalClass) async {
        isSubmitting = true
        defer { isSubmitting = false }
        let didJoin = await onJoinExisting(globalClass, selectedTerm)
        if didJoin {
            localErrorMessage = nil
            dismiss()
        } else {
            localErrorMessage = "Could not join class. Please try again."
        }
    }
}

// MARK: - Catalog Class Picker View

struct CatalogClassPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let catalogCourses: [GlobalClass]
    let isLoading: Bool
    let errorMessage: String?
    @Binding var selectedSchool: CatalogSchool?
    @Binding var searchQuery: String
    let onSchoolChanged: () -> Void
    let onSearchChanged: () -> Void
    let onJoin: (GlobalClass, String) async -> Bool

    @State private var selectedCourse: GlobalClass?
    @State private var selectedSemester = "Spring"
    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var isJoining = false
    @State private var localError: String?

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: Date())
        return Array((2018...currentYear + 1).reversed())
    }

    private var selectedTerm: String {
        "\(selectedSemester) \(selectedYear)"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters Section
                VStack(spacing: 12) {
                    // School Filter
                    Picker("School", selection: $selectedSchool) {
                        Text("All").tag(CatalogSchool?.none)
                        ForEach(CatalogSchool.allCases, id: \.self) { school in
                            Text(school.rawValue).tag(CatalogSchool?.some(school))
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: selectedSchool) { _, _ in
                        onSchoolChanged()
                    }

                    // Search Field
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(AppColors.textSecondary)
                        TextField("Search courses...", text: $searchQuery)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .foregroundColor(AppColors.textPrimary)
                        if !searchQuery.isEmpty {
                            Button {
                                searchQuery = ""
                                onSearchChanged()
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppColors.surface.opacity(0.88))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )
                    .onChange(of: searchQuery) { _, _ in
                        onSearchChanged()
                    }

                    // Term Selector
                    HStack(spacing: 8) {
                        Text("Term:")
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.textSecondary)

                        Picker("Semester", selection: $selectedSemester) {
                            Text("Spring").tag("Spring")
                            Text("Fall").tag("Fall")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 160)

                        Menu {
                            ForEach(availableYears, id: \.self) { year in
                                Button(String(year)) {
                                    selectedYear = year
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(String(selectedYear))
                                    .font(AppFonts.caption())
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                            }
                            .foregroundColor(AppColors.gold)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppColors.surface.opacity(0.88))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding()
                .background(AppColors.backgroundSecondary)

                Divider()
                    .background(AppColors.borderSubtle)

                // Course List
                if isLoading {
                    Spacer()
                    ProgressView()
                        .tint(AppColors.gold)
                    Spacer()
                } else if catalogCourses.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 40))
                            .foregroundColor(AppColors.textTertiary)
                        Text("No courses found")
                            .font(AppFonts.headline())
                            .foregroundColor(AppColors.textPrimary)
                        Text("Try adjusting your filters or search query.")
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(catalogCourses, id: \.id) { course in
                                CatalogCourseRow(
                                    course: course,
                                    isJoining: isJoining && selectedCourse?.id == course.id,
                                    onJoin: {
                                        Task {
                                            await joinCourse(course)
                                        }
                                    }
                                )
                            }
                        }
                        .padding()
                    }
                }

                // Error Messages
                if let error = errorMessage ?? localError, !error.isEmpty {
                    Text(error)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.warning)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(AppColors.surface)
                }
            }
            .background(AppColors.background.ignoresSafeArea())
            .navigationTitle("Add Class")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isJoining)
                }
            }
        }
    }

    private func joinCourse(_ course: GlobalClass) async {
        selectedCourse = course
        isJoining = true
        localError = nil
        defer { isJoining = false }

        let success = await onJoin(course, selectedTerm)
        if success {
            dismiss()
        } else {
            localError = "Could not join \(course.courseCode). Please try again."
        }
    }
}

// MARK: - Catalog Course Row

struct CatalogCourseRow: View {
    let course: GlobalClass
    let isJoining: Bool
    let onJoin: () -> Void

    private var instructorText: String? {
        if !course.instructorNames.isEmpty {
            if course.instructorNames.count == 1 {
                return course.instructorNames[0]
            } else {
                return "\(course.instructorNames[0]) +\(course.instructorNames.count - 1) more"
            }
        } else if let instructor = course.instructorName, !instructor.isEmpty {
            return instructor
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(course.courseCode)
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.textPrimary)

                    if let school = course.catalogSchool {
                        Text(school.shortName)
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(AppColors.background)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                school == .holyCross ? AppColors.gold : AppColors.greenLight
                            )
                            .clipShape(Capsule())
                    }

                    if let credits = course.credits {
                        Text("\(credits) cr")
                            .font(.caption2)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }

                if let displayName = course.displayName, !displayName.isEmpty {
                    Text(displayName)
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(2)
                }

                if let instructor = instructorText {
                    Label(instructor, systemImage: "person.text.rectangle")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textTertiary)
                }

                if course.memberCount > 0 {
                    Text("\(course.memberCount) member\(course.memberCount == 1 ? "" : "s")")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            Spacer()

            Button(action: onJoin) {
                if isJoining {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(AppColors.gold)
                } else {
                    Text("Add")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.gold)
                }
            }
            .frame(width: 60)
            .disabled(isJoining)
        }
        .padding(12)
        .background(AppColors.surface.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
    }
}

private extension View {
    func modernClassInputField() -> some View {
        self
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(AppColors.surface.opacity(0.88))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(AppColors.borderSubtle, lineWidth: 1)
            )
            .foregroundColor(AppColors.textPrimary)
    }
}

