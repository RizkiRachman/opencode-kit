#!/usr/bin/env python3
"""postflight helper — batch all contract/telemetry/STATE.md operations in one call.

Replaces 11 separate inline Python invocations from postflight.sh with a single
script that handles: contract read/migration, phase telemetry, summary update,
STATE.md generation, and contract file persistence.

Usage:
    postflight.py CONTRACT_FILE TELEMETRY_DIR STATE_FILE STATE_BACKUP_DIR TEMPLATE_FILE [NEW_STATE]

Returns JSON to stdout with extracted values for shell-level echo/log messages.
"""
import json
import os
import sys
import datetime


def main() -> int:
    # --- Parse arguments ---
    contract_file = sys.argv[1] if len(sys.argv) > 1 else '.opencode/orchestration/contract.json'
    telemetry_dir = sys.argv[2] if len(sys.argv) > 2 else '.opencode/telemetry'
    state_file = sys.argv[3] if len(sys.argv) > 3 else 'STATE.md'
    state_backup_dir = sys.argv[4] if len(sys.argv) > 4 else '.opencode/state'
    template_file = sys.argv[5] if len(sys.argv) > 5 else '.opencode/templates/contract.json'
    new_state = sys.argv[6] if len(sys.argv) > 6 else None

    start_time_file = os.path.join(telemetry_dir, '.phase_start')
    phases_file = os.path.join(telemetry_dir, 'phases.jsonl')
    summary_file = os.path.join(telemetry_dir, 'summary.json')

    now = datetime.datetime.now(datetime.UTC)
    now_iso = now.strftime('%Y-%m-%dT%H:%M:%SZ')

    # --- Load contract (file or template fallback) ---
    contract = {}
    if os.path.exists(contract_file):
        with open(contract_file) as f:
            contract = json.load(f)
    elif os.path.exists(template_file):
        with open(template_file) as f:
            contract = json.load(f)

    prev_state = contract.get('state', 'INIT')

    # --- Update state if provided ---
    if new_state:
        contract['state'] = new_state

    current_state = contract.get('state', 'UNKNOWN')

    # --- Read start time and calculate phase elapsed ---
    os.makedirs(telemetry_dir, exist_ok=True)
    phase_elapsed_ms = 0
    if os.path.exists(start_time_file):
        with open(start_time_file) as f:
            raw = f.read().strip()
        if raw:
            try:
                start_ts = int(raw)
                phase_elapsed_ms = int((now.timestamp() - start_ts) * 1000)
            except ValueError:
                pass
        os.remove(start_time_file)

    # --- Read last 'to' state from phases.jsonl for telemetry ---
    last_to_state = 'INIT'
    if os.path.exists(phases_file):
        lines = [l.strip() for l in open(phases_file) if l.strip()]
        if lines:
            try:
                last_to_state = json.loads(lines[-1]).get('to', 'INIT')
            except json.JSONDecodeError:
                pass

    # --- Record phase telemetry ---
    phase_entry = {
        'ts': now_iso,
        'from': last_to_state,
        'to': current_state,
        'elapsed_ms': phase_elapsed_ms,
    }
    with open(phases_file, 'a') as f:
        f.write(json.dumps(phase_entry) + '\n')

    # --- Contract migration (merge missing fields from template) ---
    migrated = False
    if os.path.exists(template_file):
        with open(template_file) as f:
            template = json.load(f)

        old_ver = contract.get('contract_version', '0.0.0')
        new_ver = template.get('contract_version', '0.5.2')

        needs_migration = (
            old_ver != new_ver
            or not all(k in contract for k in ['state', 'requirements', 'governance', 'score'])
        )

        if needs_migration:
            for key in template:
                if key not in contract:
                    contract[key] = template[key]
            if 'extension_skills' not in contract.get('governance', {}):
                contract.setdefault('governance', {})['extension_skills'] = []
            contract['contract_version'] = new_ver
            migrated = True

    # --- Write contract to primary location ---
    os.makedirs(os.path.dirname(contract_file) or '.', exist_ok=True)
    with open(contract_file, 'w') as f:
        json.dump(contract, f, indent=2)

    # --- Backup contract to state backup dir ---
    os.makedirs(state_backup_dir, exist_ok=True)
    with open(os.path.join(state_backup_dir, 'contract.json'), 'w') as f:
        json.dump(contract, f, indent=2)

    # --- Update telemetry summary.json ---
    total_ms = 0
    phases = []
    if os.path.exists(phases_file):
        with open(phases_file) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    total_ms += entry.get('elapsed_ms', 0)
                    phases.append(entry.get('to', ''))
                except json.JSONDecodeError:
                    pass

    summary = {
        'phases_completed': phases,
        'total_elapsed_ms': total_ms,
        'total_elapsed_s': round(total_ms / 1000, 1),
        'updated_at': now_iso,
    }
    with open(summary_file, 'w') as f:
        json.dump(summary, f, indent=2)

    # --- Extract values for STATE.md ---
    retry = contract.get('retry', {})
    score_obj = contract.get('score', {})
    state_val = contract.get('state', 'UNKNOWN')
    phase_val = retry.get('current_phase', 'none')
    score_combined = str(score_obj.get('combined', '?'))

    # Issues / blockers
    issues = retry.get('issues', [])
    issues_blockers = '\n'.join(f'- {i}' for i in issues) if issues else 'None'

    # ADRs (last 3)
    adr_log = contract.get('decisions', {}).get('adr_log', [])
    if adr_log:
        adr_lines = '\n'.join(
            f'- {e.get("id", "?")}: {e.get("title", "")}' for e in adr_log[-3:]
        )
    else:
        adr_lines = 'No ADRs recorded'

    # Last completed phase
    metrics_phases = contract.get('metrics', {}).get('phases_completed', [])
    last_phase = metrics_phases[-1] if metrics_phases else 'INIT'

    # --- Write STATE.md ---
    state_md = (
        '# Project State\n'
        '\n'
        '## Current Focus\n'
        f'Agent orchestration — {state_val} (phase: {phase_val}). Score: {score_combined}.\n'
        '\n'
        '## Known Blockers\n'
        f'{issues_blockers}\n'
        '\n'
        '## Active Decisions\n'
        f'{adr_lines}\n'
        '\n'
        '## Recent Changes\n'
        f'- Last state transition: {last_phase}\n'
    )
    state_dir = os.path.dirname(state_file)
    if state_dir:
        os.makedirs(state_dir, exist_ok=True)
    with open(state_file, 'w') as f:
        f.write(state_md)

    # --- Output JSON summary for shell script consumption ---
    output = {
        'state': state_val,
        'phase': phase_val,
        'score': score_combined,
        'prev_state': prev_state,
        'current_state': current_state,
        'phase_elapsed_ms': phase_elapsed_ms,
        'phase_elapsed_s': round(phase_elapsed_ms / 1000, 1),
        'migrated': migrated,
        'contract_version': contract.get('contract_version', '?'),
        'phases_count': len(phases),
        'total_elapsed_s': summary['total_elapsed_s'],
        'issues_count': len(issues),
        'last_to_state': last_to_state,
    }
    print(json.dumps(output))
    return 0


if __name__ == '__main__':
    sys.exit(main())
