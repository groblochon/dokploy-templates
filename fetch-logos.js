#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const https = require('https');

// Get local blueprints
const localBlueprints = fs.readdirSync('blueprints')
  .filter(item => fs.statSync(path.join('blueprints', item)).isDirectory());

// Get official blueprints from GitHub API
async function getOfficialBlueprints() {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        'User-Agent': 'dokploy-templates-script'
      }
    };
    const req = https.get('https://api.github.com/repos/Dokploy/templates/contents/blueprints?ref=canary', options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.message && json.message.includes('rate limit')) {
            console.log('GitHub API rate limited. Using cached data from curl...');
            // Fallback to the data we got earlier with curl
            const fs = require('fs');
            if (fs.existsSync('/tmp/official_blueprints.txt')) {
              const blueprintNames = fs.readFileSync('/tmp/official_blueprints.txt', 'utf8')
                .trim().split('\n').filter(Boolean);
              resolve(blueprintNames);
            } else {
              reject(new Error('No cached data available'));
            }
          } else {
            const blueprintNames = json
              .filter(item => item.type === 'dir')
              .map(item => item.name);
            resolve(blueprintNames);
          }
        } catch (e) {
          console.log('API response:', data.substring(0, 200));
          reject(e);
        }
      });
    });
    req.on('error', reject);
  });
}

// Get logo files for a specific blueprint
async function getLogoFiles(blueprintName) {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        'User-Agent': 'dokploy-templates-script'
      }
    };
    const req = https.get(`https://api.github.com/repos/Dokploy/templates/contents/blueprints/${blueprintName}?ref=canary`, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.message && (json.message.includes('rate limit') || json.message.includes('Not Found'))) {
            resolve([]); // Rate limited or blueprint not found, skip this blueprint
          } else {
            const logoFiles = json
              .filter(item => item.type === 'file' && /\.(svg|png|jpg|jpeg|gif|ico)$/i.test(item.name))
              .map(item => item.name);
            resolve(logoFiles);
          }
        } catch (e) {
          resolve([]); // Blueprint might not exist or have access issues
        }
      });
    });
    req.on('error', () => resolve([]));
  });
}

// Download a file
function downloadFile(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    https.get(url, (response) => {
      response.pipe(file);
      file.on('finish', () => {
        file.close(resolve);
      });
    }).on('error', reject);
  });
}

// Main execution
async function main() {
  console.log('Getting official blueprints...');
  const officialBlueprints = await getOfficialBlueprints();
  console.log(`Found ${officialBlueprints.length} official blueprints`);

  // Find common blueprint names
  const commonBlueprints = localBlueprints.filter(bp => 
    officialBlueprints.includes(bp.toLowerCase())
  );
  
  console.log(`Found ${commonBlueprints.length} matching blueprints`);
  
  let downloadedCount = 0;
  let updatedMetaCount = 0;

  for (const blueprint of commonBlueprints) {
    console.log(`\nProcessing blueprint: ${blueprint}`);
    
    // Get logo files from official repo
    const logoFiles = await getLogoFiles(blueprint.toLowerCase());
    
    if (logoFiles.length === 0) {
      console.log(`  No logo files found for ${blueprint}`);
      continue;
    }

    // Choose best logo (prefer svg over png, prefer exact name match)
    let bestLogo = logoFiles[0];
    const exactMatch = logoFiles.find(file => file.toLowerCase().startsWith(blueprint.toLowerCase()));
    if (exactMatch) {
      bestLogo = exactMatch;
    } else {
      const svgLogo = logoFiles.find(file => file.toLowerCase().endsWith('.svg'));
      if (svgLogo) bestLogo = svgLogo;
    }

    console.log(`  Best logo: ${bestLogo}`);

    // Download the logo
    const logoUrl = `https://raw.githubusercontent.com/Dokploy/templates/canary/blueprints/${blueprint.toLowerCase()}/${bestLogo}`;
    const destPath = path.join('blueprints', blueprint, bestLogo);
    
    try {
      await downloadFile(logoUrl, destPath);
      console.log(`  ✓ Downloaded ${bestLogo}`);
      downloadedCount++;
    } catch (e) {
      console.log(`  ✗ Failed to download ${bestLogo}: ${e.message}`);
      continue;
    }

    // Update meta.json
    const metaPath = path.join('blueprints', blueprint, 'meta.json');
    if (fs.existsSync(metaPath)) {
      try {
        const meta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
        meta.logo = bestLogo;
        fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2) + '\n');
        console.log(`  ✓ Updated meta.json logo field`);
        updatedMetaCount++;
      } catch (e) {
        console.log(`  ✗ Failed to update meta.json: ${e.message}`);
      }
    }
  }

  console.log(`\nSummary:`);
  console.log(`- Downloaded ${downloadedCount} logos`);
  console.log(`- Updated ${updatedMetaCount} meta.json files`);
}

main().catch(console.error);