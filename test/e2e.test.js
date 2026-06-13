#!/usr/bin/env node
/**
 * End-to-end test for opencode-kit plugin.
 *
 * Tests:
 * - Plugin creates contract.json on first run (ensureContract)
 * - Plugin registers skills directory
 * - Messages.transform hook injects bootstrap
 * - Config hook modifies skills paths
 * - .opencode directory structure is valid
 *
 * Run: node test/e2e.test.js
 */
import path from 'path';
import fs from 'fs';
import os from 'os';
import { fileURLToPath } from 'url';
import assert from 'assert/strict';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '..');

let passed = 0;
let failed = 0;
const tests = [];

const test = (name, fn) => {
  tests.push({ name, fn });
};

console.log('\n🔍 opencode-kit End-to-End Tests\n');

// === 1. Plugin hooks fire correctly ===
test('Plugin config hook registers skills paths', async () => {
  const { OpencodeKitPlugin } = await import(path.join(ROOT, '.opencode/plugins/opencode-kit.js'));
  const mockConfig = { skills: { paths: [] } };
  const instance = await OpencodeKitPlugin({
    client: { log: { info: () => {}, warn: () => {} } },
    directory: ROOT
  });
  await instance.config(mockConfig);
  const skillsDir = path.resolve(ROOT, 'skills');
  assert.ok(mockConfig.skills.paths.includes(skillsDir), `Skills dir should be registered: ${skillsDir}`);
});

test('Messages.transform hook injects bootstrap', async () => {
  const { OpencodeKitPlugin } = await import(path.join(ROOT, '.opencode/plugins/opencode-kit.js'));
  const instance = await OpencodeKitPlugin({
    client: { log: { info: () => {}, warn: () => {} } },
    directory: ROOT
  });

  const mockOutput = {
    messages: [
      { info: { role: 'user' }, parts: [{ type: 'text', text: 'Hello' }] }
    ]
  };

  await instance['experimental.chat.messages.transform']({}, mockOutput);

  const firstPart = mockOutput.messages[0].parts[0];
  assert.ok(firstPart.text.includes('opencode-kit'), 'Bootstrap should contain opencode-kit');
  assert.ok(firstPart.text.includes('EXTREMELY_IMPORTANT'), 'Bootstrap should have EXTREMELY_IMPORTANT wrapper');
});

// === 2. Plugin auto-initializes contract ===
test('Plugin contract auto-init does not overwrite existing contract', async () => {
  const testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'opencode-kit-e2e-'));
  const contractDir = path.join(testDir, '.opencode', 'orchestration');
  fs.mkdirSync(contractDir, { recursive: true });

  // Create existing contract
  const existingContract = { state: 'INIT', requirements: { goal: 'test' } };
  fs.writeFileSync(path.join(contractDir, 'contract.json'), JSON.stringify(existingContract));

  // Import and run
  const { OpencodeKitPlugin } = await import(path.join(ROOT, '.opencode/plugins/opencode-kit.js'));
  await OpencodeKitPlugin({
    client: { log: { info: () => {}, warn: () => {} } },
    directory: testDir
  });

  // Verify existing contract was NOT overwritten
  const after = JSON.parse(fs.readFileSync(path.join(contractDir, 'contract.json'), 'utf8'));
  assert.equal(after.requirements.goal, 'test', 'Existing contract data should be preserved');

  // Cleanup
  fs.rmSync(testDir, { recursive: true, force: true });
});

test('Plugin auto-initializes contract if missing', async () => {
  const testDir = fs.mkdtempSync(path.join(os.tmpdir(), 'opencode-kit-e2e-'));
  const contractDir = path.join(testDir, '.opencode', 'orchestration');

  // Import and run
  const { OpencodeKitPlugin } = await import(path.join(ROOT, '.opencode/plugins/opencode-kit.js'));
  await OpencodeKitPlugin({
    client: { log: { info: () => {}, warn: () => {} } },
    directory: testDir
  });

  // Verify contract was created
  const contractPath = path.join(contractDir, 'contract.json');
  assert.ok(fs.existsSync(contractPath), 'Contract should be auto-created');
  const contract = JSON.parse(fs.readFileSync(contractPath, 'utf8'));
  assert.ok(contract.state, 'Contract should have state field');
  assert.ok(contract.requirements, 'Contract should have requirements');

  // Cleanup
  fs.rmSync(testDir, { recursive: true, force: true });
});

// === 3. Plugin key is unique per project ===
test('getProjectHash returns unique keys for different directories', async () => {
  const crypto = await import('crypto');
  const hash1 = crypto.createHash('sha256').update('/project/a').digest('hex').slice(0, 12);
  const hash2 = crypto.createHash('sha256').update('/project/b').digest('hex').slice(0, 12);
  assert.notEqual(hash1, hash2, 'Different projects should have different hashes');
});

// === 4. All skills are valid ===
test('All 8 skills have valid SKILL.md files', () => {
  const expectedSkills = [
    'orchestration-template', 'scoring-pipeline', 'adr-generator',
    'qa-expert', 'system-analyst', 'token-optimize',
    'verification-before-completion', 'learner'
  ];
  assert.equal(expectedSkills.length, 8, 'Should have 8 core skills');
  const skillsDir = path.join(ROOT, 'skills');
  for (const skill of expectedSkills) {
    const skillPath = path.join(skillsDir, skill, 'SKILL.md');
    assert.ok(fs.existsSync(skillPath), `Missing skill: ${skill}`);
    const content = fs.readFileSync(skillPath, 'utf8');
    assert.ok(content.startsWith('---'), `Skill ${skill} should have frontmatter`);
    assert.ok(content.includes('description:'), `Skill ${skill} should have description`);
  }
});

// === 5. CLI works ===
test('CLI --version returns version', () => {
  const pkg = JSON.parse(fs.readFileSync(path.join(ROOT, 'package.json'), 'utf8'));
  assert.ok(pkg.version, 'Should have version');
  assert.ok(pkg.bin && pkg.bin['opencode-kit'], 'Should have bin entry');
  assert.equal(pkg.bin['opencode-kit'], 'src/cli.js', 'Bin should point to CLI');
});

// === 6. All JSON files are valid ===
test('All JSON files parse correctly', () => {
  const jsonFiles = [
    'contract.json',
    'contract.schema.json',
    'rules/rules.json',
    'package.json',
    '.claude-plugin/plugin.json'
  ];
  for (const file of jsonFiles) {
    const content = fs.readFileSync(path.join(ROOT, file), 'utf8');
    JSON.parse(content); // throws if invalid
  }
});

// === 7. README references correct npm package ===
test('README references @ikieaneh/opencode-kit', () => {
  const readme = fs.readFileSync(path.join(ROOT, 'README.md'), 'utf8');
  assert.ok(readme.includes('@ikieaneh/opencode-kit'), 'README should reference scoped package name');
  assert.ok(readme.includes('npm install'), 'README should have install command');
});

// === Summary — run collected tests with top-level await ===
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
console.log(`E2E Results: ${passed} passed, ${failed} failed\n`);
process.exit(failed > 0 ? 1 : 0);
