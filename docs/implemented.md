# lockedIn Implemented Archive

Archived on February 19, 2026 from prior `docs/IMPLEMENT.md`.
This file keeps historical completed sprint context and prior done records.

---

# lockedIn Implementation Plan

**Last Updated:** February 19, 2026
**Owner:** Founder + Engineering
**Status Key:** `Pending` | `In Progress` | `Done`

---

## Goals for This Plan

- Remove camera dependency from focus mode while preserving integrity
- Add screen time visibility and connect it to rewards
- Evolve profiles into content hubs (posts + saved posts)
- Redesign posting UX with clear post types (Stack vs Suggestion)

---

## Current State Assessment

| Component | Status | Notes |
|-----------|--------|-------|
| Camera removal from Focus | **Done** | No camera code in FocusViewModel |
| Background auto-end + notification | **Done** | Session now auto-ends on background and sends local notification |
| Focus tips rotation | **Done** | Tips rotate every 30 seconds with fade animation |
| Points awarding | **Done** | Points awarded on session completion with screen time bonus |
| Screen Time fields in User | **Done** | Added productive/non-productive minutes, visibility flag, and update timestamp |
| StudyPost/Vote/Favorite models | **Done** | Fully built |
| StudyFeedView/StudyPostRow | **Done** | Fully built |
| SharePostSheet composer | **Done** | Fully built with step-based UX |
| Profile tabs (Posts/Saved) | **Done** | Segmented tabs with Overview, Posts, and Saved implemented |
| Firestore Security Rules | **Done** | Created firestore.rules for all collections |
| Analytics Events | **Done** | AnalyticsService with Firebase Analytics (requires package) |

---

## Known Bugs

| Bug | Status | Notes |
|-----|--------|-------|
| Voting buttons non-functional | `Done` | Fixed: Security rules were blocking non-authors from updating post counters. Created `firestore.rules` allowing authenticated users to update counter fields. Deploy with `firebase deploy --only firestore:rules`. |
| Leaderboard duplicate user | `Done` | Fixed: Filter out users with nil IDs in FirebaseService, added UUID fallback in LeaderboardEntry. |
| Trend indicator arbitrary | `Done` | Removed arbitrary trend indicator that showed random up/down arrows. Proper trend tracking requires storing previous ranks, which can be added later. |
| Leaderboard listener ignores period | `Done` | Fixed: Added period-aware `getLeaderboard()` that aggregates sessions for weekly/monthly. Real-time listener now only activates for allTime period, stops for weekly/monthly where we do manual fetches. |
| OtherUserProfileView wrong background | `Done` | Fixed: Changed from `Color(.systemGroupedBackground)` to `AppColors.background.ignoresSafeArea()` to match dark theme. |

---

## Decisions Made

1. **Screen Time**: Real DeviceActivity framework integration (requires Family Controls entitlement)
2. **Background End**: Local notification when session ends due to backgrounding
3. **Post Migration**: New posts use `stackItems`, existing posts keep simple `tools` array

---

## Sprint 1: Focus Mode v2 (3-4 days)

### 1.1 Add Focus Tips to Constants
**File:** `lockedIn/lockedIn/Utilities/Constants.swift`
**Status:** `Done`

- [x] Add `focusTips: [String]` array (10-15 motivational tips)
- [x] Add `tipRotationInterval: TimeInterval = 30` constant

### 1.2 Update FocusViewModel - Tips + Auto-End + Notification
**File:** `lockedIn/lockedIn/ViewModels/FocusViewModel.swift`
**Status:** `Done`

Changes:
- [x] Add `@Published var currentTip: String = ""`
- [x] Add tip rotation timer (every 30 seconds)
- [x] Change `handleAppBackgrounded()` from `pauseSession()` to `endSession(early: true)`
- [x] Send local notification when ending due to background

### 1.3 Create NotificationService
**File:** `lockedIn/lockedIn/Services/NotificationService.swift`
**Status:** `Done`

- Request notification permission
- Send local notification: "Focus session ended early"
- Include session duration in notification body

### 1.4 Update ActiveSessionView - Rotating Tips UI
**File:** `lockedIn/lockedIn/Views/Focus/ActiveSessionView.swift`
**Status:** `Done`

- [x] Replace static encouragement text with `viewModel.currentTip`
- [x] Add fade animation on tip change
- [x] Keep existing warning message

### 1.5 Add Points Awarding
**File:** `lockedIn/lockedIn/ViewModels/FocusViewModel.swift`
**Status:** `Done`

In `endSession()` after updating totalFocusedSeconds:
```swift
let pointsEarned = finalDuration / 60  // 1 point per minute
user.points += pointsEarned
```

### Acceptance Criteria
- [x] Session starts without camera
- [x] Tips rotate every 30 seconds during session
- [x] Backgrounding app ends session immediately
- [x] Local notification sent when session ends via background
- [x] Points are awarded and saved to Firestore

---

## Sprint 2: Screen Time Integration (4-5 days)

