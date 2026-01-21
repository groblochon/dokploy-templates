#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const https = require('https');

// Get official blueprints from GitHub API
async function getLogoFiles(blueprintName) {
  return new Promise((resolve, reject) => {
    const options = {
      headers: {
        'User-Agent': 'dokploy-templates-script'
      }
    };
    const req = https.get(`https://api.github.com/repos/Dokploy/templates/contents/blueprints/${blueprintName.toLowerCase()}?ref=canary`, options, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          if (json.message && (json.message.includes('rate limit') || json.message.includes('Not Found'))) {
            resolve([]); // Rate limited or blueprint not found
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

// Get blueprint directories that have missing logos
const blueprintDirs = fs.readdirSync('blueprints')
  .filter(item => fs.statSync(path.join('blueprints', item)).isDirectory());

async function main() {
  console.log('Fixing missing logos...');
  
  let fixedCount = 0;
  let downloadedCount = 0;
  
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
      const actualFiles = fs.readdirSync(path.join('blueprints', blueprint));
      const actualLogos = actualFiles.filter(file => /\.(svg|png|jpg|jpeg|gif|ico)$/i.test(file));
      
      if (actualLogos.length > 0) {
        // Use existing logo file
        const newLogo = actualLogos[0]; // Use first found
        meta.logo = newLogo;
        fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2) + '\n');
        console.log(`  ✓ Updated to use existing logo: ${newLogo}`);
        fixedCount++;
        continue;
      }
      
      // Try to download from official repo
      console.log(`  Trying to download from official repo...`);
      const officialLogos = await getLogoFiles(blueprint);
      
      if (officialLogos.length > 0) {
        // Choose best logo (prefer exact match, then svg)
        let bestLogo = officialLogos.find(file => file.toLowerCase().includes(blueprint.toLowerCase())) || 
                       officialLogos.find(file => file.toLowerCase().endsWith('.svg')) ||
                       officialLogos[0];
        
        const logoUrl = `https://raw.githubusercontent.com/Dokploy/templates/canary/blueprints/${blueprint.toLowerCase()}/${bestLogo}`;
        const destPath = path.join('blueprints', blueprint, bestLogo);
        
        try {
          await downloadFile(logoUrl, destPath);
          console.log(`  ✓ Downloaded ${bestLogo}`);
          downloadedCount++;
          
          // Update meta.json
          meta.logo = bestLogo;
          fs.writeFileSync(metaPath, JSON.stringify(meta, null, 2) + '\n');
          console.log(`  ✓ Updated meta.json logo field`);
          fixedCount++;
        } catch (e) {
          console.log(`  ✗ Failed to download: ${e.message}`);
        }
      } else {
        console.log(`  ✗ No logos found in official repo`);
      }
      
    } catch (e) {
      console.log(`  ✗ Error processing ${blueprint}: ${e.message}`);
    }
  }
  
  console.log(`\nSummary:`);
  console.log(`- Fixed ${fixedCount} meta.json entries`);
  console.log(`- Downloaded ${downloadedCount} new logos`);
}

main().catch(console.error);