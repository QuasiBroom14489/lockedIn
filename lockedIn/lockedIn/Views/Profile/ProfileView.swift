import SwiftUI

struct ProfileView: View {
    @StateObject private var viewModel = ProfileViewModel()
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showAddClass = false
    @State private var selectedAuthorId: String?
    @State private var selectedClassForDetail: ProfileClassItem?
    @State private var classSuccessMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(AppColors.background)
                } else if let user = viewModel.user {
                    ScrollView {
                        VStack(spacing: 20) {
                            // Profile Header
                            ProfileHeaderView(
                                user: user,
                                followersCount: viewModel.followersCount,
                                followingCount: viewModel.followingCount,
                                isCurrentUser: true,
                                isFollowing: false,
                                onFollowTap: {}
                            )

                            Picker("Profile Section", selection: $viewModel.selectedTab) {
                                ForEach(ProfileTab.allCases, id: \.self) { tab in
                                    Text(tab.rawValue).tag(tab)
                                }
                            }
                            .pickerStyle(.segmented)

                            contentForSelectedTab(user: user)
                        }
                        .padding()
                    }
                } else {
                    ContentUnavailableView(
                        "Profile unavailable",
                        systemImage: "person.crop.circle.badge.exclamationmark"
                    )
                    .background(AppColors.background)
                }
            }
            .background(AppColors.background)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .navigationDestination(item: $selectedAuthorId) { userId in
                OtherUserProfileView(userId: userId)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showEditProfile = true
                        } label: {
                            Label("Edit Profile", systemImage: "pencil")
                        }

                        Button {
                            showSettings = true
                        } label: {
                            Label("Settings", systemImage: "gear")
                        }

                        Divider()

                        Button(role: .destructive) {
                            authViewModel.signOut()
                        } label: {
                            Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView(viewModel: viewModel)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showAddClass) {
            AddClassSheetView(
                suggestions: viewModel.classSuggestions,
                onSearchChanged: { query in
                    Task { await viewModel.searchGlobalClassSuggestions(query: query) }
                },
                onCreate: { courseCode, displayName, instructorName in
                    let didSave = await viewModel.addOrJoinClass(
                        courseCode: courseCode,
                        displayName: displayName,
                        instructorName: instructorName
                    )
                    if didSave {
                        classSuccessMessage = "Class added."
                        selectedClassForDetail = viewModel.classItems.first(where: { $0.global.id == GlobalClass.normalizedId(from: courseCode) })
                    }
                    return didSave
                },
                onJoinExisting: { globalClass in
                    let didSave = await viewModel.addOrJoinClass(
                        courseCode: globalClass.courseCode,
                        displayName: globalClass.displayName,
                        instructorName: globalClass.instructorName
                    )
                    if didSave {
                        classSuccessMessage = "Joined class."
                        selectedClassForDetail = viewModel.classItems.first(where: { $0.global.id == globalClass.id })
                    }
                    return didSave
                }
            )
        }
        .sheet(item: $selectedClassForDetail) { item in
            ClassDetailSheetView(
                item: item,
                isEditable: viewModel.isCurrentUser,
                dashboard: viewModel.classDashboard,
                isLoadingDashboard: viewModel.isLoadingClassDashboard,
                classErrorMessage: viewModel.classErrorMessage,
                period: viewModel.classPeriod,
                userPosts: viewModel.classUserPosts,
                isLoadingUserPosts: viewModel.isLoadingClassPosts,
                isValidSpotifyURL: { FirebaseService.shared.isValidSpotifyURL($0) },
                onPeriodChanged: { period in
                    viewModel.classPeriod = period
                    Task { await viewModel.loadGlobalClassDashboard(classId: item.global.id, period: period) }
                },
                onRefreshDashboard: {
                    Task { await viewModel.loadGlobalClassDashboard(classId: item.global.id, period: viewModel.classPeriod) }
                },
                onSave: { updatedItem in
                    Task { _ = await viewModel.saveMembershipData(for: updatedItem) }
                },
                onDelete: viewModel.isCurrentUser ? {
                    Task { await viewModel.removeClass(classKey: item.global.id) }
                } : nil
            )
        }
        .task {
            await viewModel.loadProfile(userId: nil)
        }
        .onChange(of: viewModel.selectedTab) { _, newTab in
            guard let userId = viewModel.user?.id else { return }

            Task {
                switch newTab {
                case .overview:
                    break
                case .classes:
                    await viewModel.loadClassItems(userId: userId)
                case .posts:
                    await viewModel.loadUserPosts(userId: userId)
                case .saved:
                    await viewModel.loadSavedPosts(userId: userId)
                }
            }
        }
        .refreshable {
            await viewModel.loadProfile(userId: nil)
        }
    }

    @ViewBuilder
    private func contentForSelectedTab(user: User) -> some View {
        switch viewModel.selectedTab {
        case .overview:
            overviewContent(user: user)
        case .classes:
            classesContent
        case .posts:
            postsContent
        case .saved:
            savedContent
        }
    }

    @ViewBuilder
    private func overviewContent(user: User) -> some View {
        VStack(spacing: 24) {
            StatsCard(user: user, animated: true)

            // Badge Showcase
            BadgeShowcaseView(
                badges: buildBadges(for: user)
            )

            if user.screenTimeVisibilityEnabled || viewModel.isCurrentUser {
                ScreenTimeCard(user: user, isCurrentUser: viewModel.isCurrentUser)
            }

            TierProgressCard(points: user.points, tier: user.tier, animated: true)

            if let spotifyURL = user.spotifyPlaylistURL, !spotifyURL.isEmpty {
                SpotifyCard(urlString: spotifyURL)
            }

            let mainTools = user.primaryStudyTools.isEmpty ? user.studyTools : user.primaryStudyTools
            if !mainTools.isEmpty {
                StudyToolsCard(title: "Main Stack / Study Tools", tools: mainTools)
            }

            if !user.studyTools.isEmpty {
                StudyToolsCard(title: "All Study Tools", tools: user.studyTools)
            }

            if let tips = user.tips, !tips.isEmpty {
                TipsCard(tips: tips)
            }

            if !viewModel.recentSessions.isEmpty {
                RecentSessionsCard(sessions: viewModel.recentSessions)
            }
        }
    }

    private func buildBadges(for user: User) -> [BadgeType] {
        var badges: [BadgeType] = []

        // Add tier badge
        badges.append(.tier(user.tier))

        // Add dorm badge if available
        if let dorm = Dorm.from(string: user.dorm) {
            badges.append(.dorm(dorm))
        }

        // Add achievement badges (locked/unlocked based on user progress)
        let totalHours = user.totalFocusedSeconds / 3600

        // Early Adopter - for now, everyone gets it
        var earlyAdopter = AchievementBadge.earlyAdopter
        earlyAdopter.isUnlocked = true
        badges.append(.achievement(earlyAdopter))

        // Centurion - 100+ hours
        var centurion = AchievementBadge.centurion
        centurion.isUnlocked = totalHours >= 100
        badges.append(.achievement(centurion))

        // Night Owl - placeholder, would need session time data
        badges.append(.achievement(AchievementBadge.nightOwl))

        return badges
    }

    @ViewBuilder
    private var classesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Classes")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
                Spacer()
                if viewModel.isCurrentUser {
                    Button {
                        Task { await viewModel.searchGlobalClassSuggestions(query: "") }
                        showAddClass = true
                    } label: {
                        Label("Add Class", systemImage: "plus")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundColor(AppColors.gold)
                }
            }

            if let classSuccessMessage, classSuccessMessage.isNotEmpty {
                Text(classSuccessMessage)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.success)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppColors.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if let classErrorMessage = viewModel.classErrorMessage, classErrorMessage.isNotEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(classErrorMessage)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.warning)
                    Button("Reload Classes") {
                        guard let userId = viewModel.user?.id else { return }
                        Task {
                            await viewModel.loadClassItems(userId: userId)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundColor(AppColors.gold)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if viewModel.classItems.isEmpty {
                EmptyPostsState(
                    title: "No Classes Yet",
                    message: "Add your classes to unlock class dashboards, teacher reviews, and resources."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.classItems, id: \.id) { item in
                        Button {
                            selectedClassForDetail = item
                        } label: {
                            ClassSummaryCard(item: item, dashboard: nil)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var postsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Posts")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textSecondary)

            if viewModel.userPosts.isEmpty {
                EmptyPostsState(
                    title: "No Posts Yet",
                    message: "Share your first stack or suggestion to build your profile."
                )
            } else {
                PostsListView(
                    posts: viewModel.userPosts,
                    onAuthorTap: { post in
                        selectedAuthorId = post.authorId
                    }
                )
            }
        }
    }

    @ViewBuilder
    private var savedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved Posts")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(AppColors.textSecondary)

            if viewModel.savedPosts.isEmpty {
                EmptyPostsState(
                    title: "No Saved Posts",
                    message: "Save useful stacks and tips to revisit them here."
                )
            } else {
                PostsListView(
                    posts: viewModel.savedPosts,
                    isFavoritedPost: { _ in true },
                    onAuthorTap: { post in
                        selectedAuthorId = post.authorId
                    }
                )
            }
        }
    }
}

