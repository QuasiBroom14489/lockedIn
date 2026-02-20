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
                    .modernClassInputField()
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

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
                    .modernClassInputField()
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)

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
    let onCreate: (String, String?, String?) async -> Bool
    let onJoinExisting: (GlobalClass) async -> Bool

    @State private var courseCode = ""
    @State private var displayName = ""
    @State private var instructorName = ""
    @State private var isSubmitting = false
    @State private var localErrorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Course code (e.g. CSE20312)", text: $courseCode)
                    .disabled(isSubmitting)
                    .onChange(of: courseCode) { _, newValue in
                        onSearchChanged(newValue)
                    }
                TextField("Class name (Optional)", text: $displayName)
                    .disabled(isSubmitting)
                TextField("Instructor (Optional)", text: $instructorName)
                    .disabled(isSubmitting)

                if !suggestions.isEmpty {
                    Section("Suggestions") {
                        ForEach(suggestions, id: \.id) { suggestion in
                            Button {
                                Task {
                                    await joinExisting(suggestion)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.courseCode)
                                    if let name = suggestion.displayName, name.isNotEmpty {
                                        Text(name)
                                            .font(AppFonts.caption())
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                            }
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
            .navigationTitle("Add Class")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create & Join") {
                        Task {
                            await submitClass()
                        }
                    }
                    .disabled(courseCode.trimmed.isEmpty || isSubmitting)
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
        let didJoin = await onJoinExisting(globalClass)
        if didJoin {
            localErrorMessage = nil
            dismiss()
        } else {
            localErrorMessage = "Could not join class. Please try again."
        }
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
