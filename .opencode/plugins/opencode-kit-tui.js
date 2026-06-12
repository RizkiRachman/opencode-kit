/**
 * opencode-kit TUI plugin for OpenCode.ai
 *
 * Registers command palette entries and /-slash commands for opencode-kit
 * operations (init, doctor, status, verify, ADR).
 *
 * Add to opencode.json as: "@ikieaneh/opencode-kit/tui"
 *
 * Requires: @opencode-ai/plugin >= 1.3.17 (TuiPluginApi with command.register)
 *
 * Commands registered:
 *   /kit-init (ki)   — Scaffold orchestration framework
 *   /kit-doctor (kd) — Run diagnostics
 *   /kit-status (ks) — Show contract state
 *   /kit-verify (kv) — Verify installation
 *   /kit-adr (ka)    — Record an Architecture Decision Record
 */

import { execSync } from 'child_process';
import path from 'path';
import fs from 'fs';
import { fileURLToPath } from 'url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const PLUGIN_ROOT = path.resolve(__dirname, '../..');

// ---- Helpers ----

/**
 * Run a shell script from the opencode-kit package.
 * @param {string} scriptRelPath - Relative path from package root (e.g. "src/init.sh")
 * @param {string} args - CLI arguments
 * @param {string} cwd - Working directory (user's project)
 * @returns {{ ok: boolean, output: string }}
 */
const runScript = (scriptRelPath, args = '', cwd) => {
  const scriptPath = path.resolve(PLUGIN_ROOT, scriptRelPath);
  if (!fs.existsSync(scriptPath)) {
    return {
      ok: false,
      output: `Script not found: ${scriptPath}\nEnsure opencode-kit is installed: npm install @ikieaneh/opencode-kit`,
    };
  }

  try {
    const stdout = execSync(
      `bash "${scriptPath}" ${args}`,
      {
        encoding: 'utf8',
        timeout: 60000,
        cwd: cwd || process.cwd(),
        maxBuffer: 1024 * 1024,
        env: { ...process.env, TERM: 'dumb' },
      },
    );
    return { ok: true, output: stdout.trim() };
  } catch (err) {
    const message = err.stderr || err.stdout || err.message || String(err);
    return { ok: false, output: message.trim().slice(0, 2000) };
  }
};

// ---- Plugin ----

/**
 * opencode-kit TUI plugin.
 * Registers Ctrl+P palette commands and /-slash commands.
 */
export const tui = async (api, _options, _meta) => {
  const projectDir = api.state.path.directory;

  api.command.register(() => [
    // ── init ──
    {
      title: 'opencode-kit: Initialize',
      value: 'kit:init',
      description: 'Scaffold orchestration contract + rules into this project',
      category: 'opencode-kit',
      suggested: true,
      slash: { name: 'kit-init', aliases: ['ki'] },
      onSelect: async () => {
        api.ui.toast({
          title: 'Initializing...',
          message: 'Scaffolding opencode-kit framework',
          variant: 'info',
          duration: 5000,
        });

        const result = runScript('src/init.sh', '', projectDir);

        api.ui.toast({
          title: result.ok ? 'Initialized' : 'Initialization Failed',
          message: result.ok
            ? 'opencode-kit framework scaffolded successfully'
            : result.output.slice(0, 300),
          variant: result.ok ? 'success' : 'error',
          duration: 8000,
        });

        if (!result.ok) {
          api.dialog.replace(() =>
            api.ui.DialogAlert({
              title: 'Init Failed',
              message: result.output.slice(0, 2000),
            }),
          );
        }
      },
    },

    // ── doctor ──
    {
      title: 'opencode-kit: Doctor',
      value: 'kit:doctor',
      description: 'Run diagnostics — MCPs, contract, git branch, persistence',
      category: 'opencode-kit',
      slash: { name: 'kit-doctor', aliases: ['kd'] },
      onSelect: async () => {
        api.ui.toast({
          title: 'Running doctor...',
          message: 'Checking system health',
          variant: 'info',
        });

        const result = runScript('src/doctor.sh', '', projectDir);

        api.dialog.replace(() =>
          api.ui.DialogAlert({
            title: result.ok ? 'All Checks Passed' : 'Issues Found',
            message: result.output.slice(0, 3000),
          }),
        );
      },
    },

    // ── status ──
    {
      title: 'opencode-kit: Status',
      value: 'kit:status',
      description: 'Show contract state, telemetry, and phase info',
      category: 'opencode-kit',
      slash: { name: 'kit-status', aliases: ['ks'] },
      onSelect: async () => {
        const result = runScript('src/status.sh', '', projectDir);

        api.dialog.replace(() =>
          api.ui.DialogAlert({
            title: 'opencode-kit Status',
            message: (result.ok ? result.output : result.output).slice(0, 4000),
          }),
        );
      },
    },

    // ── verify ──
    {
      title: 'opencode-kit: Verify',
      value: 'kit:verify',
      description: 'Verify installation — check all files and permissions',
      category: 'opencode-kit',
      slash: { name: 'kit-verify', aliases: ['kv'] },
      onSelect: async () => {
        api.ui.toast({
          title: 'Verifying...',
          message: 'Checking installation integrity',
          variant: 'info',
        });

        const result = runScript('src/verify.sh', '', projectDir);

        api.dialog.replace(() =>
          api.ui.DialogAlert({
            title: result.ok ? 'Verification Passed' : 'Verification Failed',
            message: result.output.slice(0, 3000),
          }),
        );
      },
    },

    // ── adr ──
    {
      title: 'opencode-kit: New ADR',
      value: 'kit:adr',
      description: 'Record an Architecture Decision Record',
      category: 'opencode-kit',
      slash: { name: 'kit-adr', aliases: ['ka'] },
      onSelect: async () => {
        // Step 1: Prompt for title
        api.dialog.replace(() =>
          api.ui.DialogPrompt({
            title: 'New ADR',
            description: () =>
              'Record an Architecture Decision Record.\nEnter the decision title:',
            placeholder: 'e.g., Use PostgreSQL for primary storage',
            onConfirm: (title) => {
              if (!title || !title.trim()) {
                api.dialog.clear();
                return;
              }

              const cleanTitle = title.replace(/"/g, '\\"').replace(/`/g, '\\`');
              const result = runScript(
                'src/adr.sh',
                `--title "${cleanTitle}"`,
                projectDir,
              );

              api.dialog.clear();
              api.ui.toast({
                title: result.ok ? 'ADR Recorded' : 'ADR Failed',
                message: result.ok
                  ? `ADR "${title}" saved to contract`
                  : result.output.slice(0, 300),
                variant: result.ok ? 'success' : 'error',
              });

              if (!result.ok) {
                api.dialog.replace(() =>
                  api.ui.DialogAlert({
                    title: 'ADR Failed',
                    message: result.output.slice(0, 2000),
                  }),
                );
              }
            },
            onCancel: () => api.dialog.clear(),
          }),
        );
      },
    },
  ]);
};