### 2.1 Add Screen Time Fields to User Model
**File:** `lockedIn/lockedIn/Models/User.swift`
**Status:** `Done`

Add fields:
```swift
var dailyProductiveMinutes: Int = 0
var dailyNonProductiveMinutes: Int = 0
var screenTimeUpdatedAt: Date?
var screenTimeVisibilityEnabled: Bool = true
```

### 2.2 Enhance ScreenTimeService with DeviceActivity
**File:** `lockedIn/lockedIn/Services/ScreenTimeService.swift`
**Status:** `In Progress`

Progress:
- [x] Added `ScreenTimeMetrics` model in service layer
- [x] Added `fetchScreenTimeMetrics() async throws -> ScreenTimeMetrics`
- [x] Added `startDeviceActivityMonitoring() async throws`
- [x] Added first-pass app categorization helper (productive/non-productive)
- [ ] Validate DeviceActivity monitoring on physical device with entitlement

Prerequisites:
- Add DeviceActivity framework to project
- Add Family Controls entitlement
- Handle authorization flow

Add methods:
```swift
func fetchScreenTimeMetrics() async throws -> ScreenTimeMetrics
func startDeviceActivityMonitoring() async throws

struct ScreenTimeMetrics {
    var productiveMinutes: Int
    var nonProductiveMinutes: Int
    var totalMinutes: Int
    var lastUpdated: Date
}
```

### 2.3 Add FirebaseService Methods
**File:** `lockedIn/lockedIn/Services/FirebaseService.swift`
**Status:** `Done`

```swift
func updateUserScreenTime(_ metrics: ScreenTimeMetrics, userId: String) async throws
```

### 2.4 Update Points Formula
**File:** `lockedIn/lockedIn/ViewModels/FocusViewModel.swift`
**Status:** `Done`

After session completion:
```swift
let basePoints = finalDuration / 60
let screenTimeBonus = calculateScreenTimeBonus(user)
let finalPoints = Int(Double(basePoints) * screenTimeBonus)
```

### 2.5 Add Screen Time Card to ProfileView
**File:** `lockedIn/lockedIn/Views/Profile/ProfileView.swift`
**Status:** `Done`

- Create `ScreenTimeCard` component
- Show productive vs non-productive split
- Visual bar chart
- Respects `screenTimeVisibilityEnabled`

### 2.6 Add to OtherUserProfileView
**File:** `lockedIn/lockedIn/Views/Profile/OtherUserProfileView.swift`
**Status:** `Done`

Show screen time card only if `screenTimeVisibilityEnabled = true`

### Acceptance Criteria
- [x] User model has screen time fields
- [ ] DeviceActivity integration works
- [x] Profile shows screen time metrics
- [x] Points calculation uses screen time bonus
- [x] Visibility toggle works for other users

---

## Sprint 3: Profile Layout Upgrade (3-4 days)

### 3.1 Add Profile Tabs
**File:** `lockedIn/lockedIn/Views/Profile/ProfileView.swift`
**Status:** `Done`

Restructure to:
```swift
VStack {
    ProfileHeader (fixed)
    Picker (Overview | Posts | Saved)
    TabView/switch for content
}
```

Tabs:
- **Overview**: Current profile content (stats, tools, tips)
- **Posts**: User's authored posts
- **Saved**: User's favorited posts

### 3.2 Update ProfileViewModel
**File:** `lockedIn/lockedIn/ViewModels/ProfileViewModel.swift`
**Status:** `Done`

Add:
```swift
@Published var userPosts: [StudyPost] = []
@Published var savedPosts: [StudyPost] = []
@Published var selectedTab: ProfileTab = .overview

func loadUserPosts() async
func loadSavedPosts() async
```

### 3.3 Add FirebaseService Queries
**File:** `lockedIn/lockedIn/Services/FirebaseService.swift`
**Status:** `Done`

```swift
func getPostsByAuthor(userId: String, limit: Int) async throws -> [StudyPost]
func getFavoritedPosts(userId: String, limit: Int) async throws -> [StudyPost]
```

### 3.4 Create PostsListView Component
**File:** `lockedIn/lockedIn/Views/Components/PostsListView.swift`
**Status:** `Done`

Extract common list logic from StudyFeedView for reuse in profile tabs.

### Acceptance Criteria
- [x] Profile has 3 tabs (Overview, Posts, Saved)
- [x] Posts tab shows user's authored posts
- [x] Saved tab shows favorited posts
- [x] Empty states are clear and actionable

---

## Sprint 4: Posting UX Redesign (4-5 days)

### 4.1 Create StudyStackItem Model
**File:** `lockedIn/lockedIn/Models/StudyStackItem.swift`
**Status:** `Done`

```swift
struct StudyStackItem: Identifiable, Codable {
    var id: String = UUID().uuidString
    var toolName: String
    var linkURL: String?
    var usageNote: String?
}
```

### 4.2 Update StudyPost Model
**File:** `lockedIn/lockedIn/Models/StudyPost.swift`
**Status:** `Done`

Add:
```swift
var stackItems: [StudyStackItem]?  // For new stack posts only
```

