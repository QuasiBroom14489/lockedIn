# lockedIn Implementation Plan

**Last Updated:** February 19, 2026
**Owner:** Founder + Engineering
**Status Key:** `Pending` | `In Progress` | `Done`

---

## Current State
Stabilization pass is active. Core product features are built; this plan tracks bug fixes, cleanup, and verification needed for reliable behavior.

### Active Stabilization Sprint (Bugs + Cleanup)
- [x] Step 1: Voting reliability + diagnostics
- [x] Step 2: Leaderboard auto-fallback to All Time
- [x] Step 3: Feed timestamp compatibility + backfill
- [x] Step 4: Archive completed tasks into `docs/implemented.md`
- [x] Step 5: Remove dead legacy context safely

| Bug | Owner | Status | Next Action |
|---|---|---|---|
| Upvote/downvote fails | Eng | In Progress | Deploy Firestore rules to active Firebase project and run vote transition smoke tests |
| Leaderboard empty | Eng | In Progress | Validate weekly/friends empty states auto-fallback to All Time on real data |
| Feed newest-only | Eng | In Progress | Run timestamp backfill and confirm fallback path no longer needed for most docs |

---

## Open Bugs

### 1) Voting reliability
**Status:** `In Progress`

Completed in code:
- `FirebaseService.setVote` now verifies `studyPosts/{postId}` exists before counter writes.
- Added `FirebaseError.postNotFound`.
- Vote/favorite failures now surface actionable errors in feed UI with operation + postId + reason.
- Soft diagnostics added for per-post interaction-state lookup failures.

Remaining:
- Firestore rules deploy to active project.
- Manual transition tests:
  - none -> upvote -> none
  - none -> downvote -> none
  - upvote -> downvote
  - downvote -> upvote
  - vote on deleted post -> explicit error

### 2) Leaderboard empty behavior
**Status:** `In Progress`

Completed in code:
- Added auto-fallback to all-time global when selected filter returns empty.
- Added fallback state in VM (`didAutoFallbackToAllTime`, `fallbackMessage`).
- Added UI banner: `No data for current filter yet. Showing All Time.`

Remaining:
- Validate weekly/friends empty datasets on staging/prod accounts.

### 3) Feed newest-only behavior
**Status:** `In Progress`

Completed in code:
- Added compatibility path in `getStudyPosts(limit:)`:
  - primary ordered query by `createdAt`
  - fallback to unordered bounded fetch + in-memory deterministic sort when needed
- Added lightweight diagnostics logs for primary count, fallback path, and missing timestamps.
- Added runbook: `docs/scripts/backfill-study-post-timestamps.md`

Remaining:
- Execute one-time backfill and verify legacy docs now include timestamps.

---

## In Progress Tasks
- Deploy Firestore rules (`firestore.rules`) to active Firebase project.
- Execute timestamp backfill runbook for `studyPosts`.
- Run stabilization smoke tests on device/emulator.

---

## Next Queue
- Add admin-only in-app maintenance action for timestamp backfill status reporting.
- Add structured telemetry counters for vote/favorite failures by error type.
- Add lightweight UI test cases for leaderboard fallback banner visibility.

---

## Blockers
- None in code.
- Operational dependency: Firebase rules deployment and production data backfill are required to fully close bug statuses.

---

## Verification Checklist
- [ ] Voting transitions persist and counters stay accurate across all 5 scenarios.
- [ ] Voting on deleted post returns explicit `Post not found` error.
- [ ] Weekly empty leaderboard auto-falls back with banner.
- [ ] Friends empty leaderboard auto-falls back with banner.
- [ ] All-time non-empty leaderboard shows no fallback banner.
- [ ] Feed displays mixed legacy/new posts (with and without historical timestamps).
- [ ] Fallback path does not introduce duplicates.
- [ ] Post ordering is deterministic after backfill.
- [ ] `IMPLEMENT.md` remains active-only.
- [x] Historical completed work moved to `docs/implemented.md`.

---

Historical completed work moved to `docs/implemented.md`.
