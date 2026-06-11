#!/usr/bin/env node
/**
 * opencode-kit CLI — version and help
 * Usage: npx opencode-kit --version
 *        npx opencode-kit --help
 */
import { fileURLToPath } from 'url';
import path from 'path';
import fs from 'fs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const pkgPath = path.resolve(__dirname, '../package.json');
const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));

const args = process.argv.slice(2);

if (args.includes('--version') || args.includes('-v')) {
  console.log(pkg.version);
  process.exit(0);
}

if (args.includes('--help') || args.includes('-h') || args.length === 0) {
  console.log(`
opencode-kit v${pkg.version}

Usage:
  npx opencode-kit [command]

Commands:
  init [--force]    Scaffold orchestration framework into project
  update [--dry-run] Pull latest templates from GitHub
  --version, -v     Print version
  --help, -h        Print this help

Plugin mode:
  Add "opencode-kit" to opencode.json plugin array (FIRST position).
  Skills are auto-registered. Contract auto-initialized on first run.

Config resolution:
  1. .opencode/            (project override)
  2. ~/.config/opencode-kit/ (global defaults)
  3. plugin templates/      (shipped defaults)

Docs: ${pkg.homepage}
`);
  process.exit(0);
}
