# Sol Advisor v0.7.0-rc.2 — GPT-6.1 compatibility preview

Community fork maintained by [p2pplayer](https://github.com/p2pplayer/sol-advisor),
based on [Daniel McAteer's upstream Sol Advisor](https://github.com/DannyMac180/sol-advisor).
The original attribution and [MIT license](../LICENSE) are preserved. This is a
community preview, not an OpenAI-official listing or an upstream release.
The version remains **0.7.0-rc.2**, not stable 0.7.0.

## Frozen runtime and public version

Reviewed runtime baseline: `95f77ab0e4b14e3f5f6ca5a554eeb1cfe648e618`, tree
`249572ab540c8e6c856b6fe88fc4c143b27c8ad8`. The public
[`v0.7.0-rc.2`](https://github.com/p2pplayer/sol-advisor/tree/v0.7.0-rc.2) tag
can point to its documentation-only descendant; the release receipt records the
final commit separately. The entire plugin subtree, marketplace catalog and all
other non-documentation tracked files are byte-identical to the reviewed baseline.

| Primary / effort | Group | Routine / effort | Complex / effort | Independent reviewer / effort |
|---|---|---|---|---|
| `gpt-5.6-sol/high` | legacy | `gpt-5.6-luna/max` | `gpt-5.6-terra/high` | `gpt-5.6-sol/high` |
| `gpt-6.1-sol/high` | current | `gpt-6-luna/max` | `gpt-6.1-sol/high` | `gpt-6.1-sol/high` |

The compatibility work adds current beside legacy. Both use `$sol-advisor:orchestration`.
Default solo and all four routes remain unchanged. Complex and reviewer share a
model but use distinct roles and fresh contexts. No GPT-6 Sol entry, Astra request,
automatic model upgrade, cross-group fallback, pricing service or alternative
execution mechanism is added. Incomplete active-unit receipts and installation
preflight/query/backup failures refuse rather than continuing.

## Installation requirements

Tested host: **Windows**, Codex CLI **0.160.0**, desktop **26.930.3930.0**.
Use native custom agents, Git, Bash/Git Bash, jq and Python 3.11+ (`python3` on PATH).
Access to exact role models is needed only when a selected route calls them.
Linux, macOS and other client/account combinations have no live acceptance evidence
for this preview. Run commands in the intended desktop user's account/state root.
On Windows, USERPROFILE/HOME alone do not establish Windows identity; a sandbox
account can report an empty list while the desktop user's plugin exists. Do not
copy credentials or impersonate accounts to bypass this distinction.

New users: follow the guarded [README quick start](../README.md#quick-start-new-installations).
Pin **p2pplayer/sol-advisor --ref v0.7.0-rc.2**, not a mutable candidate branch.
Do not install into shared environments while dependent tasks or old children are active.

After installation, perform a separate non-mutating check in Bash:

```bash
set -euo pipefail
plugin_dir="$(codex plugin list --json | jq -er '[.installed[] | select(.pluginId == "sol-advisor@sol-advisor" and .version == "0.7.0-rc.2" and .enabled == true)] | if length == 1 then .[0].source.path else error("expected one enabled rc.2") end')"
test -n "$plugin_dir"
test "$plugin_dir" != null
test -d "$plugin_dir"
test -f "$plugin_dir/scripts/install-agents.sh"
sh "$plugin_dir/scripts/install-agents.sh" --group all --check
codex plugin marketplace list
```

Confirm one enabled rc.2 plugin, marketplace **p2pplayer/sol-advisor** at the fixed
tag, and all six roles matching frozen templates. The manifest retains upstream
author/homepage attribution; those fields are not installation-source evidence.
Marketplace snapshots and effective skill cache paths can differ. Inspect the
actual task's skill catalog and native role schema, not only the source.path field.
Plugin installation alone does not register user-owned agent TOMLs. The existing
companion installer installs both groups and performs its own byte-exact post-check.
It does not change global models, permissions, account or other plugins.
An explicit file check does not prove role discovery or actual model execution.

## Existing installations

Same-name upstream, fork and local sources need controlled migration. A generic
upstream marketplace upgrade does not switch to this fork. Before removing anything:

1. Reach a safe boundary for every task sharing plugin/roles. Finish old children
   and writers; preserve original tasks, Git state and progress. Unknown activity stops migration.
2. In the correct account, query `codex plugin list --json` and
   `codex plugin marketplace list`. Record source/ref, version and enabled state
   privately. Resolve duplicates and relevant project overrides; do not delete unknown files.
3. Obtain the fixed tag in a separate directory that is not an active installed
   source. Back up user configuration, plugin registration, original source/cache
   and relevant roles in a new private location; verify original and backup hashes.
   Never publish credentials, configuration or backups.
4. Use the shipped `scripts/backup-roles.py snapshot --target-dir <actual-agents-dir>
   --backup-dir <new-private-role-backup>` from the fixed plugin source for the six
   roles. It rejects unsafe paths. Config/registration backups are separate responsibilities.
5. Inspect real target paths for symlinks, nonregular files and custom edits.
   Preflight the six original role copies in a private temporary target using the
   unchanged `install-agents.sh --target-dir <temporary-role-copies> --group all`,
   then its `--check`. Copy testing never authorizes overwriting an unsafe real path.
   Accept only missing roles, exact current templates or exact historical templates
   recognized by the installer; recheck original fingerprints before actual writes.
6. Unknown byte differences, including unrecognized line-ending changes, stop the
   migration. Preserve and resolve files individually. No force, blanket normalization,
   TOML reserialization or relaxed semantic comparison. Unmanaged aliases stay intact;
   their names do not prove model pins.
7. Only after source, backups, preflight and concurrency checks pass, use the
   [README replacement example](../README.md#existing-upstream-installs-and-updates).
   It replaces only the identified same-name registration with this fork's fixed
   tag, then uses the unchanged six-role installer.
8. Every command/query/backup failure stops deployment. Multiple commands are not
   atomic: preserve completed writes and partial state; do not assume automatic rollback.
9. Perform post-install checks and original-task discovery. Restoration requires
   checking current fingerprints and concurrent work; never blindly overwrite full
   config. The unchanged `backup-roles.py restore` restores only recorded relevant
   roles and refuses changed/unsafe targets. Restore original marketplace registration
   only from the previously verified source/ref.

## Existing task discovery

Select the exact primary/high effort and invoke the same skill again in the same
existing task. Reread current contracts, current-turn evidence, source/version and
native role schema, with a fresh unit. Reading a TOML or skill alone is not discovery.
If an exact role is missing, conflicting or unobservable, stop that native lane.
Do not substitute aliases, override pins, use another provider/API, nest Codex,
alter session databases or create replacement roots as a shortcut.
At a safe boundary, normal client exit/reopen into the same task may be needed;
the tested host required this. Neither hot loading nor successful refresh on every
client is guaranteed. Record the interruption and verify original root identity,
actual role/model/effort, child-parent relationship and working directory.
See [advanced native operations](../plugins/sol-advisor/skills/orchestration/references/operations.md).

## Validation scope

Windows acceptance ran all three current native roles from the original development
root after normal client exit/reopen. Routine GPT-6 Luna/max passed 7 parent-rerun
fixture tests; complex GPT-6.1 Sol/high passed 13. A separate fresh GPT-6.1 Sol/high
reviewer returned `ship`. Exact child role/model/effort, original parent and actual
cwd were confirmed through allowlisted metadata, not model self-description.
Source/roles/config/review-input/fixture bytes were compared before and after.
Original-root continuity was **RESUMED_PASS**, not uninterrupted hot loading.

Reviewer requested read-only; actual host policy was **workspace-write / managed**.
Acceptance proves **behaviorally read-only** review with no-edit constraints and
unchanged before/after hashes, not enforced filesystem read-only isolation.
Broader host permissions remain a residual risk.

Legacy configuration, discovery and both groups' offline regression passed; a full
legacy live rerun was not performed. Separate business-task continuity, other
platforms, all account/client combinations and comprehensive project E2E remain unverified.
One process deviation was recorded: initial attachment/skill reads preceded the
route declaration, which still preceded preflight and native calls. No claim of
100% procedural compliance, universal E2E, performance superiority or percentage
cost savings is made. Only this anonymous summary is public: no raw acceptance
ZIPs, task UUIDs, user paths, business details, session history or private config.

## Sources and attribution

- [Original project](https://github.com/DannyMac180/sol-advisor) and [MIT license](../LICENSE).
- Daniel McAteer's [Attention Heads](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor)
  and [newsletter subscription](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor).
- [Official marketplace/Git sources](https://developers.openai.com/plugins/build/plugins):
  Git-ref pinning and source/cache distinction. Examples were checked against CLI
  0.160.0 help; documentation alone does not certify this fork.
- [GitHub release mechanics](https://docs.github.com/en/rest/releases/releases).
