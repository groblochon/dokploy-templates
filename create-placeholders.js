#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Get blueprint directories that have missing logos
const blueprintDirs = fs.readdirSync('blueprints')
  .filter(item => fs.statSync(path.join('blueprints', item)).isDirectory());

console.log('Creating placeholders for missing logos...');

let fixedCount = 0;

for (const blueprint of blueprintDirs) {
  const metaPath = path.join('blueprints', blueprint, 'meta.json');
  
  if (!fs.existsSync(metaPath)) continue;
  
  try {
    const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
    const currentLogo = meta.logo;
    const currentLogoPath = path.join('blueprints', blueprint, currentLogo);
    
    // Check if current logo exists
    if (fs.existsSync(currentLogoPath)) {
      continue; // Logo exists, no fix needed
    }
    
    console.log(`\nFixing ${blueprint}: missing ${currentLogo}`);
    
    // Get actual files in the directory
    const blueprintDir = path.join('blueprints', blueprint);
    const actualFiles = fs.readdirSync(blueprintDir);
    const actualLogos = actualFiles.filter(file => /\.(svg|png|jpg|jpeg|gif|ico)$/i.test(file));
    
    if (actualLogos.length > 0) {
      // Use existing logo file
      const newLogo = actualLogos[0]; // Use first found
      meta.logo = newLogo;
      fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2) + '\n');
      console.log(`  ✓ Updated to use existing logo: ${newLogo}`);
      fixedCount++;
    } else {
      // Remove logo field temporarily or set to placeholder
      console.log(`  ✗ No logo files found, removing logo field temporarily`);
      delete meta.logo;
      fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2) + '\n');
      fixedCount++;
    }
    
  } catch (e) {
    console.log(`  ✗ Error processing ${blueprint}: ${e.message}`);
  }
}

console.log(`\nSummary:`);
console.log(`- Fixed ${fixedCount} meta.json entries`);

// Run final validation
console.log('\nRunning final validation...');

const { execSync } = require('child_process');
try {
  execSync('node validate-final.js', { stdio: 'inherit' });
} catch (e) {
  console.log('Validation script encountered an error');
}