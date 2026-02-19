# Backfill Runbook: `studyPosts` Missing Timestamps

## Goal
Normalize legacy `studyPosts` documents so feed ordering is reliable.

## Backfill Rules
For each `studyPosts/{postId}`:
1. If `createdAt` is missing, set `createdAt = updatedAt` when present.
2. If both are missing, set `createdAt = server timestamp now`.
3. Ensure `updatedAt` exists (set to same value as `createdAt` when missing).

## Safety
- Run in a maintenance/admin context only.
- Run once in production.
- Keep a dry-run mode first to log candidate documents.

## Example (Firebase Admin SDK, Node.js)
```js
import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore, FieldValue, Timestamp } from 'firebase-admin/firestore';

initializeApp({ credential: applicationDefault() });
const db = getFirestore();

async function backfillStudyPostTimestamps({ dryRun = true, batchSize = 400 } = {}) {
  const snapshot = await db.collection('studyPosts').get();
  let scanned = 0;
  let changed = 0;
  let batch = db.batch();
  let ops = 0;

  for (const doc of snapshot.docs) {
    scanned += 1;
    const data = doc.data() || {};
    const hasCreatedAt = !!data.createdAt;
    const hasUpdatedAt = !!data.updatedAt;

    if (hasCreatedAt && hasUpdatedAt) continue;

    const update = {};
    const fallbackCreatedAt = data.updatedAt || FieldValue.serverTimestamp();

    if (!hasCreatedAt) update.createdAt = fallbackCreatedAt;
    if (!hasUpdatedAt) update.updatedAt = hasCreatedAt ? data.createdAt : fallbackCreatedAt;

    changed += 1;

    if (!dryRun) {
      batch.update(doc.ref, update);
      ops += 1;
      if (ops >= batchSize) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
  }

  if (!dryRun && ops > 0) {
    await batch.commit();
  }

  console.log({ scanned, changed, dryRun });
}

await backfillStudyPostTimestamps({ dryRun: true });
// Then run with dryRun: false after verifying logs.
```

## Verification Checklist
1. Query `studyPosts` where `createdAt == null` should return `0` docs.
2. Feed should show more than the most recently posted document.
3. Feed ordering should be deterministic by recency.
