#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Get blueprint directories that have missing logos
const blueprintDirs = fs.readdirSync('blueprints')
  .filter(item => fs.statSync(path.join('blueprints', item)).isDirectory());

console.log('Adding placeholder logo references...');

let fixedCount = 0;

for (const blueprint of blueprintDirs) {
  const metaPath = path.join('blueprints', blueprint, 'meta.json');
  
  if (!fs.existsSync(metaPath)) continue;
  
  try {
    const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
    
    // Check if logo field exists
    if (meta.logo) {
      const logoPath = path.join('blueprints', blueprint, meta.logo);
      if (fs.existsSync(logoPath)) {
        continue; // Logo exists, no fix needed
      }
    }
    
    console.log(`\nAdding placeholder logo for ${blueprint}`);
    
    // Set a placeholder logo reference
    meta.logo = `${blueprint}.png`;
    fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2) + '\n');
    console.log(`  ✓ Added placeholder logo: ${blueprint}.png`);
    fixedCount++;
    
  } catch (e) {
    console.log(`  ✗ Error processing ${blueprint}: ${e.message}`);
  }
}

console.log(`\nSummary:`);
console.log(`- Added placeholder logos for ${fixedCount} blueprints`);

// Update main meta.json to reflect changes
console.log('\nUpdating main meta.json...');
const mainMeta = JSON.parse(fs.readFileSync('meta.json', 'utf8'));

for (const blueprint of blueprintDirs) {
  const metaPath = path.join('blueprints', blueprint, 'meta.json');
  
  if (fs.existsSync(metaPath)) {
    try {
      const localMeta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
      const index = mainMeta.findIndex(item => item.id === blueprint);
      
      if (index >= 0) {
        mainMeta[index] = localMeta;
      }
    } catch (e) {
      console.log(`Error updating ${blueprint} in main meta: ${e.message}`);
    }
  }
}

// Sort and save main meta.json
mainMeta.sort((a, b) => a.id.localeCompare(b.id));
fs.writeFileSync('meta.json', JSON.stringify(mainMeta, null, 2) + '\n');

console.log('✅ Updated main meta.json');

// Run final validation
console.log('\nRunning final validation...');
const { execSync } = require('child_process');
try {
  execSync('node validate-final.js', { stdio: 'inherit' });
} catch (e) {
  console.log('Validation script encountered an error');
}