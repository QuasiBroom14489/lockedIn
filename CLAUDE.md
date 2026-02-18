# lockedIn

A study resource discovery platform for Notre Dame students. Users find tools, methods, and techniques that worked for others through verified academic success and shared Study Stacks.

## Vision & Strategy

### Core Value Proposition
Help students discover study resources through social proof - find what works from people who succeeded in your classes.

### The Engagement Loop
```
Study (timer) → Prove Success (grades) → Share What Worked (Study Stack) → Others Discover → They Study
```

### Target Users
1. **High achievers** - Want recognition, competitive (leaderboard appeals to them)
2. **Struggling students** - Need help but afraid to ask directly (browse profiles anonymously)
3. **Resource seekers** - Looking for proven tools/methods for specific classes

### Monetization Model
- **Freemium** - Basic features free, premium unlocks advanced discovery
- **Ads** - On free tier (feed, Study Stack views) but NOT during focus sessions

#### Free Tier
- Focus timer + basic leaderboard
- View Study Stacks (limited views/day)
- Add classes to profile (unverified)
- Basic search by class name

#### Premium Tier (~$4.99/mo or $29.99/yr)
- Unlimited Study Stack views
- Filter by grade (show A students in specific class)
- Filter by professor
- Detailed stats (avg study time for A vs B students)
- Ad-free experience
- "Pro" profile badge

### Scale Strategy
- Launch at Notre Dame (target syllabus week for high anxiety/demand)
- Dorm competitions for viral growth
- Expand to other universities after product-market fit

## Tech Stack

- **Platform**: iOS 17.0+
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI
- **Backend**: Firebase (Auth, Firestore, Storage)
- **Architecture**: MVVM with Combine
- **IDE**: Xcode 15.0+

## Project Structure

```
lockedIn/lockedIn/lockedIn/
├── App/
│   ├── lockedInApp.swift          # App entry point, Firebase config, dark mode
│   └── ContentView.swift          # Main TabView (Focus, Leaderboard, Activity, Profile)
├── Models/
│   ├── User.swift                 # User profile with @DocumentID, points, tier
│   ├── FocusSession.swift         # Focus session + FeedItem
│   ├── StatusTier.swift           # Tier enum, cosmetics, points system
│   ├── StudyPost.swift            # Discover feed post (planned)
│   ├── Vote.swift                 # Upvote/downvote on posts (planned)
│   ├── Favorite.swift             # Bookmarked posts (planned)
│   ├── UserClass.swift            # Class with grade + Study Stack (planned)
│   ├── Dorm.swift                 # Dorm for competitions (planned)
│   └── LeaderboardEntry.swift     # Leaderboard row model
├── Views/
│   ├── Auth/
│   │   ├── LoginView.swift
│   │   └── SignUpView.swift
│   ├── Focus/
│   │   ├── FocusTimerView.swift   # Timer setup
│   │   ├── ActiveSessionView.swift # Running session with camera
│   │   └── SessionCompleteView.swift
│   ├── Leaderboard/
│   │   └── LeaderboardView.swift  # Rankings with time filters
│   ├── Profile/
│   │   ├── ProfileView.swift      # Current user profile
│   │   ├── EditProfileView.swift
│   │   └── OtherUserProfileView.swift
│   ├── Social/
│   │   ├── FeedView.swift         # Activity feed (legacy)
│   │   ├── StudyFeedView.swift    # Discover feed (planned)
│   │   ├── StudyPostRow.swift     # Post card component (planned)
│   │   ├── FavoritesView.swift    # Saved posts view (planned)
│   │   ├── SharePostSheet.swift   # Share stack/tips form (planned)
│   │   ├── SearchUsersView.swift
│   │   └── FollowersListView.swift
│   ├── Components/
│   │   ├── TierRingView.swift     # Avatar ring with tier styling
│   │   ├── TierProgressCard.swift # Points + progress to next tier
│   │   ├── TierBadgeView.swift    # Inline tier badges
│   │   └── CloverView.swift       # ND shamrock accent component
│   ├── Classes/                   # (planned)
│   │   ├── AddClassView.swift
│   │   ├── ClassDetailView.swift
│   │   └── VerifyGradeView.swift
│   └── Discovery/                 # (planned)
│       ├── ClassSearchView.swift
│       └── StudyStackView.swift
├── ViewModels/
│   ├── AuthViewModel.swift        # Auth state + form validation
│   ├── FocusViewModel.swift       # Session timer logic
│   ├── LeaderboardViewModel.swift
│   ├── ProfileViewModel.swift
│   ├── SocialViewModel.swift      # Follow/feed logic
│   ├── StudyFeedViewModel.swift   # Discover feed (planned)
│   ├── ClassViewModel.swift       # (planned)
│   └── DormViewModel.swift        # (planned)
├── Services/
│   ├── AuthService.swift          # Firebase Auth wrapper
│   ├── FirebaseService.swift      # Firestore + Storage (singleton)
│   ├── CameraService.swift        # AVFoundation for verification
│   └── ScreenTimeService.swift    # Family Controls API (optional)
└── Utilities/
    ├── Constants.swift            # Firebase collections, UI sizing, AppColors
    └── Extensions.swift           # String, Date helpers, View modifiers
```

