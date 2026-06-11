/**
 * opencode-kit plugin for OpenCode.ai
 *
 * Injects contract + rules enforcement into every session.
 * Auto-registers skills directory. Auto-initializes contract if missing.
 * Contract keys are unique per project (hashed from git remote).
 */

import path from 'path';
import fs from 'fs';
import os from 'os';
import crypto from 'crypto';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = path.resolve(__dirname, '../..');
const SKILLS_DIR = path.resolve(PLUGIN_ROOT, 'skills');
const TEMPLATES_DIR = path.resolve(PLUGIN_ROOT, 'templates');

let _bootstrapCache = undefined;
let _pluginLogger = undefined;

// --- Minimal logger (avoids console.log — uses client api if available) ---
const log = (level, msg) => {
  const prefix = `[opencode-kit]`;
  if (_pluginLogger && typeof _pluginLogger[level] === 'function') {
    _pluginLogger[level](`${prefix} ${msg}`);
  } else if (typeof process !== 'undefined' && process.stderr) {
    process.stderr.write(`${prefix} ${msg}\n`);
  }
};

// --- Generate unique contract key per project ---
const getProjectHash = (projectDir) => {
  // Try git remote first
  const gitConfigPath = path.join(projectDir, '.git', 'config');
  if (fs.existsSync(gitConfigPath)) {
    const config = fs.readFileSync(gitConfigPath, 'utf8');
    const remoteMatch = config.match(/\[remote "origin"\][\s\S]*?url\s*=\s*(.+)/);
    if (remoteMatch) {
      const hash = crypto.createHash('sha256').update(remoteMatch[1].trim()).digest('hex').slice(0, 12);
      return `orchestration-contract:${hash}`;
    }
  }
  // Fallback: hash the absolute path
  const hash = crypto.createHash('sha256').update(projectDir).digest('hex').slice(0, 12);
  return `orchestration-contract:${hash}`;
};

// --- Resolve config: project → global → plugin default ---
const resolveConfigPath = (projectDir, relPath) => {
  const homeDir = os.homedir();
  const globalDir = path.join(homeDir, '.config/opencode-kit');

  // 1. Project override
  const projectPath = path.join(projectDir, '.opencode', relPath);
  if (fs.existsSync(projectPath)) return projectPath;

  // 2. Global defaults
  const globalPath = path.join(globalDir, relPath);
  if (fs.existsSync(globalPath)) return globalPath;

  // 3. Plugin templates
  const pluginPath = path.join(TEMPLATES_DIR, relPath);
  if (fs.existsSync(pluginPath)) return pluginPath;

  // 4. Plugin root
  const rootPath = path.join(PLUGIN_ROOT, relPath);
  if (fs.existsSync(rootPath)) return rootPath;

  return null;
};

// --- Auto-init contract.json if missing ---
const ensureContract = (projectDir) => {
  const homeDir = os.homedir();
  const globalDir = path.join(homeDir, '.config/opencode-kit');
  const contractPath = path.join(projectDir, '.opencode', 'orchestration', 'contract.json');

  // Already exists — nothing to do
  if (fs.existsSync(contractPath)) return contractPath;

  // Check global config first
  const globalContract = path.join(globalDir, 'orchestration', 'contract.json');
  if (fs.existsSync(globalContract)) {
    fs.mkdirSync(path.dirname(contractPath), { recursive: true });
    fs.copyFileSync(globalContract, contractPath);
    log('info', `Auto-initialized contract from global config: ${contractPath}`);
    return contractPath;
  }

  // Scaffold from plugin template
  const templatePath = path.join(TEMPLATES_DIR, 'contract.json');
  if (fs.existsSync(templatePath)) {
    fs.mkdirSync(path.dirname(contractPath), { recursive: true });
    fs.copyFileSync(templatePath, contractPath);
    log('info', `Auto-initialized contract from plugin template: ${contractPath}`);
    return contractPath;
  }

  log('warn', 'Could not auto-initialize contract — no template found');
  return null;
};

// --- Load bootstrap content (cached) ---
const getBootstrapContent = () => {
  if (_bootstrapCache !== undefined) return _bootstrapCache;

  const skillPath = path.join(SKILLS_DIR, 'orchestration-template', 'SKILL.md');
  if (!fs.existsSync(skillPath)) {
    log('warn', 'orchestration-template skill not found');
    _bootstrapCache = null;
    return null;
  }

  const fullContent = fs.readFileSync(skillPath, 'utf8');
  const match = fullContent.match(/^---\n[\s\S]*?\n---\n([\s\S]*)$/);
  const content = match ? match[1] : fullContent;

  _bootstrapCache = `<EXTREMELY_IMPORTANT>
You have opencode-kit — a standardized orchestration framework.

**Contract Protocol (MANDATORY):**
Before any tool call, you MUST load the orchestration contract:
  lean-ctx ctx_knowledge recall --query "orchestration-contract"

If not found in lean-ctx, check:
  1. .opencode/orchestration/contract.json  (project override)
  2. ~/.config/opencode-kit/contract.json    (global defaults)

If neither exists, run: npx opencode-kit init

**Pre-flight checklist (CRITICAL):**
- [ ] Loaded contract from lean-ctx or file?
- [ ] Not on main/master branch?
- [ ] contract.state allows current action?
- [ ] rules.json loaded?

**Rules enforcement:**
CRITICAL rules → BLOCK. HIGH rules → FLAG. Never skip.

${content}
</EXTREMELY_IMPORTANT>`;

  return _bootstrapCache;
};

export const OpencodeKitPlugin = async ({ client, directory }) => {
  const homeDir = os.homedir();
  const projectDir = directory || process.cwd();
  const globalConfigDir = path.join(homeDir, '.config/opencode-kit');
  const contractKey = getProjectHash(projectDir);

  // Wire up logger
  _pluginLogger = client?.log || null;

  log('info', `Plugin loaded (project: ${path.basename(projectDir)}, key: ${contractKey})`);

  // Auto-init contract on first run
  ensureContract(projectDir);

  // Ensure global config directory exists
  fs.mkdirSync(path.join(globalConfigDir, 'orchestration'), { recursive: true });
  fs.mkdirSync(path.join(globalConfigDir, 'rules'), { recursive: true });

  return {
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];

      if (!config.skills.paths.includes(SKILLS_DIR)) {
        config.skills.paths.push(SKILLS_DIR);
        log('info', `Registered skills: ${SKILLS_DIR}`);
      }

      // Register global config skills path
      if (!config.skills.paths.includes(globalConfigDir)) {
        if (fs.existsSync(globalConfigDir)) {
          config.skills.paths.push(globalConfigDir);
        }
      }

      // Provide default contract key hint for agents
      config.contractKey = contractKey;
    },

    'experimental.chat.messages.transform': async (_input, output) => {
      const bootstrap = getBootstrapContent();
      if (!bootstrap || !output.messages.length) return;

      const firstUser = output.messages.find(m => m.info.role === 'user');
      if (!firstUser || !firstUser.parts.length) return;

      // Guard: skip if already injected
      if (firstUser.parts.some(p => p.type === 'text' && p.text.includes('opencode-kit'))) return;

      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
    }
  };
};
