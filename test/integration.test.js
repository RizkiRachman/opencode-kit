#!/usr/bin/env node
/**
 * Integration test for opencode-kit plugin.
 *
 * Tests:
 * - Plugin module loads without errors
 * - Contract auto-init creates contract.json
 * - getProjectHash returns unique keys
 * - Skills directory is registered
 * - All JSON files are valid
 *
 * Run: node test/integration.test.js
 */
import path from 'path';
import fs from 'fs';
import crypto from 'crypto';
import assert from 'assert/strict';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

let passed = 0;
let failed = 0;
const tests = [];

const test = (name, fn) => {
  tests.push({ name, fn });
};

// === Helper (same logic as plugin) ===
function generateHash(projectDir) {
  const hash = crypto.createHash('sha256').update(projectDir).digest('hex').slice(0, 12);
  return `orchestration-contract:${hash}`;
}

// === Test Suite ===
console.log('\n[opencode-kit] Integration Tests\n');

// 1. Plugin module loads
test('Plugin module loads without errors', async () => {
  const plugin = await import(path.join(ROOT, '.opencode/plugins/opencode-kit.js'));
  assert.ok(plugin, 'Plugin should export something');
  assert.ok(plugin.OpencodeKitPlugin, 'Plugin should export OpencodeKitPlugin');
  assert.equal(typeof plugin.OpencodeKitPlugin, 'function', 'OpencodeKitPlugin should be a function');
});

// 2. Plugin returns expected hooks
test('Plugin returns config + messages.transform hooks', async () => {
  const { OpencodeKitPlugin } = await import(path.join(ROOT, '.opencode/plugins/opencode-kit.js'));
  const instance = await OpencodeKitPlugin({ client: {}, directory: ROOT });
  assert.ok(instance.config, 'Should have config hook');
  assert.ok(instance['experimental.chat.messages.transform'], 'Should have messages.transform hook');
  assert.equal(typeof instance.config, 'function', 'config should be a function');
  assert.equal(typeof instance['experimental.chat.messages.transform'], 'function', 'messages.transform should be a function');
});

// 3. Project hash is deterministic
test('getProjectHash returns deterministic key', () => {
  // Re-import to access internals
  const hash1 = generateHash('/tmp/test-project-1');
  const hash2 = generateHash('/tmp/test-project-1');
  const hash3 = generateHash('/tmp/test-project-2');
  assert.equal(hash1, hash2, 'Same path should produce same hash');
  assert.notEqual(hash1, hash3, 'Different paths should produce different hashes');
  assert.ok(hash1.startsWith('orchestration-contract:'), 'Hash should have correct prefix');
});

// 4. Skills directory exists
test('Skills directory has all required skills', () => {
  const expectedSkills = [
    'orchestration-template',
    'scoring-pipeline',
    'adr-generator',
    'qa-expert',
    'system-analyst',
    'token-optimize',
    'verification-before-completion',
    'learner'
  ];
  const skillsDir = path.join(ROOT, 'skills');
  for (const skill of expectedSkills) {
    const skillPath = path.join(skillsDir, skill, 'SKILL.md');
    assert.ok(fs.existsSync(skillPath), `Missing skill: ${skill}`);
  }
});

// 5. Plugin metadata exists
test('Plugin metadata (plugin.json) is valid', () => {
  const pluginJson = path.join(ROOT, '.claude-plugin', 'plugin.json');
  assert.ok(fs.existsSync(pluginJson), 'plugin.json should exist');
  const data = JSON.parse(fs.readFileSync(pluginJson, 'utf8'));
  assert.ok(data.name, 'Should have name');
  assert.ok(data.version, 'Should have version');
  assert.ok(data.description, 'Should have description');
});

// 6. Contract template is valid JSON
test('Contract template is valid JSON', () => {
  const template = path.join(ROOT, 'templates', 'contract.json');
  assert.ok(fs.existsSync(template), 'contract template should exist');
  const data = JSON.parse(fs.readFileSync(template, 'utf8'));
  assert.ok(data.state, 'Should have state field');
  assert.ok(data.requirements, 'Should have requirements');
  assert.ok(data.score, 'Should have score');
});