// MARK: - Profile Header

struct ProfileHeaderView: View {
    let user: User
    let followersCount: Int
    let followingCount: Int
    let isCurrentUser: Bool
    let isFollowing: Bool
    let onFollowTap: () -> Void

    @State private var nameAppeared = false
    @State private var badgesAppeared = false
    @State private var statsAppeared = false

    var body: some View {
        VStack(spacing: 0) {
            // Tier Banner with Avatar
            ZStack(alignment: .bottom) {
                // Full-width tier banner
                TierBannerView(tier: user.tier, height: 130)

                // Enhanced avatar overlapping the banner
                EnhancedTierAvatarView(
                    photoURL: user.photoURL,
                    displayName: user.displayName,
                    tier: user.tier,
                    size: Constants.UI.profileImageSize
                )
                .offset(y: Constants.UI.profileImageSize * 0.5)
            }
            .padding(.bottom, Constants.UI.profileImageSize * 0.5)

            // Name and Info with staggered animation
            VStack(spacing: 10) {
                Text(user.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundColor(AppColors.textPrimary)
                    .opacity(nameAppeared ? 1 : 0)
                    .offset(y: nameAppeared ? 0 : 10)

                // Tier Title
                TierTitleView(tier: user.tier)
                    .opacity(nameAppeared ? 1 : 0)
                    .offset(y: nameAppeared ? 0 : 10)

                // Dorm Badge
                if user.dorm != nil {
                    ProfileDormBadge(dormString: user.dorm)
                        .opacity(badgesAppeared ? 1 : 0)
                        .scaleEffect(badgesAppeared ? 1 : 0.8)
                }

                // Year and Major
                let profileFacts = [user.year, user.major]
                    .compactMap { value -> String? in
                        guard let value, value.isNotEmpty else { return nil }
                        return value
                    }

                if !profileFacts.isEmpty {
                    Text(profileFacts.joined(separator: " • "))
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textSecondary)
                        .opacity(badgesAppeared ? 1 : 0)
                }
            }
            .padding(.top, 12)

            // Followers/Following with animated numbers
            HStack(spacing: 40) {
                StatPill(value: followersCount, label: "Followers", appeared: statsAppeared)
                StatPill(value: followingCount, label: "Following", appeared: statsAppeared, delay: 0.1)
            }
            .padding(.top, 20)
            .opacity(statsAppeared ? 1 : 0)
            .offset(y: statsAppeared ? 0 : 15)

            // Follow Button (for other users)
            if !isCurrentUser {
                Button(action: onFollowTap) {
                    HStack(spacing: 6) {
                        Image(systemName: isFollowing ? "checkmark" : "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text(isFollowing ? "Following" : "Follow")
                            .font(.headline)
                    }
                    .foregroundColor(isFollowing ? AppColors.textPrimary : AppColors.background)
                    .frame(width: 130, height: 40)
                    .background(
                        isFollowing ?
                        AnyShapeStyle(AppColors.surface) :
                        AnyShapeStyle(
                            LinearGradient(
                                colors: [AppColors.gold, AppColors.goldLight],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    )
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(isFollowing ? AppColors.borderSubtle : Color.clear, lineWidth: 1)
                    )
                    .shadow(color: isFollowing ? .clear : AppColors.gold.opacity(0.3), radius: 8)
                }
                .padding(.top, 20)
                .opacity(statsAppeared ? 1 : 0)
                .scaleEffect(statsAppeared ? 1 : 0.9)
            }
        }
        .padding(.bottom, 20)
        .background(AppColors.surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.borderSubtle, lineWidth: 1)
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.4).delay(0.2)) {
                nameAppeared = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.35)) {
                badgesAppeared = true
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.5)) {
                statsAppeared = true
            }
        }
    }
}