## Data Models

### Current Firestore Schema
```
users/{userId}
├── displayName, email, photoURL
├── major, year
├── totalFocusedSeconds
├── studyTools: [String]           # General Study Stack
├── tips: String
├── spotifyPlaylistURL
├── points: Int                    # Status tier points
├── selectedTitle: String?         # Custom title if unlocked
├── selectedFrame: String?         # Frame cosmetic ID
├── unlockedCosmetics: [String]    # IDs of unlocked items
├── createdAt, updatedAt

users/{userId}/sessions/{sessionId}
├── startTime, endTime, durationSeconds
├── verified, completedAt

users/{userId}/following/{targetUserId}
users/{userId}/followers/{followerId}
```

### Planned Schema Additions

```
users/{userId}
├── dorm: String                   # "Zahm Hall", "Welsh Family", etc.
├── generalStudyStack: [String]    # Renamed from studyTools

users/{userId}/classes/{classId}
├── courseCode: "ACCT 20100"
├── courseName: "Intro to Accounting"
├── professor: "Smith"
├── semester: "Fall 2025"
├── grade: "A"                     # null if unverified
├── verified: Bool
├── verifiedAt: Timestamp
├── studyStack: [String]           # Class-specific tools/resources
├── tips: String                   # Class-specific advice
├── createdAt: Timestamp

dorms/{dormId}
├── name: "Zahm Hall"
├── totalFocusedSeconds: Int       # Aggregated from members
├── memberCount: Int
├── weeklySeconds: Int             # Reset weekly for competitions

posts/{postId}                     # Discover feed posts
├── authorId: String
├── postType: "study_stack" | "tips"
├── studyTools: [String]?          # For stack posts
├── tips: String?                  # For tips posts
├── classId: String?               # If class-specific
├── courseCode, courseName, professor, grade, gradeVerified
├── authorDisplayName, authorPhotoURL, authorPoints  # Denormalized
├── upvotes, downvotes, score: Int
├── hotScore: Double               # Ranking algorithm result
├── createdAt, updatedAt
├── isEdited: Bool
├── previousPostId: String?        # Link to original if re-shared

votes/{voteId}                     # Vote tracking
├── userId, postId: String
├── voteType: -1 | 0 | 1           # down | none | up
├── createdAt, updatedAt

users/{userId}/favorites/{favoriteId}  # Bookmarked posts
├── postId: String
├── createdAt: Timestamp
```

### Grade Verification Flow
1. User adds class to profile (course, professor, semester)
2. User uploads transcript photo/PDF
3. Status: "Pending Review"
4. Admin reviews in dashboard, confirms grade
5. Transcript deleted after verification (privacy)
6. Verified badge appears on class

### Points System (Planned)
| Action | Points |
|--------|--------|
| Complete focus session | +1 per minute |
| Upload a class | +10 |
| Verify grade (A) | +25 |
| Verify grade (B) | +15 |
| Verify grade (C) | +5 |
| Someone views your Study Stack | +2 |
| Someone follows you | +5 |

### Status Tier System

