/**
 * Backfill Script: Global Tools Library (`tools`)
 *
 * Seeds and normalizes the shared `tools` catalog from:
 * 1. Existing curated tool list (ProfileViewModel.commonStudyTools)
 * 2. Historical post data (studyPosts.stackItems[].toolName and legacy studyPosts.tools[])
 *
 * Usage:
 *   node backfill-global-tools.js              # Dry run (default)
 *   node backfill-global-tools.js --execute    # Actually write to Firestore
 *
 * Prerequisites:
 *   - Firebase CLI logged in: firebase login
 */

import { spawn, execSync } from 'child_process';
import { createInterface } from 'readline';

const PROJECT_ID = 'lockedin-733fd';
const FIRESTORE_API = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;

// Curated tools from ProfileViewModel.commonStudyTools
const CURATED_TOOLS = [
  'Notion',
  'Anki',
  'Quizlet',
  'Google Docs',
  'OneNote',
  'Obsidian',
  'GoodNotes',
  'Notability'
];

/**
 * Normalize tool name to canonical ID
 */
function normalizeToolId(name) {
  if (!name || typeof name !== 'string') return null;
  return name
    .trim()
    .toUpperCase()
    .replace(/[^A-Z0-9]+/g, '_')
    .replace(/_+/g, '_')
    .replace(/^_|_$/g, '');
}

function cleanDisplayName(name) {
  if (!name || typeof name !== 'string') return null;
  return name.trim();
}

// Get access token from Firebase CLI configstore
function getAccessToken() {
  try {
    const result = execSync(`node -e "
      const { configstore } = require('firebase-tools/lib/configstore');
      const tokens = configstore.get('tokens');
      if (tokens && tokens.access_token) console.log(tokens.access_token);
    "`, {
      encoding: 'utf8',
      timeout: 10000,
      cwd: process.cwd()
    });
    if (result.trim()) return result.trim();
  } catch (err) {
    console.error('Failed to get access token:', err.message);
  }

  return null;
}

// Firestore REST API helper
async function firestoreRequest(method, path, body = null, accessToken) {
  const url = `${FIRESTORE_API}${path}`;
  const options = {
    method,
    headers: {
      'Authorization': `Bearer ${accessToken}`,
      'Content-Type': 'application/json'
    }
  };
  if (body) {
    options.body = JSON.stringify(body);
  }

  const response = await fetch(url, options);
  if (!response.ok) {
    const text = await response.text();
    throw new Error(`Firestore API error: ${response.status} ${text}`);
  }
  return response.json();
}

// Convert Firestore document to plain object
function docToObject(doc) {
  if (!doc.fields) return {};
  const obj = {};
  for (const [key, value] of Object.entries(doc.fields)) {
    obj[key] = firestoreValueToJS(value);
  }
  return obj;
}

function firestoreValueToJS(value) {
  if (value.stringValue !== undefined) return value.stringValue;
  if (value.integerValue !== undefined) return parseInt(value.integerValue, 10);
  if (value.doubleValue !== undefined) return value.doubleValue;
  if (value.booleanValue !== undefined) return value.booleanValue;
  if (value.nullValue !== undefined) return null;
  if (value.arrayValue) {
    return (value.arrayValue.values || []).map(firestoreValueToJS);
  }
  if (value.mapValue) {
    return docToObject({ fields: value.mapValue.fields });
  }
  if (value.timestampValue) return new Date(value.timestampValue);
  return null;
}

function jsToFirestoreValue(value) {
  if (value === null || value === undefined) return { nullValue: null };
  if (typeof value === 'string') return { stringValue: value };
  if (typeof value === 'number') {
    return Number.isInteger(value) ? { integerValue: String(value) } : { doubleValue: value };
  }
  if (typeof value === 'boolean') return { booleanValue: value };
  if (Array.isArray(value)) {
    return { arrayValue: { values: value.map(jsToFirestoreValue) } };
  }
  if (value instanceof Date) return { timestampValue: value.toISOString() };
  if (typeof value === 'object') {
    const fields = {};
    for (const [k, v] of Object.entries(value)) {
      fields[k] = jsToFirestoreValue(v);
    }
    return { mapValue: { fields } };
  }
  return { nullValue: null };
}

function objectToFirestoreDoc(obj) {
  const fields = {};
  for (const [key, value] of Object.entries(obj)) {
    fields[key] = jsToFirestoreValue(value);
  }
  return { fields };
}