// MARK: - Stat Pill

struct StatPill: View {
    let value: Int
    let label: String
    let appeared: Bool
    var delay: Double = 0

    @State private var animatedValue: Int = 0

    var body: some View {
        VStack(spacing: 4) {
            Text("\(animatedValue)")
                .font(.title3.weight(.bold))
                .foregroundColor(AppColors.textPrimary)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.background.opacity(0.5))
        )
        .onChange(of: appeared) { _, newValue in
            if newValue {
                animateCount()
            }
        }
    }

    private func animateCount() {
        let steps = 20
        let duration = 0.8
        let stepDuration = duration / Double(steps)

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + stepDuration * Double(step)) {
                withAnimation(.easeOut(duration: stepDuration)) {
                    let progress = Double(step) / Double(steps)
                    let eased = 1 - pow(1 - progress, 3)
                    animatedValue = Int(Double(value) * eased)
                }
            }
        }
    }
}

// MARK: - Stats Card

struct StatsCard: View {
    let user: User
    var animated: Bool = false

    @State private var appeared = false
    @State private var clockRotation: Double = 0
    @State private var flameScale: CGFloat = 1.0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with icon
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColors.gold.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.gold)
                }

                Text("Focus Stats")
                    .font(.headline.weight(.bold))
                    .foregroundColor(AppColors.textPrimary)

                Spacer()
            }

            // Stats Grid
            HStack(spacing: 16) {
                // Total Time
                GlassStatCard(
                    icon: "clock.fill",
                    iconRotation: clockRotation,
                    value: animated ? user.totalFocusedSeconds : nil,
                    displayValue: user.formattedTotalTime,
                    label: "Total Time",
                    color: AppColors.gold,
                    appeared: appeared
                )

                // Streak
                GlassStatCard(
                    icon: "flame.fill",
                    iconScale: flameScale,
                    value: animated ? user.currentStreak : nil,
                    displayValue: "\(user.currentStreak)",
                    label: "Streak",
                    suffix: user.currentStreak == 1 ? "day" : "days",
                    color: .orange,
                    appeared: appeared,
                    delay: 0.1,
                    isStreak: true
                )

                // Sessions (bonus stat)
                GlassStatCard(
                    icon: "target",
                    value: nil,
                    displayValue: "\(user.points)",
                    label: "Points",
                    color: AppColors.greenLight,
                    appeared: appeared,
                    delay: 0.2
                )
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: [AppColors.surfaceElevated.opacity(0.9), AppColors.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.gold.opacity(0.2), AppColors.borderSubtle],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }

            // Animate clock icon
            withAnimation(
                .linear(duration: 4)
                .repeatForever(autoreverses: false)
            ) {
                clockRotation = 360
            }

            // Animate flame icon
            withAnimation(
                .easeInOut(duration: 1)
                .repeatForever(autoreverses: true)
            ) {
                flameScale = 1.15
            }
        }
    }
}

