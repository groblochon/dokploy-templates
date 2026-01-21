#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

// Get local blueprints that don't have meta.json
const localBlueprints = fs.readdirSync('blueprints')
  .filter(item => fs.statSync(path.join('blueprints', item)).isDirectory())
  .filter(blueprint => !fs.existsSync(path.join('blueprints', blueprint, 'meta.json')));

console.log(`Found ${localBlueprints.length} blueprints without meta.json:`, localBlueprints);

// Simple meta.json creation for common cases
function createBasicMeta(blueprintName) {
  const name = blueprintName
    .split('-')
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(' ');
  
  // Check if we have a logo file
  const blueprintPath = path.join('blueprints', blueprintName);
  const files = fs.readdirSync(blueprintPath);
  const logoFile = files.find(file => /\.(svg|png|jpg|jpeg|gif|ico)$/i.test(file)) || `${blueprintName}.png`;
  
  return {
    id: blueprintName,
    name: name,
    version: "latest",
    description: `${name} application deployment template`,
    logo: logoFile,
    links: {
      github: `https://github.com/${blueprintName}/${blueprintName}`
    },
    tags: [blueprintName]
  };
}

// Get our current main meta.json
const mainMetaPath = 'meta.json';
const mainMeta = JSON.parse(fs.readFileSync(mainMetaPath, 'utf8'));

let createdCount = 0;

for (const blueprint of localBlueprints) {
  console.log(`\nCreating meta.json for: ${blueprint}`);
  
  const meta = createBasicMeta(blueprint);
  const metaPath = path.join('blueprints', blueprint, 'meta.json');
  
  // Check if this blueprint exists in official meta.json
  const officialEntry = mainMeta.find(item => item.id === blueprint);
  if (officialEntry) {
    console.log(`  ✓ Using official entry from main meta.json`);
    fs.writeFileSync(metaPath, JSON.stringify(officialEntry, null, 2) + '\n');
  } else {
    console.log(`  ✓ Creating basic meta.json`);
    fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2) + '\n');
    
    // Add to main meta.json if not already there
    if (!mainMeta.find(item => item.id === blueprint)) {
      mainMeta.push(meta);
      console.log(`  ✓ Added to main meta.json`);
    }
  }
  
  createdCount++;
}

// Sort and save main meta.json
mainMeta.sort((a, b) => a.id.localeCompare(b.id));
fs.writeFileSync(mainMetaPath, JSON.stringify(mainMeta, null, 2) + '\n');

console.log(`\nSummary:`);
console.log(`- Created ${createdCount} meta.json files`);
console.log(`- Total entries in main meta.json: ${mainMeta.length}`);