A mature, prestigious progression system (Reddit/Discord/Stack Overflow style, NOT gamified).

#### Tier Thresholds & Colors
| Tier | Points | Hex Color | Title |
|------|--------|-----------|-------|
| Bronze | 0 - 999 | #8B7355 | Novice |
| Silver | 1,000 - 4,999 | #9CA3AF | Apprentice |
| Gold | 5,000 - 14,999 | #C7A32E (ND gold) | Scholar |
| Platinum | 15,000 - 39,999 | #A3B8CC | Elite |
| Diamond | 40,000 - 99,999 | #60A5FA | Master |
| Obsidian | 100,000+ | #1F2937 + gold accent | Legend |

#### Visual Prestige Elements

**1. Profile Ring/Frame** (`TierRingView.swift`)
- Subtle gradient ring around avatar (not thick cartoon borders)
- Higher tiers get subtle glow/shimmer
- Ring styles per tier:
  - Bronze: Thin muted border
  - Silver: Subtle metallic gradient
  - Gold: ND gold with soft inner glow
  - Platinum: Cool silver-blue gradient
  - Diamond: Crystalline blue with subtle refraction
  - Obsidian: Dark with gold trim accent

**2. Title/Flair**
- Displayed under username: "◆ Platinum Scholar"
- Uses tier accent color
- User can toggle visibility

**3. Profile Card Evolution**
- Background gets subtle treatment at higher tiers
- Not full redesign - refined accents only
- Higher tiers may have subtle pattern overlay

**4. Cosmetic Unlocks by Tier**
| Tier | Unlocks |
|------|---------|
| Silver | Custom profile banner colors |
| Gold | Animated avatar ring (subtle pulse) |
| Platinum | Profile card gradient backgrounds |
| Diamond | Custom title text, exclusive frames |
| Obsidian | All cosmetics + "Founding Member" badges |

#### Design Principles
1. **Earned, not bought** - Status from studying, not purchases
2. **Subtle progression** - Refined visual changes, not flashy
3. **Optional display** - Users can show/hide tier elements
4. **Consistent palette** - Tier colors complement dark mode + ND gold
5. **No distractions** - Prestige is for profiles, not during focus sessions

## Development Roadmap

| Phase | Features | Status |
|-------|----------|--------|
| **0b. Status Tiers** | Points awarding, remaining integrations | **In Progress** |
| **0c. Discover Feed** | Reddit-like feed with upvotes, favorites, sharing | **Next** |
| **1. Foundation** | Dorm field on profile, dorm leaderboard | Planned |
| **2. Classes** | Add classes to profile, basic Study Stack per class | Planned |
| **3. Verification** | Transcript upload, admin review dashboard | Planned |
| **4. Discovery** | Search/filter by class, professor, grade | Planned |
| **5. Monetization** | Premium tier, ads on free tier | Planned |

### Phase 0b: Status Tiers - Remaining Tasks

| Task | Status |
|------|--------|
| OtherUserProfileView integration | Pending |
| LeaderboardView tier badges | Pending |
| FeedView tier badges | Pending |
| Points awarding logic (FocusViewModel) | Pending |
| Firestore migration for points field | Pending |

### Phase 0c: Discover Feed

Reddit-like activity feed where users share Study Stacks and Tips with upvote/downvote system.

#### Core Features
- **Share Posts**: Explicitly share stacks or tips to feed (separate posts)
- **Voting**: Upvote/downvote affects feed ranking via hotScore
- **Tier Boost**: Higher status users' content ranks higher
- **Filtering**: Friends vs Everyone toggle
- **Favorites**: Bookmark posts for easy reference
- **Pro Filters**: Filter by class, grade (future premium feature)

#### Ranking Algorithm
```
hotScore = (voteScore × tierMultiplier × timeDecay) + verificationBonus

Tier Multipliers: Bronze=1.0, Silver=1.05, Gold=1.1, Platinum=1.2, Diamond=1.35, Obsidian=1.5
Time Decay: Linear over 24 hours
Verification Bonus: A=0.3, B=0.15, C=0.05
```

## Key Patterns

