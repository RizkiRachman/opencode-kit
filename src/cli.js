#!/usr/bin/env node
/**
 * opencode-kit CLI — version, help, and project commands
 * Usage: npx opencode-kit --version
 *        npx opencode-kit --help
 *        npx opencode-kit doctor
 *        npx opencode-kit status
 *        npx opencode-kit analytics
 */
import { fileURLToPath } from 'url';
import path from 'path';
import fs from 'fs';
import { spawnSync } from 'child_process';

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
  init [--force]         Scaffold orchestration framework into project
  update [--dry-run]     Pull latest templates from GitHub
  doctor                 Run project health checks
  status                 Show project status
  analytics              Show project analytics
  --version, -v          Print version
  --help, -h             Print this help

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

/**
 * Walk up from startDir to find a directory containing .opencode/
 */
function findProjectRoot(startDir) {
  let dir = startDir;
  while (dir !== path.dirname(dir)) {
    if (fs.existsSync(path.join(dir, '.opencode'))) {
      return dir;
    }
    dir = path.dirname(dir);
  }
  return null;
}

const commands = {
  doctor: '.opencode/src/doctor.sh',
  status: '.opencode/src/status.sh',
  analytics: 'src/analytics.sh',
};

const command = args[0];

if (commands[command]) {
  const projectRoot = findProjectRoot(path.resolve(__dirname, '..'));

  if (!projectRoot) {
    console.error('Not in an opencode-kit project');
    process.exit(1);
  }

  const scriptPath = path.resolve(projectRoot, commands[command]);
  const result = spawnSync('bash', [scriptPath], { stdio: 'inherit', cwd: projectRoot });
  process.exit(result.status);
}
