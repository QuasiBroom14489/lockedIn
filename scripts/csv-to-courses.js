/**
 * CSV to Courses Converter
 *
 * Reads course-catalog-template.csv and outputs JavaScript array for seed-catalog-courses.js
 *
 * Usage:
 *   node csv-to-courses.js
 *   node csv-to-courses.js path/to/your-file.csv
 */

import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

function parseCSV(content) {
  const lines = content.split('\n').map(line => line.trim()).filter(line => line.length > 0);
  if (lines.length < 2) {
    console.error('CSV must have a header row and at least one data row');
    return [];
  }

  // Parse header
  const headers = parseCSVLine(lines[0]);

  // Parse data rows
  const courses = [];
  for (let i = 1; i < lines.length; i++) {
    const values = parseCSVLine(lines[i]);
    const row = {};
    headers.forEach((header, index) => {
      row[header.trim()] = values[index]?.trim() || '';
    });

    // Skip empty rows
    if (!row['Course Code']) continue;

    // Collect instructors (handles any number of Instructor columns)
    const instructors = [];
    for (let j = 1; j <= 20; j++) {
      const instructor = row[`Instructor ${j}`];
      if (instructor) {
        instructors.push(instructor);
      }
    }

    courses.push({
      courseCode: row['Course Code'],
      displayName: row['Course Name'],
      school: row['School'] || 'Holy Cross',
      credits: parseInt(row['Credits']) || 3,
      instructors: instructors
    });
  }

  return courses;
}

function parseCSVLine(line) {
  const values = [];
  let current = '';
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];

    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      values.push(current);
      current = '';
    } else {
      current += char;
    }
  }
  values.push(current);

  return values;
}

function formatAsJavaScript(courses) {
  let output = 'const GATEWAY_COURSES = [\n';

  // Group by school
  const holyCrossCourses = courses.filter(c => c.school === 'Holy Cross');
  const notreDameCourses = courses.filter(c => c.school === 'Notre Dame');

  if (holyCrossCourses.length > 0) {
    output += '  // Holy Cross Courses\n';
    for (const course of holyCrossCourses) {
      output += formatCourse(course);
    }
    output += '\n';
  }

  if (notreDameCourses.length > 0) {
    output += '  // Notre Dame Courses\n';
    for (const course of notreDameCourses) {
      output += formatCourse(course);
    }
  }

  output += '];\n';
  return output;
}

function formatCourse(course) {
  const instructorsStr = course.instructors.length > 0
    ? `[${course.instructors.map(i => `"${i}"`).join(', ')}]`
    : '[]';

  return `  { courseCode: "${course.courseCode}", displayName: "${course.displayName}", school: "${course.school}", credits: ${course.credits}, instructors: ${instructorsStr} },\n`;
}

// Main
const csvPath = process.argv[2] || join(__dirname, 'course-catalog-template.csv');

try {
  const content = readFileSync(csvPath, 'utf8');
  const courses = parseCSV(content);

  if (courses.length === 0) {
    console.log('No courses found in CSV');
    process.exit(1);
  }

  console.log(`// Parsed ${courses.length} courses from ${csvPath}\n`);
  console.log(formatAsJavaScript(courses));
  console.log(`\n// Copy the above array into seed-catalog-courses.js`);
} catch (err) {
  console.error('Error reading CSV:', err.message);
  process.exit(1);
}
