/**
 * Seed Script: Catalog Courses for Gateway Students
 *
 * Seeds pre-defined course catalog for Holy Cross and Notre Dame courses.
 * These courses appear in the CatalogClassPickerView for easy browsing.
 *
 * Usage:
 *   node seed-catalog-courses.js              # Dry run (default)
 *   node seed-catalog-courses.js --execute    # Actually write to Firestore
 *
 * Prerequisites:
 *   - Place your Firebase service account key at: scripts/serviceAccountKey.json
 *   - Download from: Firebase Console > Project Settings > Service Accounts > Generate New Private Key
 */

import { initializeApp, cert } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Gateway courses from Holy Cross and Notre Dame
const GATEWAY_COURSES = [
  // Holy Cross Courses
  { courseCode: "MATH 141", displayName: "Elements of Calculus", school: "Holy Cross", credits: 4, instructors: ["Laura LeGare", "Dennis James Vandenberg"] },
  { courseCode: "MATH 151", displayName: "Calculus I for Science", school: "Holy Cross", credits: 4, instructors: ["Laura LeGare"] },
  { courseCode: "MATH 118", displayName: "Finite Mathematics", school: "Holy Cross", credits: 4, instructors: ["Stephen Takach"] },
  { courseCode: "PHYS 151", displayName: "Physics for Science", school: "Holy Cross", credits: 4, instructors: ["John William Biddle"] },
  { courseCode: "PHYS 151 L", displayName: "Physics for Science Lab", school: "Holy Cross", credits: 0, instructors: ["John William Biddle"] },
  { courseCode: "PHYS 152", displayName: "Physics II for Science", school: "Holy Cross", credits: 4, instructors: ["John William Biddle"] },
  { courseCode: "PHYS 152 L", displayName: "Physics II for Science Lab", school: "Holy Cross", credits: 0, instructors: ["John William Biddle"] },
  { courseCode: "MATH 142", displayName: "Elements of Calculus II", school: "Holy Cross", credits: 4, instructors: ["Laura LeGare"] },
  { courseCode: "ECON 201", displayName: "Principles of Microeconomics", school: "Holy Cross", credits: 3, instructors: ["George E Mokrzan", "Edwige Tia"] },
  { courseCode: "ECON 202", displayName: "Principles of Macroeconomics", school: "Holy Cross", credits: 3, instructors: ["Edwige Tia", "George E Mokrzan"] },
  { courseCode: "PHIL 201", displayName: "Introduction to Philosophy", school: "Holy Cross", credits: 3, instructors: ["Angela M Schwenkler", "David Wayne Lutz", "David Schenk"] },
  { courseCode: "ENGL 101", displayName: "Writing and Rhetoric", school: "Holy Cross", credits: 3, instructors: ["Christopher Robert John Scheirer", "Laura Jean Jackson", "Heather Ghormley", "Justin G Watson", "Emily Mahan", "Anthony Monta"] },
  { courseCode: "THEO 140", displayName: "Creation, Covenant and Christ", school: "Holy Cross", credits: 3, instructors: ["Louis Theodore Albarran", "Brian K Carpenter", "Robert Edward McFadden"] },
  { courseCode: "BIOL 121", displayName: "Biological Sciences", school: "Holy Cross", credits: 3, instructors: ["Katherine L Barrett", "Elaine Mokrzan"] },
  { courseCode: "BIOL 125", displayName: "Human Biology", school: "Holy Cross", credits: 3, instructors: ["Elaine Mokrzan", "Lawrence Unfried"] },
  { courseCode: "BIOL 130", displayName: "Human Ecology", school: "Holy Cross", credits: 3, instructors: ["Katherine L Barrett"] },
  { courseCode: "BIOL 151", displayName: "Principles of Biology", school: "Holy Cross", credits: 3, instructors: ["Aris T. Alexandrou"] },
  { courseCode: "BIOL 151 L", displayName: "Principles of Biology Lab", school: "Holy Cross", credits: 1, instructors: ["Aris T. Alexandrou"] },
  { courseCode: "BIOL 152", displayName: "Principles of Biology II", school: "Holy Cross", credits: 3, instructors: ["Katherine L Barrett", "Aris T. Alexandrou"] },
  { courseCode: "BIOL 152 L", displayName: "Principles of Biology II Lab", school: "Holy Cross", credits: 1, instructors: ["Katherine L Barrett", "Aris T. Alexandrou"] },
];

/**
 * Normalize course code to canonical ID (e.g., "MATH 141" -> "MATH141")
 */
function normalizeCourseCode(code) {
  if (!code || typeof code !== 'string') return null;
  return code
    .trim()
    .toUpperCase()
    .replace(/\s+/g, '');
}

