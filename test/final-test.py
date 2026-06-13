#!/usr/bin/env python3
import json, os

os.chdir('/tmp/okit-final-test')
results = []
def check(name, passed, detail=""):
    results.append((name, passed))
    print(f"  {'✅' if passed else '❌'} {name}" + (f" — {detail}" if detail else ""))

print("=" * 60)
print("TEST SUITE — opencode-kit init.sh (FINAL)")
print("=" * 60)

print("\n1. DIRECTORY STRUCTURE")
for d in [".opencode", ".opencode/agents", ".opencode/skills", ".opencode/rules",
          ".opencode/orchestration", ".opencode/src"]:
    check(f"{d}/ exists", os.path.isdir(d))

print("\n2. AGENTS")
agents = sorted([f.replace('.md','') for f in os.listdir('.opencode/agents') if f.endswith('.md')])
check("15 agents", len(agents) == 15, f"got {len(agents)}")
expected = ['architect','code-reviewer','database-specialist','devops-agent',
    'documentation-agent','explorer','fixer','learner','librarian','observer',
    'orchestrator','planner','security-reviewer','task-manager','testing-specialist']
missing = set(expected) - set(agents)
check("all expected present", len(missing) == 0, f"missing: {missing}" if missing else "")
meta = sum(1 for a in agents if '_meta:' in open(f'.opencode/agents/{a}.md').read())
check("_meta in all", meta == 15, f"{meta}/15")
leanctx = sum(1 for a in agents if 'lean-ctx' in open(f'.opencode/agents/{a}.md').read())
check("lean-ctx in all", leanctx == 15, f"{leanctx}/15")
madar = sum(1 for a in agents if 'Madar' in open(f'.opencode/agents/{a}.md').read())
check("madar MCP in all", madar == 15, f"{madar}/15")

print("\n3. SKILLS")
skills = sorted([d for d in os.listdir('.opencode/skills') if os.path.isdir(f'.opencode/skills/{d}')])
check("19 skills", len(skills) == 19, f"got {len(skills)}")
valid = sum(1 for s in skills if os.path.exists(f'.opencode/skills/{s}/SKILL.md'))
check("all have SKILL.md", valid == len(skills), f"{valid}/{len(skills)}")

print("\n4. RULES")
rules = sorted([f for f in os.listdir('.opencode/rules') if f.endswith('.json')])
check("4 rule files", len(rules) == 4, f"got {len(rules)}")
for r in rules:
    with open(f'.opencode/rules/{r}') as f:
        data = json.load(f)
    extends = data.get('_meta',{}).get('extends')
    check(f"{r} extends=opencode-kit", extends == 'opencode-kit', f"got {extends}")

print("\n5. CONTRACT")
cp = '.opencode/orchestration/contract.json'
check("contract.json exists", os.path.exists(cp))
with open(cp) as f:
    c = json.load(f)
check("_meta.extends=opencode-kit", c.get('_meta',{}).get('extends') == 'opencode-kit')
check("state=INIT", c.get('state') == 'INIT')
check("has session", 'session' in c)
check("has governance", 'governance' in c)
check("has validation", 'validation' in c)

print("\n6. WORKFLOW RULES")
with open('.opencode/rules/workflow-rules.json') as f:
    wr = json.load(f)
check("7 steps", len(wr.get('steps',[])) == 7)
check("6 states", len(wr.get('workflow',{}).get('states',[])) == 6)
check("transitions", len(wr.get('workflow',{}).get('transitions',[])) > 0)
check("learner_rules (5)", len(wr.get('learner_rules',{}).get('rules',[])) == 5)
check("agent_rules (8)", len(wr.get('agent_rules',{}).get('rules',[])) == 8)

print("\n7. AGENT RULES")
with open('.opencode/rules/agent-rules.json') as f:
    ar = json.load(f)
check("enforcement (3)", len(ar.get('enforcement',{})) == 3)
check("permissions (15)", len(ar.get('permissions',{})) == 15)
check("scoring", 'scoring' in ar)
check("escalation (6)", len(ar.get('escalation',{}).get('rules',[])) == 6)

print("\n8. LEARNER RULES")
with open('.opencode/rules/learner-rules.json') as f:
    lr = json.load(f)
check("enforcement (3)", len(lr.get('enforcement',{})) == 3)
check("code_patterns (5)", len(lr.get('extraction_patterns',{}).get('code_patterns',{}).get('patterns',[])) == 5)
check("arch_patterns (3)", len(lr.get('extraction_patterns',{}).get('architecture_patterns',{}).get('patterns',[])) == 3)
check("categories (4)", len(lr.get('knowledge_persistence',{}).get('categories',[])) == 4)
check("rules (6)", len(lr.get('rules',[])) == 6)

print("\n9. SCRIPTS")
src = os.listdir('.opencode/src') if os.path.isdir('.opencode/src') else []
check("verify.sh", 'verify.sh' in src)
check("platform.sh", 'platform.sh' in src)

print("\n10. GENERATED OPENCODE.JSON")
check("opencode.json.generated exists", os.path.exists('opencode.json.generated'))
with open('opencode.json.generated') as f:
    gen = json.load(f)
agents_cfg = gen.get('agent', {})
mcps = gen.get('mcp', {})
perms = gen.get('permission', {})
plugins = gen.get('plugin', [])
check("15 agents configured", len(agents_cfg) == 15, f"got {len(agents_cfg)}")
check("8 MCPs", len(mcps) == 8, f"got {len(mcps)}")
check("18 permissions", len(perms) == 18, f"got {len(perms)}")
check("8 plugins", len(plugins) == 8, f"got {len(plugins)}")
has_model = any('model' in cfg for cfg in agents_cfg.values())
has_temp = any('temperature' in cfg for cfg in agents_cfg.values())
has_fallback = any('fallback_models' in cfg for cfg in agents_cfg.values())
check("model stripped", not has_model)
check("temperature stripped", not has_temp)
check("fallback_models stripped", not has_fallback)
orch = agents_cfg.get('orchestrator', {})
check("orchestrator has steps", 'steps' in orch)
check("orchestrator has skills", 'skills' in orch and len(orch['skills']) > 0)
check("orchestrator has tools", 'tools' in orch)

print("\n" + "=" * 60)
passed = sum(1 for _,p in results if p)
failed = sum(1 for _,p in results if not p)
print(f"RESULTS: {passed}/{passed+failed} passed, {failed} failed")
if failed:
    print("\nFAILED:")
    for name, p in results:
        if not p: print(f"  {name}")
else:
    print("\nALL TESTS PASSED")
print("=" * 60)
