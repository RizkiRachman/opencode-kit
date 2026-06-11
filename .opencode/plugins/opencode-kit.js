/**
 * opencode-kit plugin for OpenCode.ai
 *
 * Injects contract + rules enforcement into every session.
 * Auto-registers skills directory. No per-project scaffolding needed.
 *
 * Config resolution:
 *   1. .opencode/orchestration/contract.json  (project override)
 *   2. ~/.config/opencode-kit/contract.json    (global defaults)
 *   3. [plugin]/templates/contract.json         (plugin defaults)
 */

import path from 'path';
import fs from 'fs';
import os from 'os';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = path.resolve(__dirname, '../..');
const SKILLS_DIR = path.resolve(PLUGIN_ROOT, 'skills');

// --- Bootstrap content cache (loaded once per session) ---
let _bootstrapCache = undefined;

export const OpencodeKitPlugin = async ({ client, directory }) => {
  const homeDir = os.homedir();
  const globalConfigDir = path.join(homeDir, '.config/opencode-kit');

  // Lazy-load and cache the orchestration-template skill as bootstrap
  const getBootstrapContent = () => {
    if (_bootstrapCache !== undefined) return _bootstrapCache;

    const skillPath = path.join(SKILLS_DIR, 'orchestration-template', 'SKILL.md');
    if (!fs.existsSync(skillPath)) {
      console.warn('[opencode-kit] orchestration-template skill not found');
      _bootstrapCache = null;
      return null;
    }

    const fullContent = fs.readFileSync(skillPath, 'utf8');
    // Strip frontmatter
    const match = fullContent.match(/^---\n[\s\S]*?\n---\n([\s\S]*)$/);
    const content = match ? match[1] : fullContent;

    _bootstrapCache = `<EXTREMELY_IMPORTANT>
You have opencode-kit — a standardized orchestration framework.

**Contract Protocol (MANDATORY):**
Before any tool call, you MUST load the orchestration contract:
  lean-ctx ctx_knowledge recall --query "orchestration-contract"

If not found in lean-ctx, check these paths in order:
  1. .opencode/orchestration/contract.json  (project override)
  2. ~/.config/opencode-kit/contract.json    (global defaults)

If neither exists, the project has not been initialized.
Run: npx opencode-kit init

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

  return {
    // Register skills directory so OpenCode discovers opencode-kit skills
    config: async (config) => {
      config.skills = config.skills || {};
      config.skills.paths = config.skills.paths || [];

      if (!config.skills.paths.includes(SKILLS_DIR)) {
        config.skills.paths.push(SKILLS_DIR);
        console.log('[opencode-kit] Registered skills directory:', SKILLS_DIR);
      }

      // Register global config path for skill resolution
      if (!config.skills.paths.includes(globalConfigDir)) {
        config.skills.paths = config.skills.paths || [];
        if (fs.existsSync(globalConfigDir)) {
          config.skills.paths.push(globalConfigDir);
        }
      }
    },

    // Inject bootstrap into the first user message of each session.
    // Uses user message (not system) to avoid token bloat and model issues.
    'experimental.chat.messages.transform': async (_input, output) => {
      const bootstrap = getBootstrapContent();
      if (!bootstrap || !output.messages.length) return;

      const firstUser = output.messages.find(m => m.info.role === 'user');
      if (!firstUser || !firstUser.parts.length) return;

      // Guard: skip if already injected (prevents double injection)
      if (firstUser.parts.some(p => p.type === 'text' && p.text.includes('opencode-kit'))) return;

      const ref = firstUser.parts[0];
      firstUser.parts.unshift({ ...ref, type: 'text', text: bootstrap });
    }
  };
};