/**
 * Extract department prefix from course code (e.g., "MATH141" -> "MATH")
 */
function extractDepartment(normalizedCode) {
  if (!normalizedCode) return null;
  const match = normalizedCode.match(/^([A-Z]+)/);
  return match ? match[1] : null;
}

async function seedCatalogCourses({ dryRun = true }) {
  console.log(`=== Seed Catalog Courses ===`);
  console.log(`Mode: ${dryRun ? 'DRY RUN' : 'EXECUTE'}\n`);

  // Initialize Firebase Admin
  let db;
  if (!dryRun) {
    const serviceAccountPath = join(__dirname, 'serviceAccountKey.json');
    try {
      const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8'));
      initializeApp({
        credential: cert(serviceAccount)
      });
      db = getFirestore();
      console.log('Firebase Admin initialized.\n');
    } catch (err) {
      console.error(`Failed to load service account key from ${serviceAccountPath}`);
      console.error('Download it from: Firebase Console > Project Settings > Service Accounts > Generate New Private Key');
      console.error(`Error: ${err.message}`);
      process.exit(1);
    }
  }

  console.log(`Processing ${GATEWAY_COURSES.length} catalog courses...\n`);

  let created = 0;
  let updated = 0;
  let skipped = 0;

  for (const course of GATEWAY_COURSES) {
    const courseId = normalizeCourseCode(course.courseCode);
    if (!courseId) {
      console.log(`  SKIP: Invalid course code "${course.courseCode}"`);
      skipped++;
      continue;
    }

    const department = extractDepartment(courseId);
    const instructors = course.instructors || [];

    if (dryRun) {
      // Dry run - just show what would happen
      const instructorInfo = instructors.length > 0 ? `, ${instructors.length} instructor(s)` : '';
      console.log(`  WOULD CREATE/UPDATE ${courseId}: "${course.displayName}" (${course.school}, ${course.credits} cr${instructorInfo})`);
      created++;
      continue;
    }

    // Check if course already exists
    const docRef = db.collection('classes').doc(courseId);
    const existingDoc = await docRef.get();

    if (existingDoc.exists) {
      const existingData = existingDoc.data();

      // Merge instructors
      const existingInstructors = existingData.instructorNames || [];
      const mergedInstructors = [...new Set([...existingInstructors, ...instructors])];

      const update = {
        isCatalogCourse: true,
        school: course.school,
        department: department,
        credits: course.credits,
        displayName: existingData.displayName || course.displayName,
        instructorNames: mergedInstructors,
        instructorName: mergedInstructors[0] || existingData.instructorName || null,
        updatedAt: new Date()
      };

      console.log(`  UPDATE ${courseId}: Setting as ${course.school} catalog course${mergedInstructors.length > 0 ? ` (${mergedInstructors.length} instructors)` : ''}`);

      await docRef.update(update);
      updated++;
    } else {
      // Create new catalog course
      const newDoc = {
        id: courseId,
        courseCode: courseId,
        displayName: course.displayName,
        instructorName: instructors[0] || null,
        recentTerms: [],
        instructorNames: instructors,
        aliases: [],
        createdByUserId: 'catalog_seed',
        memberCount: 0,
        isCatalogCourse: true,
        school: course.school,
        department: department,
        credits: course.credits,
        createdAt: new Date(),
        updatedAt: new Date()
      };

      const instructorInfo = instructors.length > 0 ? `, ${instructors.length} instructor(s)` : '';
      console.log(`  CREATE ${courseId}: "${course.displayName}" (${course.school}, ${course.credits} cr${instructorInfo})`);

      await docRef.set(newDoc);
      created++;
    }
  }

  console.log(`\n=== Summary ===`);
  console.log(`  Created: ${created}`);
  console.log(`  Updated: ${updated}`);
  console.log(`  Skipped: ${skipped}`);
  console.log(`  Mode: ${dryRun ? 'DRY RUN (no changes made)' : 'EXECUTED'}`);

  if (dryRun) {
    console.log(`\nTo execute, first:`);
    console.log(`  1. Download service account key from Firebase Console`);
    console.log(`  2. Save it as: scripts/serviceAccountKey.json`);
    console.log(`  3. Run: node seed-catalog-courses.js --execute`);
  }
}

const args = process.argv.slice(2);
const dryRun = !args.includes('--execute');

seedCatalogCourses({ dryRun })
  .then(() => {
    console.log('\nDone.');
    process.exit(0);
  })
  .catch((err) => {
    console.error('Error:', err);
    process.exit(1);
  });