// MARK: - Glass Stat Card

struct GlassStatCard: View {
    let icon: String
    var iconRotation: Double = 0
    var iconScale: CGFloat = 1.0
    let value: Int?
    let displayValue: String
    let label: String
    var suffix: String? = nil
    let color: Color
    let appeared: Bool
    var delay: Double = 0
    var isStreak: Bool = false

    @State private var animatedValue: Int = 0
    @State private var showValue = false
    @State private var fireParticles: [FireParticle] = []

    var body: some View {
        VStack(spacing: 10) {
            // Icon with glow and fire particles for streak
            ZStack {
                // Fire particles for streak
                if isStreak && animatedValue > 0 {
                    ForEach(fireParticles) { particle in
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.orange, .red.opacity(0)],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: particle.size
                                )
                            )
                            .frame(width: particle.size * 2, height: particle.size * 2)
                            .offset(x: particle.x, y: particle.y)
                            .opacity(particle.opacity)
                    }
                }

                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 44, height: 44)
                    .blur(radius: 4)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isStreak ?
                        AnyShapeStyle(
                            LinearGradient(
                                colors: [.yellow, .orange, .red],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        ) :
                        AnyShapeStyle(color)
                    )
                    .rotationEffect(.degrees(iconRotation))
                    .scaleEffect(iconScale)
                    .shadow(color: isStreak ? .orange.opacity(0.6) : .clear, radius: 4)
            }

            // Value with suffix
            HStack(spacing: 4) {
                if let value = value, showValue {
                    Text("\(animatedValue)")
                        .font(.title3.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                        .contentTransition(.numericText())
                } else {
                    Text(displayValue)
                        .font(.title3.weight(.bold))
                        .foregroundColor(AppColors.textPrimary)
                }

                if let suffix = suffix {
                    Text(suffix)
                        .font(.caption.weight(.medium))
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            // Label
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(AppColors.background.opacity(0.4))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isStreak && animatedValue > 0 ?
                    LinearGradient(
                        colors: [.orange.opacity(0.3), .red.opacity(0.2)],
                        startPoint: .top,
                        endPoint: .bottom
                    ) :
                    LinearGradient(colors: [color.opacity(0.1), color.opacity(0.1)], startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
        )
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 15)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(delay), value: appeared)
        .onChange(of: appeared) { _, newValue in
            if newValue, let value = value {
                showValue = true
                animateCount(to: value)
                if isStreak {
                    startFireAnimation()
                }
            }
        }
    }

    private func animateCount(to target: Int) {
        let steps = 25
        let duration = 1.0
        let stepDuration = duration / Double(steps)

        for step in 0...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay + stepDuration * Double(step)) {
                withAnimation(.easeOut(duration: stepDuration)) {
                    let progress = Double(step) / Double(steps)
                    let eased = 1 - pow(1 - progress, 3)
                    animatedValue = Int(Double(target) * eased)
                }
            }
        }
    }

    private func startFireAnimation() {
        // Generate initial particles
        fireParticles = (0..<6).map { _ in
            FireParticle(
                x: CGFloat.random(in: -15...15),
                y: CGFloat.random(in: -25...(-5)),
                size: CGFloat.random(in: 3...6),
                opacity: 0
            )
        }

        // Animate particles
        for (index, _) in fireParticles.enumerated() {
            withAnimation(
                .easeOut(duration: 1.5)
                .repeatForever(autoreverses: false)
                .delay(Double(index) * 0.2)
            ) {
                fireParticles[index].y = -35
                fireParticles[index].opacity = 0.6
            }
        }
    }
}

