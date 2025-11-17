#!/usr/bin/env node
/**
 * Universal installation script for nuxt-dx-tools-lsp
 * Detects and works with npm, pnpm, yarn, and bun
 */

const { execSync } = require('child_process');
const { existsSync } = require('fs');
const { join } = require('path');

// Detect which package manager is being used
function detectPackageManager() {
  // Check for lockfiles
  if (existsSync('pnpm-lock.yaml')) return 'pnpm';
  if (existsSync('yarn.lock')) return 'yarn';
  if (existsSync('bun.lockb')) return 'bun';
  if (existsSync('package-lock.json')) return 'npm';

  // Check which package manager is available
  const managers = ['pnpm', 'yarn', 'bun', 'npm'];
  for (const manager of managers) {
    try {
      execSync(`${manager} --version`, { stdio: 'ignore' });
      console.log(`📦 Detected package manager: ${manager}`);
      return manager;
    } catch {
      // Manager not available, try next
    }
  }

  // Fallback to npm (should always be available)
  return 'npm';
}

// Build the TypeScript code
function build() {
  const packageManager = detectPackageManager();

  console.log('🔨 Building TypeScript LSP server...');

  try {
    // Use the detected package manager to run the build script
    const buildCmd = packageManager === 'npm'
      ? 'npm run build'
      : `${packageManager} build`;

    execSync(buildCmd, { stdio: 'inherit', cwd: __dirname });

    console.log('✅ Build complete!');

    // Make server executable
    const serverPath = join(__dirname, 'dist', 'server.js');
    if (existsSync(serverPath)) {
      try {
        execSync(`chmod +x "${serverPath}"`, { stdio: 'ignore' });
        console.log('✅ Server executable permission set');
      } catch (err) {
        // chmod might fail on Windows, that's okay
        console.log('⚠️  Could not set executable permission (may not be needed on Windows)');
      }
    }
  } catch (error) {
    console.error('❌ Build failed:', error.message);
    process.exit(1);
  }
}

// Run installation
function install() {
  console.log('🚀 Installing nuxt-dx-tools-lsp...\n');
  build();
  console.log('\n✨ Installation complete!\n');
  console.log('You can now use: nuxt-dx-tools-lsp --stdio');
}

// Run if executed directly
if (require.main === module) {
  install();
}

module.exports = { detectPackageManager, build, install };
