#!/usr/bin/env python3
"""Exact two-group preflight. No spawning, installation, or model fallback."""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import tomllib

GROUPS = {
    ("gpt-5.6-sol", "high"): ("legacy", {
        "routine": ("sol_advisor_luna_implementer", "gpt-5.6-luna", "max"),
        "complex": ("sol_advisor_terra_implementer", "gpt-5.6-terra", "high"),
        "reviewer": ("sol_advisor_sol_reviewer", "gpt-5.6-sol", "high"),
    }),
    ("gpt-6.1-sol", "high"): ("current", {
        "routine": ("sol_advisor_current_routine_implementer", "gpt-6-luna", "max"),
        "complex": ("sol_advisor_current_complex_implementer", "gpt-6.1-sol", "high"),
        "reviewer": ("sol_advisor_current_reviewer", "gpt-6.1-sol", "high"),
    }),
}


def plan(model, effort, route, implementer=None, evidence="runtime"):
    if (model, effort) not in GROUPS:
        raise ValueError("unsupported primary model/effort; no fallback")
    if evidence not in ("runtime", "user-confirmation"):
        raise ValueError("primary evidence must be runtime or user-confirmation")
    if route not in ("solo", "delegate", "audit", "full"):
        raise ValueError("unknown route")
    if route in ("delegate", "full"):
        if implementer not in ("routine", "complex"):
            raise ValueError("select exactly one routine or complex implementer")
    elif implementer is not None:
        raise ValueError("this route has no implementer")
    group, roles = GROUPS[model, effort]
    selected = ([implementer] if implementer else []) + (["reviewer"] if route in ("audit", "full") else [])
    return {"group": group, "primary_model": model, "primary_effort": effort,
            "primary_evidence": evidence, "route": route,
            "roles": [{"kind": kind, "role": roles[kind][0], "model": roles[kind][1],
                       "effort": roles[kind][2]} for kind in selected]}


def confirm_primary(observed, confirmed):
    """Use effective-turn metadata, never whole-root history or model self-description."""
    result = []
    used_confirmation = False
    for field in ("model", "effort"):
        value = observed.get(field)
        assertion = confirmed.get(field)
        if value is not None and assertion is not None and value != assertion:
            raise ValueError("observed primary conflicts with confirmation")
        if value is None:
            value = assertion
            used_confirmation = True
        if not isinstance(value, str) or not value:
            raise ValueError("primary metadata unavailable; explicit confirmation required")
        result.append(value)
    if tuple(result) not in GROUPS:
        raise ValueError("unsupported effective primary")
    return *result, "user-confirmation" if used_confirmation else "runtime"


def check_unit(previous, current, in_flight):
    fields = ("thread_id", "unit_id", "primary_model", "primary_effort", "group", "config_fingerprint")
    if any(not current.get(field) for field in fields):
        raise ValueError("incomplete invocation identity")
    if previous and in_flight and any(previous.get(k) != current[k] for k in fields):
        raise ValueError("active unit changed; stop new delegation until safe boundary")
    # A new invocation never inherits discovery or successful role checks.
    return {**current, "role_checks_cached": False}


def check_discovery(selected, discovered):
    """discovered must come from the host's current native role/tool schema."""
    for expected in selected:
        matches = [r for r in discovered if r.get("role") == expected["role"]]
        if len(matches) != 1:
            raise ValueError("selected role missing or shadowed in host discovery")
        for key in ("model", "effort"):
            if matches[0].get(key) is not None and matches[0][key] != expected[key]:
                raise ValueError("discovered pin conflict")


def check_runtime(expected, record, parent_id, cwd):
    for key, wanted in (("agent_role", expected["role"]), ("model", expected["model"]),
                        ("effort", expected["effort"]), ("parent_thread_id", parent_id), ("cwd", cwd)):
        if not wanted or record.get(key) != wanted:
            raise ValueError("missing or conflicting runtime " + key)
    if not record.get("thread_id") or record["thread_id"] == parent_id:
        raise ValueError("fresh child thread required")


def check_isolation(record, hard_required=False, unchanged=False):
    sandbox = record.get("sandbox_policy_type")
    profile = record.get("permission_profile_type")
    if not sandbox or not profile:
        raise ValueError("review isolation unobservable")
    if sandbox == "read-only":
        return "enforced-read-only"
    if hard_required or not unchanged:
        raise ValueError("broader isolation requires unchanged state; hard isolation unavailable")
    return "behavioral-read-only-broader-host-policy"


def fingerprint(plugin):
    paths = [plugin / ".codex-plugin/plugin.json", plugin / "skills/orchestration/SKILL.md",
             *sorted((plugin / "skills/orchestration/references").glob("*.md")),
             *sorted((plugin / "agents").glob("*.toml")),
             plugin / "scripts/model-group.py", plugin / "scripts/install-agents.sh"]
    digest = hashlib.sha256()
    for path in paths:
        if path.is_symlink() or not path.is_file():
            raise ValueError("unsafe or missing contract source")
        digest.update(path.relative_to(plugin).as_posix().encode() + b"\0" + path.read_bytes())
    return digest.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model", required=True)
    parser.add_argument("--effort", required=True)
    parser.add_argument("--route", required=True)
    parser.add_argument("--implementer")
    parser.add_argument("--evidence", default="runtime")
    parser.add_argument("--thread-id", required=True)
    parser.add_argument("--unit-id", required=True)
    parser.add_argument("--previous-unit", type=Path)
    parser.add_argument("--in-flight", action="store_true")
    args = parser.parse_args()
    result = plan(args.model, args.effort, args.route, args.implementer, args.evidence)
    result.update(thread_id=args.thread_id, unit_id=args.unit_id,
                  config_fingerprint=fingerprint(Path(__file__).resolve().parent.parent))
    previous = json.loads(args.previous_unit.read_text()) if args.previous_unit else None
    if args.in_flight and previous is None:
        raise ValueError("active unit requires previous receipt")
    result = check_unit(previous, result, args.in_flight)
    # Validate only selected templates; solo does not require an unused role.
    for role in result["roles"]:
        filename = role["role"].replace("_", "-") + ".toml"
        data = tomllib.loads((Path(__file__).resolve().parent.parent / "agents" / filename).read_text())
        if (data.get("name"), data.get("model"), data.get("model_reasoning_effort")) != (role["role"], role["model"], role["effort"]):
            raise ValueError("selected template pin conflict")
    print(json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError) as exc:
        sys.exit("ERROR: " + str(exc))
