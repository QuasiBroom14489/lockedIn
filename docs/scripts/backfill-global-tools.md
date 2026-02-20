# Backfill Runbook: Global Tools Library (`tools`)

## Goal
Seed and normalize the shared `tools` catalog from:
1. Existing curated tool list in app (`ProfileViewModel.commonStudyTools`)
2. Historical post data (`studyPosts.stackItems[].toolName` and legacy `studyPosts.tools[]`)

## Preconditions
1. Firestore rules deployed with `tools/{toolId}` support.
2. Admin/service account access to read `studyPosts` and write `tools`.
3. Backup/export available for rollback.

## Normalization Rules
1. Trim whitespace.
2. Uppercase.
3. Replace non-alphanumeric separators with `_`.
4. Collapse duplicate `_`.
5. Remove leading/trailing `_`.

Examples:
- `Google Docs` -> `GOOGLE_DOCS`
- `google-docs` -> `GOOGLE_DOCS`
- `  anki  ` -> `ANKI`

## Recommended Script Logic
For each candidate tool string:
1. Build `toolId` via normalization.
2. Skip empty tool names.
3. If `tools/{toolId}` exists:
- merge aliases (normalized alias keys)
- increment `usageCount`
- set `updatedAt`
4. Else create:
- `id = toolId`
- `displayName = original cleaned name`
- `aliases = [normalized keys]`
- `category = null` (optional later)
- `createdByUserId = "migration"`
- `usageCount = 1`
- timestamps

## Verification Checklist
1. `tools` collection populated with expected canonical IDs.
2. Known duplicates merged:
- `Google Docs`, `google docs`, `google-docs` -> one doc
3. `usageCount` is >0 for popular tools.
4. Composer tool suggestions load from `tools`.
5. Onboarding tool search returns seeded tools.

## Rollback
1. Restore from Firestore export for `tools` collection, or
2. Delete `tools/*` docs created during migration window and rerun script after rule/logic fix.
