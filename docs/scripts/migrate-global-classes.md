# Global Classes Migration Runbook

## Purpose
Migrate legacy per-user class docs (`users/{userId}/classes/{legacyClassId}`) into:
1. Global catalog docs: `classes/{courseCode}`
2. User membership docs: `users/{userId}/classes/{courseCode}`

## Preconditions
1. Firestore rules for top-level `classes/{classId}` are deployed.
2. App version with global-class support is available.
3. Backup/export is available before migration.

## Data Mapping
1. `classId` target: normalized `courseCode` (uppercase, no spaces).
2. Global class fields:
   - `id`, `courseCode`
   - `displayName`, `instructorName`
   - `createdByUserId` (first writer)
   - `memberCount`, `createdAt`, `updatedAt`
3. Membership fields:
   - `classId`
   - `teacherReview`, `teacherRating`
   - `spotifyLinks`, `helpfulWebsites`
   - `joinedAt`, `updatedAt`

## Procedure
1. Read all users.
2. For each user, read `users/{userId}/classes/*`.
3. For each class doc:
   - Resolve `courseCode` from doc field.
   - Normalize to `normalizedClassId`.
   - Upsert `classes/{normalizedClassId}` if missing.
   - Upsert membership `users/{userId}/classes/{normalizedClassId}`.
   - Increment `memberCount` only when membership is newly created.
4. Optionally write migration marker in legacy doc:
   - `migratedToClassId: normalizedClassId`
   - `migrationVersion: 1`

## Post-Migration Checks
1. Random sample users:
   - Class list still visible.
   - Class detail review/resources preserved.
2. Composer:
   - Suggestions include globally created classes.
3. Dashboard:
   - Shared dashboard counts include posts from multiple users in same class.

## Notes
1. Keep legacy decoding fallback enabled for one release cycle.
2. Do not hard-delete legacy docs until metrics confirm successful reads and writes.