struct FireParticle: Identifiable {
    let id = UUID()
    var x: CGFloat
    var y: CGFloat
    var size: CGFloat
    var opacity: Double
}

struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(AppColors.gold)
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(AppColors.textPrimary)
            }
            Text(label)
                .font(AppFonts.caption())
                .foregroundColor(AppColors.textSecondary)
        }
    }
}

// MARK: - Screen Time Card

struct ScreenTimeCard: View {
    let user: User
    var isCurrentUser: Bool = true

    private var productiveMinutes: Int {
        max(user.dailyProductiveMinutes, 0)
    }

    private var nonProductiveMinutes: Int {
        max(user.dailyNonProductiveMinutes, 0)
    }

    private var totalMinutes: Int {
        productiveMinutes + nonProductiveMinutes
    }

    private var productiveRatio: Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(productiveMinutes) / Double(totalMinutes)
    }

    private var nonProductiveRatio: Double {
        guard totalMinutes > 0 else { return 0 }
        return Double(nonProductiveMinutes) / Double(totalMinutes)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Screen Time")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)

                Spacer()

                if let updatedAt = user.screenTimeUpdatedAt {
                    Text("Updated \(updatedAt.timeAgoString())")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.textTertiary)
                }
            }

            if totalMinutes == 0 {
                Text("No screen time data available yet.")
                    .font(AppFonts.body())
                    .foregroundColor(AppColors.textSecondary)
            } else {
                VStack(spacing: 10) {
                    GeometryReader { geometry in
                        let productiveWidth = geometry.size.width * productiveRatio
                        let nonProductiveWidth = geometry.size.width * nonProductiveRatio

                        HStack(spacing: 0) {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.success)
                                .frame(width: productiveWidth)

                            RoundedRectangle(cornerRadius: 8)
                                .fill(AppColors.warning)
                                .frame(width: nonProductiveWidth)
                        }
                        .frame(height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .frame(height: 12)

                    HStack(spacing: 12) {
                        LegendItem(
                            color: AppColors.success,
                            title: "Productive",
                            value: "\(productiveMinutes)m"
                        )

                        Spacer()

                        LegendItem(
                            color: AppColors.warning,
                            title: "Non-Productive",
                            value: "\(nonProductiveMinutes)m"
                        )
                    }
                }
            }

            if isCurrentUser && !user.screenTimeVisibilityEnabled {
                Text("Your screen time is hidden from other users.")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textTertiary)
            }
        }
        .cardStyle()
    }
}

