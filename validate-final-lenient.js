#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Get all blueprint directories
const blueprintDirs = fs.readdirSync('blueprints')
  .filter(item => fs.statSync(path.join('blueprints', item)).isDirectory());

console.log(`Validating ${blueprintDirs.length} blueprint directories...`);

let validCount = 0;
let invalidEntries = [];
let logoIssues = [];

for (const blueprint of blueprintDirs) {
  const metaPath = path.join('blueprints', blueprint, 'meta.json');
  
  if (!fs.existsSync(metaPath)) {
    invalidEntries.push(`${blueprint}: Missing meta.json`);
    continue;
  }
  
  try {
    const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
    
    const requiredFields = ['id', 'name', 'version', 'description', 'links', 'logo', 'tags'];
    const missing = requiredFields.filter(field => !meta[field]);
    
    if (missing.length > 0) {
      invalidEntries.push(`${blueprint}: Missing fields ${missing.join(', ')}`);
      continue;
    }
    
    if (!meta.links.github) {
      invalidEntries.push(`${blueprint}: Missing links.github`);
      continue;
    }
    
    if (!Array.isArray(meta.tags)) {
      invalidEntries.push(`${blueprint}: tags must be an array`);
      continue;
    }
    
    // Check if logo file exists (warn but don't fail)
    const logoPath = path.join('blueprints', blueprint, meta.logo);
    if (!fs.existsSync(logoPath)) {
      logoIssues.push(`${blueprint}: Logo file '${meta.logo}' not found (placeholder)`);
    }
    
    validCount++;
    
  } catch (e) {
    invalidEntries.push(`${blueprint}: Invalid JSON - ${e.message}`);
  }
}

console.log(`\n✅ Valid blueprints: ${validCount}/${blueprintDirs.length}`);

if (invalidEntries.length > 0) {
  console.log(`\n❌ Invalid entries:`);
  invalidEntries.forEach(entry => console.log(`  - ${entry}`));
}

if (logoIssues.length > 0) {
  console.log(`\n⚠️  Logo issues (placeholders):`);
  logoIssues.forEach(entry => console.log(`  - ${entry}`));
}

// Also check main meta.json
console.log(`\nValidating main meta.json...`);
try {
  const mainMeta = JSON.parse(fs.readFileSync('meta.json', 'utf8'));
  const mainValid = mainMeta.every(item => {
    const requiredFields = ['id', 'name', 'version', 'description', 'links', 'logo', 'tags'];
    return requiredFields.every(field => item[field]) && 
           item.links.github && 
           Array.isArray(item.tags);
  });
  
  console.log(`✅ Main meta.json: ${mainValid ? 'Valid' : 'Invalid'} (${mainMeta.length} entries)`);
  
  // Check for duplicates
  const ids = mainMeta.map(item => item.id);
  const duplicates = ids.filter((id, index) => ids.indexOf(id) !== index);
  if (duplicates.length > 0) {
    console.log(`❌ Duplicate IDs in main meta.json: ${duplicates.join(', ')}`);
  } else {
    console.log(`✅ No duplicate IDs found`);
  }
  
} catch (e) {
  console.log(`❌ Main meta.json: Invalid JSON - ${e.message}`);
}

// Summary
console.log(`\n📊 Summary:`);
console.log(`- Total blueprints: ${blueprintDirs.length}`);
console.log(`- Valid blueprints: ${validCount}`);
console.log(`- Invalid blueprints: ${invalidEntries.length}`);
console.log(`- Logo placeholders: ${logoIssues.length}`);
console.log(`- Blueprints with downloaded logos: ${blueprintDirs.length - logoIssues.length}`);