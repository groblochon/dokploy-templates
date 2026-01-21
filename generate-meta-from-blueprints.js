#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

/**
 * Script pour générer le meta.json principal à partir des blueprints
 * Lit chaque dossier blueprint, extrait les métadonnées et génère le fichier meta.json
 */

const BLUEPRINTS_DIR = path.join(__dirname, 'blueprints');
const OUTPUT_FILE = path.join(__dirname, 'meta.json');

function extractVersionFromDockerCompose(blueprintPath) {
  try {
    const dockerComposePath = path.join(blueprintPath, 'docker-compose.yml');
    if (!fs.existsSync(dockerComposePath)) {
      return 'latest';
    }
    
    const content = fs.readFileSync(dockerComposePath, 'utf8');
    const imageMatch = content.match(/image:\s*([^\s:]+):([^\s\n]+)/);
    return imageMatch ? imageMatch[2] : 'latest';
  } catch (error) {
    console.warn(`Warning: Could not extract version from ${blueprintPath}:`, error.message);
    return 'latest';
  }
}

function getLogoFiles(blueprintPath) {
  try {
    const files = fs.readdirSync(blueprintPath);
    const logoExtensions = ['.svg', '.png', '.jpg', '.jpeg', '.webp'];
    const logoFiles = files.filter(file => 
      logoExtensions.some(ext => file.toLowerCase().endsWith(ext))
    );
    
    // Priorité: SVG > PNG > JPG > JPEG > WEBP
    const prioritizedFiles = logoFiles.sort((a, b) => {
      const getPriority = (filename) => {
        const ext = path.extname(filename).toLowerCase();
        switch (ext) {
          case '.svg': return 1;
          case '.png': return 2;
          case '.jpg': return 3;
          case '.jpeg': return 4;
          case '.webp': return 5;
          default: return 6;
        }
      };
      return getPriority(a) - getPriority(b);
    });
    
    return prioritizedFiles[0] || null;
  } catch (error) {
    return null;
  }
}

function generateBlueprintMeta(blueprintDir) {
  const blueprintPath = path.join(BLUEPRINTS_DIR, blueprintDir);
  const metaPath = path.join(blueprintPath, 'meta.json');
  
  // Si meta.json existe, l'utiliser
  if (fs.existsSync(metaPath)) {
    try {
      const metaContent = fs.readFileSync(metaPath, 'utf8');
      const meta = JSON.parse(metaContent);
      
      // Validation basique
      if (!meta.id || !meta.name || !meta.description || !meta.links || !meta.links.github) {
        console.warn(`Warning: Invalid meta.json in ${blueprintDir}, skipping`);
        return null;
      }
      
      // S'assurer que l'id correspond au nom du dossier
      meta.id = blueprintDir;
      
      // Extraire la version depuis docker-compose.yml si non présente ou si "latest"
      if (!meta.version || meta.version === 'latest') {
        meta.version = extractVersionFromDockerCompose(blueprintPath);
      }
      
      // Ajouter le logo si manquant
      if (!meta.logo) {
        const logoFile = getLogoFiles(blueprintPath);
        meta.logo = logoFile || 'logo.png';
      }
      
      // S'assurer que tags est un tableau
      if (!Array.isArray(meta.tags)) {
        meta.tags = [];
      }
      
      return meta;
    } catch (error) {
      console.warn(`Warning: Error parsing meta.json in ${blueprintDir}:`, error.message);
      return null;
    }
  }
  
  // Générer depuis docker-compose.yml et template.toml si pas de meta.json
  const dockerComposePath = path.join(blueprintPath, 'docker-compose.yml');
  const templatePath = path.join(blueprintPath, 'template.toml');
  
  if (!fs.existsSync(dockerComposePath)) {
    console.warn(`Warning: No docker-compose.yml found in ${blueprintDir}, skipping`);
    return null;
  }
  
  try {
    const dockerCompose = fs.readFileSync(dockerComposePath, 'utf8');
    const version = extractVersionFromDockerCompose(blueprintPath);
    const logoFile = getLogoFiles(blueprintPath);
    
    // Extraire le nom du service principal depuis docker-compose
    const serviceMatch = dockerCompose.match(/services:\s*\n\s*(\w+):/);
    const serviceName = serviceMatch ? serviceMatch[1] : blueprintDir;
    
    // Générer des métadonnées basiques
    const meta = {
      id: blueprintDir,
      name: serviceName.charAt(0).toUpperCase() + serviceName.slice(1).replace(/[-_]/g, ' '),
      version: version,
      description: `${serviceName} application template`,
      logo: logoFile || 'logo.png',
      links: {
        github: `https://github.com/${serviceName}/${serviceName}`
      },
      tags: []
    };
    
    return meta;
  } catch (error) {
    console.warn(`Warning: Error generating meta for ${blueprintDir}:`, error.message);
    return null;
  }
}

function main() {
  console.log('🔍 Scan des blueprints...');
  
  if (!fs.existsSync(BLUEPRINTS_DIR)) {
    console.error(`❌ Erreur: Le dossier ${BLUEPRINTS_DIR} n'existe pas`);
    process.exit(1);
  }
  
  const blueprintDirs = fs.readdirSync(BLUEPRINTS_DIR)
    .filter(item => {
      const itemPath = path.join(BLUEPRINTS_DIR, item);
      return fs.statSync(itemPath).isDirectory() && 
             fs.existsSync(path.join(itemPath, 'docker-compose.yml'));
    })
    .sort();
  
  console.log(`📦 ${blueprintDirs.length} blueprints trouvés`);
  
  const metas = [];
  let processed = 0;
  let skipped = 0;
  
  for (const blueprintDir of blueprintDirs) {
    const meta = generateBlueprintMeta(blueprintDir);
    if (meta) {
      metas.push(meta);
      processed++;
      console.log(`✅ ${blueprintDir} -> ${meta.name} v${meta.version}`);
    } else {
      skipped++;
      console.log(`⚠️  ${blueprintDir} -> ignoré`);
    }
  }
  
  // Trier par nom
  metas.sort((a, b) => a.name.localeCompare(b.name));
  
  // Écrire le fichier meta.json
  const output = JSON.stringify(metas, null, 2);
  fs.writeFileSync(OUTPUT_FILE, output);
  
  console.log(`\n📄 Généré ${OUTPUT_FILE} avec ${metas.length} entrées`);
  console.log(`📊 Statistiques: ${processed} traités, ${skipped} ignorés`);
  
  // Lancer le script de déduplication et tri existant
  try {
    console.log('\n🔄 Lancement du script de traitement existant...');
    execSync('node dedupe-and-sort-meta.js', { stdio: 'inherit' });
  } catch (error) {
    console.warn('\n⚠️  Le script de traitement a échoué, mais le fichier a été généré');
  }
  
  console.log('\n🎉 Terminé!');
}

if (require.main === module) {
  main();
}

module.exports = { generateBlueprintMeta, extractVersionFromDockerCompose, getLogoFiles };