### Firebase Service (Singleton)
```swift
FirebaseService.shared.db           // Firestore
FirebaseService.shared.storage      // Storage
FirebaseService.shared.auth         // Auth
```

### ViewModels
- Use `@MainActor` for main thread safety
- Inherit from `ObservableObject` with `@Published` properties
- Use async/await for Firebase operations
- Combine for reactive bindings

### Theming (Dark Mode)

The app uses a dark mode theme with Notre Dame gold/green accents.

#### Dark Mode Backgrounds
| Name | Hex | Usage |
|------|-----|-------|
| `background` | `#0D0D0D` | Main app background |
| `backgroundSecondary` | `#1A1A1A` | Grouped backgrounds |
| `surface` | `#242424` | Cards, elevated surfaces |
| `surfaceElevated` | `#2E2E2E` | Modals, sheets |
| `border` | `#3A3A3A` | Borders, dividers |
| `borderSubtle` | `#2A2A2A` | Subtle separators |

#### Notre Dame Accent Colors
| Name | Hex | Usage |
|------|-----|-------|
| `gold` | `#C7A32E` | Primary accent (ND gold) |
| `goldLight` | `#D4B84A` | Highlights |
| `goldMuted` | `#8B7220` | Disabled states |
| `green` | `#00843D` | Official ND green |
| `greenLight` | `#00A34B` | Green highlights |
| `greenMuted` | `#005C2A` | Subtle green accents |

#### Text Colors
| Name | Value | Usage |
|------|-------|-------|
| `textPrimary` | `#FFFFFF` | Main text |
| `textSecondary` | `#FFFFFF` @ 70% | Secondary labels |
| `textTertiary` | `#FFFFFF` @ 50% | Captions |

#### Glow Effects
| Element | Color | Radius | Opacity |
|---------|-------|--------|---------|
| Primary buttons | Gold | 8 | 0.3 |
| Focus timer ring (active) | Gold | 12 | 0.4 |
| Top leaderboard badges | Gold | 6 | 0.25 |
| Cards (subtle) | Green | 4 | 0.1 |

#### View Modifiers (Extensions.swift)
- `cardStyle()` - Dark surface with subtle green glow
- `primaryButtonStyle()` - Gold background, dark text, gold glow
- `secondaryButtonStyle()` - Surface background, gold border
- `goldGlow(radius:opacity:)` - Gold shadow effect
- `greenGlow(radius:opacity:)` - Green shadow effect

#### Clover Accents (CloverView.swift)
Shamrock (☘ U+2618) used as subtle Notre Dame Easter eggs:
- Login screen: Small gold clover below title
- Empty states: Medium muted green clover
- Session complete: Animated celebration clover
- Obsidian tier: Gold clover accent

#### Fonts
- `AppFonts.timer()` - 72pt monospaced for countdown

## Core Features (Current)

### Focus Sessions
- Minimum duration: 60 seconds
- Camera verification during session
- Sessions stored in user subcollection
- `totalFocusedSeconds` aggregated on user document

### Leaderboard
- Real-time listener on `totalFocusedSeconds`
- Friends leaderboard filters by following list
- Time filters: weekly, monthly, all-time
- Dorm leaderboard (planned)

### Social
- Follow/unfollow with batch writes (both sides)
- Activity feed shows completed sessions from followed users
- User search by displayName prefix

## Firebase Security

Users can only write to their own documents. All reads require authentication. Transcripts stored in private bucket, deleted after verification.

## Development Notes

- GoogleService-Info.plist required (not in repo)
- Family Controls capability optional (requires Apple Developer Program)
- Profile photos stored at `profile_photos/{userId}.jpg`
- Transcripts stored at `transcripts/{userId}/{timestamp}.pdf` (temporary)

## Notre Dame Dorms Reference

Men's: Carroll, Dillon, Duncan, Fisher, Keenan, Keough, Knott, Morrissey, O'Neill, Siegfried, Sorin, St. Edward's, Stanford, Coyle

Women's: Badin, Breen-Phillips, Cavanaugh, Farley, Howard, Lewis, Lyons, McGlinn, Pasquerilla East, Pasquerilla West, Ryan, Walsh, Welsh Family
