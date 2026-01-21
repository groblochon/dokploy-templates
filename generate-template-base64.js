#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

/**
 * Script pour générer la base64 d'un template Dokploy
 * Compresse le dossier en ZIP puis l'encode en base64
 */

function zipFolder(sourceDir, outputPath) {
  const archiver = require('archiver');
  const output = fs.createWriteStream(outputPath);
  const archive = archiver('zip', { zlib: { level: 9 } });

  return new Promise((resolve, reject) => {
    output.on('close', () => {
      console.log(`📦 ZIP créé: ${outputPath} (${archive.pointer()} bytes)`);
      resolve();
    });

    archive.on('error', (err) => {
      reject(err);
    });

    archive.pipe(output);
    archive.directory(sourceDir, false);
    archive.finalize();
  });
}

function fileToBase64(filePath) {
  const file = fs.readFileSync(filePath);
  return file.toString('base64');
}

async function main() {
  const tempZipPath = path.join(__dirname, 'dokploy-template.zip');
  const outputPath = path.join(__dirname, 'template-base64.txt');
  
  try {
    console.log('🔧 Création du template Dokploy...');
    
    // Créer le ZIP du dossier courant (exclure certains fichiers/dossiers)
    const { execSync } = require('child_process');
    
    // Créer un .dockerignore temporaire
    const dockerignore = `
node_modules
.git
.gitignore
*.md
.DS_Store
template-base64.txt
dokploy-template.zip
.github
`.trim();
    
    fs.writeFileSync('.dockerignore-temp', dockerignore);
    
    try {
      execSync(`zip -r ${tempZipPath} . -x "*.git*" "node_modules/*" "*.md" ".DS_Store" "template-base64.txt" "dokploy-template.zip" ".github/*"`, { stdio: 'inherit' });
    } catch (error) {
      // Fallback si zip n'est pas disponible
      console.log('⚠️  zip non disponible, utilisation de Node.js...');
      await zipFolder('.', tempZipPath);
    }
    
    // Nettoyer le .dockerignore temporaire
    if (fs.existsSync('.dockerignore-temp')) {
      fs.unlinkSync('.dockerignore-temp');
    }
    
    console.log('🔄 Encodage en base64...');
    const base64 = fileToBase64(tempZipPath);
    
    fs.writeFileSync(outputPath, base64);
    
    console.log(`✅ Base64 généré: ${outputPath}`);
    console.log(`📊 Taille: ${base64.length} caractères`);
    console.log('\n📋 Pour importer dans Dokploy:');
    console.log('1. Copiez le contenu du fichier template-base64.txt');
    console.log('2. Dans Dokploy, allez sur Templates');
    console.log('3. Cliquez sur "Importer" et collez la base64');
    
    // Nettoyer le fichier ZIP temporaire
    fs.unlinkSync(tempZipPath);
    console.log('🧹 Fichier temporaire nettoyé');
    
  } catch (error) {
    console.error('❌ Erreur:', error.message);
    process.exit(1);
  }
}

// Vérifier si les dépendances sont disponibles
try {
  require('archiver');
} catch (error) {
  console.log('📦 Installation des dépendances...');
  const { execSync } = require('child_process');
  execSync('npm install archiver', { stdio: 'inherit' });
}

if (require.main === module) {
  main();
}

module.exports = { fileToBase64, zipFolder };