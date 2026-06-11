# Release Plan — opencode-kit

## Release Flow

```
BRANCH → COMMIT → TEST → PR → MERGE → 🤖 AUTO-TAG + PUBLISH
```

**Tagging and publishing are fully automated via GitHub Actions.** When a PR is merged to `main`, the `release` workflow automatically creates a git tag and publishes to npm — no manual steps required.

## Phase 1: Branch & Develop

```sh
git checkout -b feature/YYYYMMDD-description
# Make changes
```

### File Change Order
1. **Core files** (plugin.js, rules/, src/*.sh)
2. **Templates** (templates/agents/*.md, templates/contract.json)
3. **Skills** (skills/*/)
4. **Docs** (README.md, CHANGELOG.md, docs/examples/)
5. **Tests** (test/*.test.js)

### Version Bump
Update the version in `package.json` before merging:

| Bump | When |
|------|------|
| `patch` | Bug fixes, small tweaks |
| `minor` | New features, breaking script changes |
| `major` | Breaking plugin API changes |

**The release workflow reads `package.json` version and creates tag `v<version>`.**

## Phase 2: Test

Run all tests before committing:

```sh
node test/integration.test.js   # 7 tests — plugin hooks, JSON validity
node test/e2e.test.js           # 9 tests — plugin lifecycle, auto-init
```

All 16 must pass (0 failed).

The release workflow also runs these tests before publishing.

## Phase 3: Commit & PR

```sh
git add -A
git commit -m "type: description"
git push -u origin feature/YYYYMMDD-description
gh pr create \
  --title "type: description" \
  --body "## Summary\n<bullet points>"
```

### Commit Types
| Type | Use |
|------|-----|
| `feat` | New capability |
| `fix` | Bug fix |
| `chore` | Build, config, tooling |
| `docs` | Documentation |
| `refactor` | Code restructure |

### Review & Merge
1. CI validates the PR (ShellCheck, scaffold test, syntax, integration, E2E)
2. Merge to `main` using the **merge commit** strategy
3. ✅ **Release is automatic** — the `release` workflow handles tag + publish

---

## 🔧 Required Setup — One Time Only

For the automated release workflow to work, you must configure **one GitHub secret**:

### 1. Generate an npm automation token

```sh
# Visit https://www.npmjs.com/settings/<username>/tokens
# Create an "Automation" token (read + publish)
```

### 2. Add as a GitHub Actions secret

| Setting | Value |
|---------|-------|
| Repository | `RizkiRachman/opencode-kit` |
| Settings → Secrets and variables → Actions |
| **New repository secret** |
| Name: `NPM_TOKEN` |
| Value: `<your npm automation token>` |

That's it. No manual tagging, no `npm publish` from your machine.

---

## How the Automation Works

The workflow at `.github/workflows/release.yml`:

1. **Triggers** on every push to `main` (which happens when a PR is merged)
2. **Reads** the version from `package.json`
3. **Checks** if a git tag `v<version>` already exists
   - **Tag exists** → skips (already published)
   - **No tag** → runs tests, creates tag, publishes to npm
4. **Publishes** `npm publish --access public`

### Post-Release Verification

```sh
# Confirm latest version on npm
python3 -c "import urllib.request, json; print(json.loads(urllib.request.urlopen('https://registry.npmjs.org/@ikieaneh/opencode-kit').read())['dist-tags']['latest'])"
```

---

## Quick Reference

```
DEV    → git checkout -b feature/YYYYMMDD-desc
TEST   → node test/integration.test.js && node test/e2e.test.js
BUMP   → Update version in package.json + CHANGELOG.md
COMMIT → git add -A && git commit -m "type: msg" && git push
PR     → gh pr create --title "type: msg" --body "## Summary"
MERGE  → gh pr merge <num> --merge  ← triggers auto-release 🚀
```
