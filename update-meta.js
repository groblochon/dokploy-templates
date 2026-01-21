#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const https = require('https');

// Download official meta.json
async function getOfficialMeta() {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        'User-Agent': 'dokploy-templates-script'
      }
    };
    const req = https.get('https://raw.githubusercontent.com/Dokploy/templates/canary/meta.json', options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const meta = JSON.parse(data);
          resolve(meta);
        } catch (e) {
          reject(e);
        }
      });
    });
    req.on('error', reject);
  });
}

// Get local blueprints
const localBlueprints = fs.readdirSync('blueprints')
  .filter(item => fs.statSync(path.join('blueprints', item)).isDirectory());

// Check if meta.json has all required fields
function validateMeta(meta) {
  const required = ['id', 'name', 'version', 'description', 'links', 'logo', 'tags'];
  const missing = required.filter(field => !meta[field]);
  
  if (missing.length > 0) {
    return { valid: false, missing };
  }
  
  if (!meta.links.github) {
    return { valid: false, missing: ['links.github'] };
  }
  
  if (!Array.isArray(meta.tags)) {
    return { valid: false, missing: ['tags (must be array)'] };
  }
  
  return { valid: true };
}

// Main execution
async function main() {
  console.log('Fetching official meta.json...');
  const officialMeta = await getOfficialMeta();
  console.log(`Found ${officialMeta.length} entries in official meta.json`);

  let updatedCount = 0;
  let addedCount = 0;
  let validatedCount = 0;

  // Get our current meta.json
  const ourMetaPath = 'meta.json';
  const ourMeta = JSON.parse(fs.readFileSync(ourMetaPath, 'utf8'));

  for (const blueprint of localBlueprints) {
    console.log(`\nProcessing blueprint: ${blueprint}`);
    
    const blueprintPath = path.join('blueprints', blueprint);
    const metaPath = path.join(blueprintPath, 'meta.json');
    
    // Check if we have a local meta.json
    let localMeta = null;
    if (fs.existsSync(metaPath)) {
      try {
        localMeta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
      } catch (e) {
        console.log(`  ✗ Invalid meta.json in ${blueprint}`);
        continue;
      }
    }

    // Find official entry
    const officialEntry = officialMeta.find(item => item.id === blueprint);
    
    if (officialEntry) {
      console.log(`  ✓ Found official entry`);
      
      // Update local meta.json with official data
      const updatedMeta = { ...officialEntry };
      
      // Keep any local customizations that don't conflict with required fields
      if (localMeta) {
        // Preserve custom fields that aren't in official entry
        Object.keys(localMeta).forEach(key => {
          if (!officialEntry.hasOwnProperty(key) && key !== 'id') {
            updatedMeta[key] = localMeta[key];
          }
        });
      }
      
      // Validate the meta
      const validation = validateMeta(updatedMeta);
      if (!validation.valid) {
        console.log(`  ✗ Missing required fields: ${validation.missing.join(', ')}`);
        
        // Try to fix common issues
        if (!updatedMeta.links) updatedMeta.links = {};
        if (!updatedMeta.links.github && localMeta && localMeta.links && localMeta.links.github) {
          updatedMeta.links.github = localMeta.links.github;
        }
        if (!Array.isArray(updatedMeta.tags)) {
          updatedMeta.tags = [];
        }
      } else {
        console.log(`  ✓ Meta.json is valid`);
        validatedCount++;
      }
      
      // Write the updated meta.json
      fs.writeFileSync(metaPath, JSON.stringify(updatedMeta, null, 2) + '\n');
      
      // Update or add to our main meta.json
      const existingIndex = ourMeta.findIndex(item => item.id === blueprint);
      if (existingIndex >= 0) {
        ourMeta[existingIndex] = updatedMeta;
        updatedCount++;
        console.log(`  ✓ Updated entry in main meta.json`);
      } else {
        ourMeta.push(updatedMeta);
        addedCount++;
        console.log(`  ✓ Added new entry to main meta.json`);
      }
      
    } else if (localMeta) {
      console.log(`  ⚠ No official entry found, keeping local meta.json`);
      
      // Validate existing meta
      const validation = validateMeta(localMeta);
      if (!validation.valid) {
        console.log(`  ✗ Missing required fields: ${validation.missing.join(', ')}`);
      } else {
        console.log(`  ✓ Local meta.json is valid`);
        validatedCount++;
      }
      
      // Ensure it's in our main meta.json
      const existingIndex = ourMeta.findIndex(item => item.id === blueprint);
      if (existingIndex < 0) {
        ourMeta.push(localMeta);
        addedCount++;
        console.log(`  ✓ Added local entry to main meta.json`);
      }
    } else {
      console.log(`  ⚠ No meta.json found for ${blueprint}`);
    }
  }

  // Sort and write our main meta.json
  ourMeta.sort((a, b) => a.id.localeCompare(b.id));
  fs.writeFileSync(ourMetaPath, JSON.stringify(ourMeta, null, 2) + '\n');

  console.log(`\nSummary:`);
  console.log(`- Updated ${updatedCount} existing entries`);
  console.log(`- Added ${addedCount} new entries`);
  console.log(`- Validated ${validatedCount} meta.json files`);
  console.log(`- Total entries in main meta.json: ${ourMeta.length}`);
}

main().catch(console.error);