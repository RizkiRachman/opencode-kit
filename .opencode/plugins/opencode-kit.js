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
const ROOT_DIR = path.resolve(PLUGIN_ROOT);

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
  try {
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
    const templatePath = path.join(ROOT_DIR, 'contract.json');
    if (fs.existsSync(templatePath)) {
      fs.mkdirSync(path.dirname(contractPath), { recursive: true });
      fs.copyFileSync(templatePath, contractPath);
      log('info', `Auto-initialized contract from plugin template: ${contractPath}`);
      return contractPath;
    }

    log('warn', 'Could not auto-initialize contract — no template found');
    return null;
  } catch (err) {
    log('error', `Failed to auto-init contract: ${err.message}`);
    return null;
  }
};

// --- Auto-provision agents if missing ---
const ensureAgents = (projectDir) => {
  try {
    const sourceDir = path.join(PLUGIN_ROOT, 'agents');
    const destDir = path.join(projectDir, '.opencode', 'agents');

    // Skip if dest exists and has .md files
    if (fs.existsSync(destDir)) {
      const existing = fs.readdirSync(destDir).filter(f => f.endsWith('.md'));
      if (existing.length > 0) {
        log('info', `Agents already provisioned (${existing.length} files) — skipping`);
        return;
      }
    }

    // Copy all .md files from source to dest
    if (!fs.existsSync(sourceDir)) {
      log('warn', `Source agents dir not found: ${sourceDir}`);
      return;
    }

    fs.mkdirSync(destDir, { recursive: true });
    const files = fs.readdirSync(sourceDir).filter(f => f.endsWith('.md'));
    for (const file of files) {
      fs.copyFileSync(path.join(sourceDir, file), path.join(destDir, file));
    }
    log('info', `Provisioned ${files.length} agents → ${destDir}`);
  } catch (err) {
    log('error', `Failed to auto-provision agents: ${err.message}`);
  }
};

// --- Auto-provision skills if missing ---
const ensureSkills = (projectDir) => {
  try {
    const sourceDir = path.join(PLUGIN_ROOT, 'skills');
    const destDir = path.join(projectDir, '.opencode', 'skills');

    // Skip if dest exists and has subdirectories
    if (fs.existsSync(destDir)) {
      const existing = fs.readdirSync(destDir).filter(f => {
        return fs.statSync(path.join(destDir, f)).isDirectory();
      });
      if (existing.length > 0) {
        log('info', `Skills already provisioned (${existing.length} dirs) — skipping`);
        return;
      }
    }

    // Copy all skill directories from source to dest
    if (!fs.existsSync(sourceDir)) {
      log('warn', `Source skills dir not found: ${sourceDir}`);
      return;
    }

    fs.mkdirSync(destDir, { recursive: true });
    const dirs = fs.readdirSync(sourceDir).filter(f => {
      return fs.statSync(path.join(sourceDir, f)).isDirectory();
    });
    for (const dir of dirs) {
      fs.cpSync(path.join(sourceDir, dir), path.join(destDir, dir), { recursive: true });
    }
    log('info', `Provisioned ${dirs.length} skills → ${destDir}`);
  } catch (err) {
    log('error', `Failed to auto-provision skills: ${err.message}`);
  }
};

