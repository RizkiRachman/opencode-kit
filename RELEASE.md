# Release Plan — opencode-kit

## Release Flow

```
PR → MERGE → 🤖 AUTO-PATCH-BUMP → TAG → PUBLISH
```

**Everything is fully automated.** When a PR is merged to `main`, the `release` workflow:
1. Reads the latest version from npm registry
2. Auto-increments the **patch** version (0.6.0 → 0.6.1)
3. Commits the version bump with `[skip ci]`
4. Runs tests
5. Creates git tag + publishes to npm

**You never need to bump versions manually.** Just merge your PR.

## Developer Workflow

```sh
# 1. Feature branch
git checkout -b feature/YYYYMMDD-description
# ... make changes ...

# 2. Commit & push
git add -A
git commit -m "type: description"
git push -u origin feature/YYYYMMDD-description

# 3. Create PR
gh pr create --title "type: description" --body "## Summary\nWhat changed"

# 4. Merge → auto-release triggers 🚀
gh pr merge <num> --merge
```

### Commit Types (for changelog clarity)
| Type | Use |
|------|-----|
| `feat` | New capability |
| `fix` | Bug fix |
| `chore` | Build, config, tooling |
| `docs` | Documentation |
| `refactor` | Code restructure |

---

## 🔧 Required Setup — One Time Only

The `release` workflow needs an npm token:

1. **Generate** an Automation token at https://www.npmjs.com/settings/ikieaneh/tokens
2. **Add** to GitHub: **Settings → Secrets and variables → Actions → New repository secret**
   - Name: `NPM_TOKEN`
   - Value: your npm token

---

## How the Automation Works

Workflow: `.github/workflows/release.yml`

1. **Trigger:** Every push to `main`
2. **Read latest:** `npm view @ikieaneh/opencode-kit version` (falls back to `0.0.0`)
3. **Bump patch:** `major.minor.patch+1`
4. **Update files:** `package.json` + `.claude-plugin/plugin.json`
5. **Commit** with `[skip ci]` (prevents re-triggering)
6. **Run tests**
7. **Create tag** `v<new-version>`
8. **Publish** `npm publish --access public`

### Version Rules

| Bump | How |
|------|-----|
| `patch` | **Auto** — every merge increments patch |
| `minor` | Manual — change `npm view` command logic |
| `major` | Manual — requires workflow change |

---

## Quick Reference

```
DEV      → git checkout -b feature/YYYYMMDD-desc
COMMIT   → git add -A && git commit -m "type: msg" && git push
PR       → gh pr create --title "type: msg" --body "## Summary"
MERGE    → gh pr merge <num> --merge  ← triggers auto-release 🚀
VERIFY   → python3 -c "import urllib.request, json; print(json.loads(urllib.request.urlopen('https://registry.npmjs.org/@ikieaneh/opencode-kit').read())['dist-tags']['latest'])"
```