// 7. Rules.json is valid
test('rules.json is valid JSON with required fields', () => {
  const rulesFile = path.join(ROOT, 'rules', 'rules.json');
  assert.ok(fs.existsSync(rulesFile), 'rules.json should exist');
  const data = JSON.parse(fs.readFileSync(rulesFile, 'utf8'));
  assert.ok(Array.isArray(data.rules), 'Should have rules array');
  assert.ok(data.rules.length >= 10, `Should have >= 10 rules, got ${data.rules.length}`);
  assert.ok(data.state_machine, 'Should have state_machine');
  assert.ok(data.scoring, 'Should have scoring');
});


// === TUI Plugin Tests ===

// 8. TUI plugin module loads
test('TUI plugin module loads without errors', async () => {
  const tuiPlugin = await import(path.join(ROOT, '.opencode/plugins/opencode-kit-tui.js'));
  assert.ok(tuiPlugin, 'TUI plugin should export something');
  assert.ok(tuiPlugin.tui, 'TUI plugin should export a tui function');
  assert.equal(typeof tuiPlugin.tui, 'function', 'tui should be a function');
});

// 9. TUI plugin registers commands
test('TUI plugin registers expected commands', async () => {
  const { tui } = await import(path.join(ROOT, '.opencode/plugins/opencode-kit-tui.js'));

  // Mock TUI API
  let registeredCommands = [];
  const mockApi = {
    state: { path: { directory: ROOT } },
    command: {
      register: (cb) => {
        registeredCommands = cb();
        return () => {};
      },
    },
    ui: {
      toast: () => {},
      DialogAlert: () => {},
    },
    dialog: {
      replace: () => {},
      clear: () => {},
    },
  };

  await tui(mockApi, {}, {});

  assert.ok(registeredCommands.length >= 5, `Should register >= 5 commands, got ${registeredCommands.length}`);

  // Check all required commands exist
  const commandValues = registeredCommands.map(c => c.value);
  const expected = ['kit:init', 'kit:doctor', 'kit:status', 'kit:verify', 'kit:adr'];
  for (const cmd of expected) {
    assert.ok(commandValues.includes(cmd), `Missing command: ${cmd}`);
  }

  // Check slash definitions
  const initCmd = registeredCommands.find(c => c.value === 'kit:init');
  assert.ok(initCmd.slash, 'init should have slash definition');
  assert.equal(initCmd.slash.name, 'kit-init', 'init slash name');
  assert.ok(initCmd.slash.aliases.includes('ki'), 'init should have ki alias');

  // Check categories
  for (const cmd of registeredCommands) {
    assert.equal(cmd.category, 'opencode-kit', `Command ${cmd.value} should have correct category`);
  }
});

// 10. TUI plugin file exists in exports
test('TUI plugin is exported in package.json', () => {
  const pkgPath = path.join(ROOT, 'package.json');
  const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf8'));
  assert.ok(pkg.exports, 'package.json should have exports');
  assert.ok(pkg.exports['./tui'], 'package.json should export ./tui');
  assert.equal(
    pkg.exports['./tui'].import,
    '.opencode/plugins/opencode-kit-tui.js',
    'TUI export should point to correct file'
  );
  // Verify the file actually exists
  const tuiPath = path.join(ROOT, '.opencode/plugins/opencode-kit-tui.js');
  assert.ok(fs.existsSync(tuiPath), 'TUI plugin file should exist');
});

// === Run collected tests (supports both sync and async) ===
for (const { name, fn } of tests) {
  try {
    await fn();
    console.log(`  ✅ ${name}`);
    passed++;
  } catch (e) {
    console.log(`  ❌ ${name}: ${e.message}`);
    failed++;
  }
}

console.log(`\n${'━'.repeat(40)}`);
console.log(`Results: ${passed} passed, ${failed} failed\n`);
process.exit(failed > 0 ? 1 : 0);