async function backfillGlobalTools({ dryRun = true }) {
  console.log(`=== Backfill Global Tools ===`);
  console.log(`Mode: ${dryRun ? 'DRY RUN' : 'EXECUTE'}\n`);

  // Get access token from Firebase CLI's cached credentials
  console.log('Getting Firebase access token...');
  const accessToken = getAccessToken();

  if (!accessToken) {
    console.error('Failed to get access token. Please run: firebase login');
    process.exit(1);
  }
  console.log('  Got access token.\n');

  const toolsMap = new Map();

  function addTool(rawName, source) {
    const toolId = normalizeToolId(rawName);
    const displayName = cleanDisplayName(rawName);
    if (!toolId || !displayName) return;

    if (toolsMap.has(toolId)) {
      const existing = toolsMap.get(toolId);
      existing.aliases.add(toolId);
      existing.usageCount += 1;
      existing.sources.add(source);
    } else {
      toolsMap.set(toolId, {
        displayName,
        aliases: new Set([toolId]),
        usageCount: 1,
        sources: new Set([source])
      });
    }
  }

  // 1. Add curated tools
  console.log('Processing curated tools...');
  for (const tool of CURATED_TOOLS) {
    addTool(tool, 'curated');
  }
  console.log(`  Added ${CURATED_TOOLS.length} curated tools\n`);

  // 2. Fetch studyPosts via REST API
  console.log('Fetching studyPosts...');
  let postsData;
  try {
    postsData = await firestoreRequest('GET', '/studyPosts', null, accessToken);
  } catch (err) {
    console.error('Failed to fetch studyPosts:', err.message);
    process.exit(1);
  }

  const posts = postsData.documents || [];
  console.log(`  Found ${posts.length} posts\n`);

  let stackItemsCount = 0;
  let legacyToolsCount = 0;

  for (const doc of posts) {
    const data = docToObject(doc);

    if (Array.isArray(data.stackItems)) {
      for (const item of data.stackItems) {
        if (item && item.toolName) {
          addTool(item.toolName, 'stackItems');
          stackItemsCount++;
        }
      }
    }

    if (Array.isArray(data.tools)) {
      for (const tool of data.tools) {
        if (tool && typeof tool === 'string') {
          addTool(tool, 'legacy_tools');
          legacyToolsCount++;
        }
      }
    }
  }

  console.log(`Extracted tools from posts:`);
  console.log(`  stackItems[].toolName: ${stackItemsCount}`);
  console.log(`  legacy tools[]: ${legacyToolsCount}\n`);

  console.log(`Unique tools to process: ${toolsMap.size}\n`);

  let created = 0;
  let updated = 0;

  for (const [toolId, toolData] of toolsMap) {
    // Check if tool exists
    let existingDoc = null;
    try {
      existingDoc = await firestoreRequest('GET', `/tools/${toolId}`, null, accessToken);
    } catch {
      // Document doesn't exist
    }

    if (existingDoc && existingDoc.fields) {
      const existingData = docToObject(existingDoc);
      const existingAliases = new Set(existingData.aliases || []);
      const mergedAliases = [...new Set([...existingAliases, ...toolData.aliases])];

      const update = {
        aliases: mergedAliases,
        usageCount: (existingData.usageCount || 0) + toolData.usageCount,
        updatedAt: new Date()
      };

      console.log(`  UPDATE ${toolId}: +${toolData.usageCount} usage`);

      if (!dryRun) {
        const updateDoc = objectToFirestoreDoc(update);
        await firestoreRequest(
          'PATCH',
          `/tools/${toolId}?updateMask.fieldPaths=aliases&updateMask.fieldPaths=usageCount&updateMask.fieldPaths=updatedAt`,
          updateDoc,
          accessToken
        );
      }
      updated++;
    } else {
      const newDoc = {
        id: toolId,
        displayName: toolData.displayName,
        aliases: Array.from(toolData.aliases),
        category: null,
        createdByUserId: 'migration',
        usageCount: toolData.usageCount,
        createdAt: new Date(),
        updatedAt: new Date()
      };

      console.log(`  CREATE ${toolId}: "${toolData.displayName}" (usage: ${toolData.usageCount})`);

      if (!dryRun) {
        const createDoc = objectToFirestoreDoc(newDoc);
        await firestoreRequest(
          'PATCH',
          `/tools/${toolId}`,
          createDoc,
          accessToken
        );
      }
      created++;
    }
  }

  console.log(`\n=== Summary ===`);
  console.log(`  Created: ${created}`);
  console.log(`  Updated: ${updated}`);
  console.log(`  Mode: ${dryRun ? 'DRY RUN (no changes made)' : 'EXECUTED'}`);

  if (dryRun) {
    console.log(`\nRun with --execute flag to apply changes.`);
  }
}

const args = process.argv.slice(2);
const dryRun = !args.includes('--execute');

backfillGlobalTools({ dryRun })
  .then(() => {
    console.log('\nDone.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
