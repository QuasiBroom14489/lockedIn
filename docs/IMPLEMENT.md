#### New Models
      370 -| Model | Purpose |
      371 -|-------|---------|
      372 -| `StudyPost.swift` | Feed post (stack or tips) with author info, votes, ho
          -tScore |
      373 -| `Vote.swift` | User vote on a post (upvote/downvote/none) |
      374 -| `Favorite.swift` | User's saved/bookmarked posts |
      375 -
      376 -#### New Views
      377 -| View | Purpose |
      378 -|------|---------|
      379 -| `StudyFeedView.swift` | Main feed (replaces FeedView) |
      380 -| `StudyPostRow.swift` | Post card with votes, content, user info |
      381 -| `FavoritesView.swift` | Saved posts list |
      382 -| `SharePostSheet.swift` | Form to share stack/tips to feed |
      383 -
      384 -#### New ViewModel
      385 -| ViewModel | Purpose |
      386 -|-----------|---------|
      387 -| `StudyFeedViewModel.swift` | Feed state, voting, favorites, pagination |
      388 -
      389 -#### Implementation Tasks
      390 -
      391 -| Task | Status |
      392 -|------|--------|
      393 -| StudyPost.swift model | Pending |
      394 -| Vote.swift model | Pending |
      395 -| Favorite.swift model | Pending |
      396 -| Constants.swift - add collection names | Pending |
      397 -| Extensions.swift - array chunking helper | Pending |
      398 -| FirebaseService.swift - post CRUD methods | Pending |
      399 -| FirebaseService.swift - voting methods | Pending |
      400 -| FirebaseService.swift - favorites methods | Pending |
      401 -| StudyFeedViewModel.swift | Pending |
      402 -| StudyPostRow.swift component | Pending |
      403 -| StudyFeedView.swift (main feed) | Pending |
      404 -| FavoritesView.swift | Pending |
      405 -| SharePostSheet.swift | Pending |
      406 -| ContentView.swift - replace Activity tab | Pending |
      407 -| ProfileView.swift - add share buttons | Pending |
      408 -
      345 
      258  | Diamond | Custom title text, exclusive frames |
      259  | Obsidian | All cosmetics + "Founding Member" badges |
      260
      261 -#### Implementation Files
      262 -
      263 -**Models:**
      264 -- `StatusTier.swift` - Enum with thresholds, colors, titles, unlocks ✓
      265 -- `CosmeticUnlock` - Enum for unlockable cosmetics ✓
      266 -- `PointsAction` - Reference enum for points system ✓
      267 -
      268 -**Views:**
      269 -- `TierRingView.swift` - Avatar ring component with tier-based styling ✓
      270 -- `TierAvatarView` - Avatar wrapped with tier ring ✓
      271 -- `TierProgressCard.swift` - Points display with progress to next tier ✓
      272 -- `TierProgressCompact` - Single-line compact progress ✓
      273 -- `TierBadgeView.swift` - Small inline tier indicator (4 styles) ✓
      274 -- `TierTitleView` - Inline "◆ Gold Scholar" text ✓
      275 -- `TierLabelView` - Icon + title + points for lists ✓
      276 -
      277 -**Integration Points:**
      278 -- `ProfileHeaderView` - TierAvatarView around avatar, TierTitleView under n
          -ame ✓
      279 -- `ProfileView` - TierProgressCard added to profile ✓
      280 -- `User.swift` - Added `points`, computed `tier`, `selectedTitle`, `selecte
          -dFrame`, `unlockedCosmetics` ✓
      281 -- `OtherUserProfileView` - Integrate tier components (pending)
      282 -- `LeaderboardView` - Add tier badges to rows (pending)
      283 -- `FeedView` - Add tier badges to activity items (pending)
      284 -



