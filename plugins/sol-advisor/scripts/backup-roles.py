#!/usr/bin/env python3
"""Explicit scoped backup/restore; no cross-file transaction or automatic rollback."""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import sys

FILES = {
    "legacy": ("sol-advisor-luna-implementer.toml", "sol-advisor-terra-implementer.toml", "sol-advisor-sol-reviewer.toml"),
    "current": ("sol-advisor-current-routine-implementer.toml", "sol-advisor-current-complex-implementer.toml", "sol-advisor-current-reviewer.toml"),
}


def safe_path(path):
    for item in (path, *path.parents):
        if item.is_symlink() or (hasattr(item, "is_junction") and item.is_junction()):
            raise ValueError("symlink or junction path refused")
    if path.exists() and not (path.is_file() or path.is_dir()):
        raise ValueError("nonregular path refused")


def contents(path):
    safe_path(path)
    if not path.exists():
        return None
    if not path.is_file():
        raise ValueError("role must be a regular file")
    return path.read_bytes()


def digest(data):
    return hashlib.sha256(data).hexdigest() if data is not None else None


def snapshot(target, backup, group):
    safe_path(target); safe_path(backup)
    if backup.exists():
        raise ValueError("backup directory already exists")
    names = FILES["legacy"] + FILES["current"] if group == "all" else FILES[group]
    templates = Path(__file__).resolve().parent.parent / "agents"
    records = {}
    for name in names:
        before = contents(target / name)
        after = contents(templates / name)
        if after is None:
            raise ValueError("candidate template missing")
        records[name] = {"before": base64.b64encode(before).decode() if before is not None else None,
                         "before_sha256": digest(before), "candidate_sha256": digest(after)}
    backup.mkdir(parents=True)
    with (backup / "roles.json").open("x", encoding="utf-8") as output:
        json.dump({"schema": 1, "target": str(target), "group": group, "files": records}, output, indent=2)


def restore(target, backup):
    safe_path(target); safe_path(backup)
    data = json.loads(contents(backup / "roles.json"))
    if data.get("schema") != 1 or data.get("target") != str(target):
        raise ValueError("backup target/schema mismatch")
    group = data["group"]
    names = FILES["legacy"] + FILES["current"] if group == "all" else FILES[group]
    if set(data["files"]) != set(names):
        raise ValueError("backup inventory mismatch")
    actions = []
    templates = Path(__file__).resolve().parent.parent / "agents"
    for name in names:
        record = data["files"][name]
        before = base64.b64decode(record["before"], validate=True) if record["before"] is not None else None
        if digest(before) != record["before_sha256"] or digest(contents(templates / name)) != record["candidate_sha256"]:
            raise ValueError("backup integrity/candidate mismatch")
        observed = contents(target / name)
        if observed == before:
            continue
        if digest(observed) != record["candidate_sha256"]:
            raise ValueError("concurrent modification; no files restored")
        actions.append((target / name, observed, before))
    for path, expected, before in actions:
        if contents(path) != expected:
            raise ValueError("destination changed; earlier restores may exist")
        if before is None:
            path.unlink()
        else:
            # Exact preflight/recheck, then replace this file only; no transaction claim.
            staged = path.with_name(path.name + ".sol-advisor-restore")
            with staged.open("xb") as output:
                output.write(before)
            try:
                if contents(path) != expected:
                    raise ValueError("destination changed; earlier restores may exist")
                os.replace(staged, path)
            finally:
                staged.unlink(missing_ok=True)
        if contents(path) != before:
            raise ValueError("post-restore mismatch; earlier restores may exist")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("snapshot", "restore"))
    parser.add_argument("--target-dir", required=True, type=Path)
    parser.add_argument("--backup-dir", required=True, type=Path)
    parser.add_argument("--group", choices=("legacy", "current", "all"), default="all")
    args = parser.parse_args()
    target, backup = args.target_dir.absolute(), args.backup_dir.absolute()
    if target == backup or target in backup.parents or backup in target.parents:
        raise ValueError("backup and target must be separate directories")
    if args.action == "snapshot":
        snapshot(target, backup, args.group)
    else:
        restore(target, backup)
    print(args.action.upper() + " PASSED (scoped roles only)")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, KeyError, TypeError) as exc:
        sys.exit("ERROR (earlier writes, if any, are not rolled back): " + str(exc))