private struct LegendItem: View {
    let color: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.textSecondary)

                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
            }
        }
    }
}

struct EmptyPostsState: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "tray")
                .font(.system(size: 32))
                .foregroundColor(AppColors.textTertiary)

            Text(title)
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            Text(message)
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .cardStyle()
    }
}

// MARK: - Spotify Card

struct SpotifyCard: View {
    let urlString: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "music.note")
                    .foregroundColor(AppColors.greenLight)
                Text("Study Playlist")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
            }

            Link(destination: URL(string: urlString) ?? URL(string: "https://spotify.com")!) {
                HStack {
                    Text("Open in Spotify")
                        .font(AppFonts.body())
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .foregroundColor(AppColors.gold)
            }
        }
        .cardStyle()
    }
}

// MARK: - Study Tools Card

struct StudyToolsCard: View {
    var title: String = "Study Tools"
    let tools: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            FlowLayout(spacing: 8) {
                ForEach(tools, id: \.self) { tool in
                    Text(tool)
                        .font(AppFonts.caption())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(AppColors.gold.opacity(0.15))
                        .foregroundColor(AppColors.gold)
                        .cornerRadius(16)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Tips Card

struct TipsCard: View {
    let tips: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(AppColors.gold)
                Text("Study Tips")
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.textPrimary)
            }

            Text(tips)
                .font(AppFonts.body())
                .foregroundColor(AppColors.textSecondary)
        }
        .cardStyle()
    }
}

// MARK: - Recent Sessions Card

struct RecentSessionsCard: View {
    let sessions: [FocusSession]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Sessions")
                .font(AppFonts.headline())
                .foregroundColor(AppColors.textPrimary)

            ForEach(sessions) { session in
                HStack {
                    VStack(alignment: .leading) {
                        Text(session.formattedDuration)
                            .font(.headline)
                            .foregroundColor(AppColors.textPrimary)
                        Text(session.relativeTimeString)
                            .font(AppFonts.caption())
                            .foregroundColor(AppColors.textSecondary)
                    }

                    Spacer()

                    if session.verified {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(AppColors.success)
                    }
                }
                .padding(.vertical, 4)

                if session.id != sessions.last?.id {
                    Divider()
                        .background(AppColors.borderSubtle)
                }
            }
        }
        .cardStyle()
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                       y: bounds.minY + result.positions[index].y),
                          proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + rowHeight
        }
    }
}

// MARK: - Settings View

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var spotifyAuth = SpotifyAuthManager.shared

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Button("Change Password") {
                        // TODO: Implement password change
                    }

                    Button("Change Email") {
                        // TODO: Implement email change
                    }
                }

                Section {
                    HStack {
                        Image(systemName: "music.note")
                            .foregroundColor(AppColors.greenLight)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Spotify")
                                .foregroundColor(AppColors.textPrimary)

                            if spotifyAuth.isConnected {
                                Text("Connected")
                                    .font(.caption)
                                    .foregroundColor(AppColors.success)
                            } else {
                                Text("Not connected")
                                    .font(.caption)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }

                        Spacer()

                        if spotifyAuth.isConnected {
                            Button("Disconnect") {
                                spotifyAuth.disconnect()
                            }
                            .font(.subheadline)
                            .foregroundColor(AppColors.error)
                        } else {
                            Button {
                                spotifyAuth.initiateConnection()
                            } label: {
                                if spotifyAuth.isConnecting {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("Connect")
                                        .font(.subheadline)
                                        .foregroundColor(AppColors.greenLight)
                                }
                            }
                            .disabled(spotifyAuth.isConnecting)
                        }
                    }

                    if let error = spotifyAuth.connectionError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppColors.warning)
                    }

                    if !spotifyAuth.isSpotifyInstalled() {
                        HStack(spacing: 6) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.caption)
                            Text("Spotify app not installed")
                                .font(.caption)
                        }
                        .foregroundColor(AppColors.warning)
                    }
                } header: {
                    Text("Music Integration")
                } footer: {
                    Text("Connect Spotify to control playback during focus sessions without leaving the app.")
                }

                Section("Notifications") {
                    Toggle("Session Reminders", isOn: .constant(true))
                    Toggle("Leaderboard Updates", isOn: .constant(true))
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        authViewModel.signOut()
                        dismiss()
                    }
                }

                Section {
                    Button("Delete Account", role: .destructive) {
                        // TODO: Implement account deletion
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
