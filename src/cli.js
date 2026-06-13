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
  preflight              Run pre-flight gate checks
  score                  Run scoring pipeline
  contract-lint          Validate contract structure
  checkpoint             Checkpoint management (save/list/validate/fix)
  diff                   Show contract changes since last checkpoint
  audit                  Query audit trail
  verify                 Verify project setup
  adoption-check         Check project adoption status
  contract-lock          Check/manage contract lock
  adr <title>            Create Architecture Decision Record

Slash commands (in opencode TUI):
  /opencode-kit:doctor          Health checks
  /opencode-kit:status          Project status
  /opencode-kit:preflight       Pre-flight gate
  /opencode-kit:score           Scoring pipeline
  /opencode-kit:contract-lint   Contract validation
  /opencode-kit:checkpoint      List checkpoints
  /opencode-kit:audit           Audit trail
  /opencode-kit:verify          Setup verification
  /opencode-kit:lock            Contract lock status

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
  analytics: '.opencode/src/analytics.sh',
  preflight: '.opencode/src/preflight.sh',
  score: '.opencode/src/scoring-pipeline.sh',
  'contract-lint': '.opencode/src/contract-lint.sh',
  checkpoint: '.opencode/src/checkpoint.sh',
  diff: '.opencode/src/diff.sh',
  audit: '.opencode/src/audit-trail.sh',
  verify: '.opencode/src/verify.sh',
  'adoption-check': '.opencode/src/adoption-check.sh',
  'contract-lock': '.opencode/src/contract-lock.sh',
};

const command = args[0];

if (commands[command]) {
  const projectRoot = findProjectRoot(process.cwd());

  if (!projectRoot) {
    console.error('Not in an opencode-kit project');
    process.exit(1);
  }

  const scriptPath = path.resolve(projectRoot, commands[command]);
  const result = spawnSync('bash', [scriptPath], { stdio: 'inherit', cwd: projectRoot });
  process.exit(result.status);
}

if (command === 'init') {
  const scriptPath = path.resolve(__dirname, 'init.sh');
  const result = spawnSync('bash', [scriptPath], { stdio: 'inherit', cwd: process.cwd() });
  process.exit(result.status);
}

if (command === 'update') {
  const scriptPath = path.resolve(__dirname, 'update.sh');
  const result = spawnSync('bash', [scriptPath], { stdio: 'inherit', cwd: process.cwd() });
  process.exit(result.status);
}

if (command === 'adr') {
  const title = args.slice(1).join(' ');
  if (!title) {
    console.error('Usage: npx opencode-kit adr <title>');
    process.exit(1);
  }
  const projectRoot = findProjectRoot(process.cwd());
  if (!projectRoot) {
    console.error('Not in an opencode-kit project');
    process.exit(1);
  }
  const scriptPath = path.resolve(projectRoot, '.opencode/src/adr.sh');
  const result = spawnSync('bash', [scriptPath, title], { stdio: 'inherit', cwd: projectRoot });
  process.exit(result.status);
}