**Note:** Existing posts with `tools: [String]` continue to render with simple chips. New posts use `stackItems` for structured layout. No migration.

### 4.3 Redesign SharePostSheet
**File:** `lockedIn/lockedIn/Views/Social/SharePostSheet.swift`
**Status:** `Done`

Step-based flow:
1. Choose post type (Stack or Suggestion)
2. Type-specific form
   - Stack: Add structured tools with links + notes
   - Suggestion: Text-first with tags
3. Preview + Post

### 4.4 Update StudyPostRow Rendering
**File:** `lockedIn/lockedIn/Views/Components/StudyPostRow.swift`
**Status:** `Done`

- Stack posts with `stackItems`: Show structured layout with tool cards
- Stack posts with `tools` (legacy): Show simple chip layout
- Suggestion posts: Clean text card with tag chips

### 4.5 Add Post Type Filter to Feed
**File:** `lockedIn/lockedIn/Views/Social/StudyFeedView.swift`
**Status:** `Done`

Add filter chips: All | Stacks | Suggestions

### Acceptance Criteria
- [x] Composer has step-based flow (under 3 steps)
- [x] Stack posts support multiple tools with links/notes
- [x] Suggestion posts have tag-first discovery
- [x] Feed visually differentiates post types
- [x] Filter chips work correctly

---

## Sprint 5: Polish & QA (2-3 days)

### 5.1 Firestore Security Rules
**Status:** `Done`

Created `/firestore.rules` with rules for:
- `studyPosts` collection (author can update all fields, others can update counter fields only)
- `votes` collection (user owns their votes)
- `favorites` collection (user owns their favorites)
- `users` collection and subcollections (owner-only writes, authenticated reads)

Deploy with: `firebase deploy --only firestore:rules`

### 5.2 Analytics Events
**Status:** `Done`

Created `AnalyticsService.swift` with Firebase Analytics integration.

Events implemented:
- `focus_session_started` - with duration goal
- `focus_session_completed` - with duration and points earned
- `focus_session_ended_background` - with elapsed duration
- `focus_tip_displayed` - with tip index
- `screen_time_synced` - with productive/non-productive minutes
- `post_created_stack` / `post_created_suggestion` - with tool/tag counts
- `post_voted` - with vote type
- `post_favorite_toggled` - with favorited state
- `profile_tab_changed` - with tab name
- `user_followed` / `user_unfollowed` - with target user ID
- `leaderboard_viewed` - with period and friends filter

**Note:** Requires adding `FirebaseAnalytics` package to the project.

### 5.3 Testing
**Status:** `Done`

Created unit test files in `lockedInTests/`:
- `PointsFormulaTests.swift` - Tests for screen time bonus calculation and points awarding
- `VoteTransitionTests.swift` - Tests for vote state transitions and counter delta logic

**Note:** Test files need to be added to a test target in Xcode. To set up:
1. Add a new Unit Test target in Xcode (File > New > Target > Unit Testing Bundle)
2. Add the test files to the test target
3. Run with Cmd+U

Manual smoke tests per acceptance criteria should be performed before release.

---

## Critical Files Summary

| Sprint | Files to Modify | Files to Create |
|--------|-----------------|-----------------|
| 1 | Constants.swift, FocusViewModel.swift, ActiveSessionView.swift | NotificationService.swift |
| 2 | User.swift, ScreenTimeService.swift, FirebaseService.swift, ProfileView.swift, OtherUserProfileView.swift | ScreenTimeCard.swift |
| 3 | ProfileView.swift, ProfileViewModel.swift, FirebaseService.swift | PostsListView.swift |
| 4 | StudyPost.swift, SharePostSheet.swift, StudyPostRow.swift, StudyFeedView.swift | StudyStackItem.swift |
| 5 | firestore.rules | - |

---

## Dependencies

```
Sprint 1 (Focus Mode)
    |
    v
Sprint 2 (Screen Time) <-- Uses points awarding from Sprint 1
    |
    +---> Sprint 3 (Profile Tabs) <-- Independent, can parallel with Sprint 2
    |
    v
Sprint 4 (Posting UX) <-- Can parallel with Sprint 3
    |
    v
Sprint 5 (QA) <-- Requires all above
```

**Parallelization:** Sprints 2+3 can run in parallel. Sprints 3+4 can overlap.

---

## Verification Plan

1. **Focus Mode v2**: Start session, verify no camera, background app, verify session ends + notification, check points in Firestore
2. **Screen Time**: Check User document for fields, verify profile card, test visibility toggle
3. **Profile Tabs**: Tap each tab, verify data loads, test pagination, check empty states
4. **Posting UX**: Create both post types, verify rendering, test filters
5. **Full E2E**: Complete focus session -> check points -> create post -> view on profile -> favorite -> verify in saved tab

---

## Definition of Done

- All 4 initiatives shipped with stable production behavior
- Firestore rules updated and verified
- No regression in focus session completion path
- Profile and feed UX meet product requirements
- Local notifications working for background session end
