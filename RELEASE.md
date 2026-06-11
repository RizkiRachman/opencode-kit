# Release Plan — opencode-kit

## Release Flow

```
BRANCH → COMMIT → TEST → PR → MERGE → TAG → PUBLISH
```

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

## Phase 2: Test

Run all tests before committing:

```sh
node test/integration.test.js   # 7 tests — plugin hooks, JSON validity
node test/e2e.test.js           # 9 tests — plugin lifecycle, auto-init
```

All 16 must pass (0 failed).

## Phase 3: Commit & PR

```sh
git add -A
git commit -m "type: description"
git push -u origin feature/YYYYMMDD-description
gh pr create \
  --title "type: description" \
  --body "## Summary\n<bullet points>"
gh pr merge --merge
```

### Commit Types
| Type | Use |
|------|-----|
| `feat` | New capability |
| `fix` | Bug fix |
| `chore` | Build, config, tooling |
| `docs` | Documentation |
| `refactor` | Code restructure |

## Phase 4: Tag & Publish

```sh
git checkout main
git pull origin main
npm version patch -m "chore: bump to v%s"
npm config set //registry.npmjs.org/:_authToken <token>
npm publish
git push --tags
```

### Version Rules
| Bump | When |
|------|------|
| `patch` | Bug fixes, small tweaks |
| `minor` | New features, breaking script changes |
| `major` | Breaking plugin API changes |

## Phase 5: Post-Release

```sh
# Verify publish
python3 -c "import urllib.request, json; print(json.loads(urllib.request.urlopen('https://registry.npmjs.org/@ikieaneh/opencode-kit').read())['dist-tags']['latest'])"
```

---

## Quick Reference

```
DEV  → git checkout -b feature/YYYYMMDD-desc
TEST → node test/integration.test.js && node test/e2e.test.js
COMMIT → git add -A && git commit -m "type: msg" && git push
PR   → gh pr create --title "type: msg" --body "## Summary"
TAG  → npm version patch && git push --tags
PUB  → npm publish
```