// --- Auto-provision rules if missing ---
const ensureRules = (projectDir) => {
  try {
    const sourceDir = path.join(PLUGIN_ROOT, 'rules');
    const destDir = path.join(projectDir, '.opencode', 'rules');

    // Skip if dest exists and has .json files
    if (fs.existsSync(destDir)) {
      const existing = fs.readdirSync(destDir).filter(f => f.endsWith('.json'));
      if (existing.length > 0) {
        log('info', `Rules already provisioned (${existing.length} files) — skipping`);
        return;
      }
    }

    // Copy all .json files from source to dest
    if (!fs.existsSync(sourceDir)) {
      log('warn', `Source rules dir not found: ${sourceDir}`);
      return;
    }

    fs.mkdirSync(destDir, { recursive: true });
    const files = fs.readdirSync(sourceDir).filter(f => f.endsWith('.json'));
    for (const file of files) {
      fs.copyFileSync(path.join(sourceDir, file), path.join(destDir, file));
    }
    log('info', `Provisioned ${files.length} rules → ${destDir}`);
  } catch (err) {
    log('error', `Failed to auto-provision rules: ${err.message}`);
  }
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
- [ ] contract.governance.permissions.allowed_execution respected?
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

  // Auto-provision agents, skills, and rules
  ensureAgents(projectDir);
  ensureSkills(projectDir);
  ensureRules(projectDir);

  // Ensure global config directory exists
  try {
    fs.mkdirSync(path.join(globalConfigDir, 'orchestration'), { recursive: true });
    fs.mkdirSync(path.join(globalConfigDir, 'rules'), { recursive: true });
  } catch (err) {
    log('warn', `Failed to create global config dirs: ${err.message}`);
  }

  return {
    // Skill resolution order (first match wins):
    //   1. .opencode/skills/<name>/  (user project — highest priority)
    //   2. plugin skills/<name>/     (opencode-kit defaults — fallback)
    config: async (config) => {
      try {
        config.skills = config.skills || {};
        config.skills.paths = config.skills.paths || [];

        // Detect if other plugins might conflict with opencode-kit's system prompt
        if (config.plugins && Array.isArray(config.plugins)) {
          const kitIndex = config.plugins.findIndex(p =>
            typeof p === 'string' && p.includes('opencode-kit')
          );
          if (kitIndex > 0) {
            const firstPlugin = config.plugins[0];
            log('warn', `Plugin ordering conflict: opencode-kit should be FIRST, but found '${firstPlugin}' at position 0 and opencode-kit at position ${kitIndex}`);
          }
        }

        // Register user project skills FIRST (higher priority)
        const userSkillsDir = path.join(projectDir, '.opencode/skills');
        if (fs.existsSync(userSkillsDir) && !config.skills.paths.includes(userSkillsDir)) {
          config.skills.paths.push(userSkillsDir);
          log('info', `Registered user skills: ${userSkillsDir}`);
        }

        // Register plugin skills SECOND (fallback)
        if (!config.skills.paths.includes(SKILLS_DIR)) {
          config.skills.paths.push(SKILLS_DIR);
          log('info', `Registered plugin skills: ${SKILLS_DIR}`);
        }

        // Register global config skills path
        if (!config.skills.paths.includes(globalConfigDir)) {
          if (fs.existsSync(globalConfigDir)) {
            config.skills.paths.push(globalConfigDir);
          }
        }

        // Inject agent configs from template if not present in project
        const templateConfigPath = path.join(ROOT_DIR, 'opencode.json.template');
        if (fs.existsSync(templateConfigPath)) {
          try {
            const templateConfig = JSON.parse(fs.readFileSync(templateConfigPath, 'utf8'));
            const templateAgents = templateConfig.agent || {};
            config.agent = config.agent || {};
            let injected = 0;
            for (const [name, agentCfg] of Object.entries(templateAgents)) {
              if (!config.agent[name]) {
                config.agent[name] = agentCfg;
                injected++;
              }
            }
            // Inject command configs from template if not present
            const templateCommands = templateConfig.command || {};
            config.command = config.command || {};
            let cmdsInjected = 0;
            for (const [name, cmdCfg] of Object.entries(templateCommands)) {
              if (!config.command[name]) {
                config.command[name] = cmdCfg;
                cmdsInjected++;
              }
            }
            if (cmdsInjected > 0) {
              log('info', `Injected ${cmdsInjected} command configs from kit template`);
            }

            // Inject MCP configs from template if not present
            const templateMcp = templateConfig.mcp || {};
            config.mcp = config.mcp || {};
            let mcpsInjected = 0;
            for (const [name, mcpCfg] of Object.entries(templateMcp)) {
              if (!config.mcp[name]) {
                config.mcp[name] = mcpCfg;
                mcpsInjected++;
              }
            }
            if (mcpsInjected > 0) {
              log('info', `Injected ${mcpsInjected} MCP configs from kit template`);
            }

            // Inject permission configs from template if not present
            const templatePerms = templateConfig.permission || {};
            config.permission = config.permission || {};
            let permsInjected = 0;
            for (const [name, permCfg] of Object.entries(templatePerms)) {
              if (!config.permission[name]) {
                config.permission[name] = permCfg;
                permsInjected++;
              }
            }
            if (permsInjected > 0) {
              log('info', `Injected ${permsInjected} permission configs from kit template`);
            }

            if (injected > 0) {
              log('info', `Injected ${injected} agent configs from kit template`);
            }
          } catch (err) {
            log('warn', `Failed to inject agent configs: ${err.message}`);
          }
        }

        // Provide default contract key hint for agents
        config.contractKey = contractKey;
      } catch (err) {
        log('error', `config hook failed: ${err.message}`);
      }
    },

    'experimental.chat.messages.transform': async (_input, output) => {
      try {
        const bootstrap = getBootstrapContent();
        if (!bootstrap || !output.messages.length) return;

        // Check contract for rule_overrides + allowed_execution and inject them into bootstrap
        const contractPath = path.join(projectDir, '.opencode', 'orchestration', 'contract.json');
        let finalBootstrap = bootstrap;
        if (fs.existsSync(contractPath)) {
          try {
            const contractRaw = fs.readFileSync(contractPath, 'utf8');
            const contract = JSON.parse(contractRaw);

            // Inject rule_overrides if present
            if (contract.validation && contract.validation.rule_overrides) {
              const overrides = contract.validation.rule_overrides;
              const overrideKeys = Object.keys(overrides);
              if (overrideKeys.length > 0) {
                const overrideText = overrideKeys
                  .map(id => `  - ${id}: action → ${overrides[id]}`)
                  .join('\n');
                finalBootstrap = bootstrap + `\n## Rule Overrides (from contract)\n\nThe following rule severities have been overridden:\n${overrideText}\n`;
              }
            }

            // Inject allowed_execution whitelist if present
            if (contract.governance && contract.governance.permissions && contract.governance.permissions.allowed_execution) {
              const ae = contract.governance.permissions.allowed_execution;
              const toolsList = (ae.tools || []).length > 0 ? ae.tools.join(', ') : '(none)';
              const deniedList = (ae.denied || []).length > 0 ? ae.denied.join(', ') : '(none)';
              const execText = `\n## Execution Permission Whitelist (from contract)\n\nThis project enforces a contract-based execution whitelist — principle of least privilege:\n  Allowed: ${toolsList}\n  Denied: ${deniedList}\n\nAgents MUST only use whitelisted tools for shell execution. Violations trigger SHELL_002 (CRITICAL/BLOCK).\n`;
              finalBootstrap += execText;
            }
          } catch (err) {
            log('warn', `Failed to parse contract for rules/permissions: ${err.message}`);
          }
        }

        const firstUser = output.messages.find(m => m.info.role === 'user');
        if (!firstUser || !firstUser.parts.length) return;

        // Guard: skip if already injected
        if (firstUser.parts.some(p => p.type === 'text' && p.text.includes('opencode-kit'))) return;

        const ref = firstUser.parts[0];
        firstUser.parts.unshift({ ...ref, type: 'text', text: finalBootstrap });
      } catch (err) {
        log('error', `messages.transform hook failed: ${err.message}`);
      }
    }
  };
};
