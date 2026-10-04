# Native operations

This is the maintainer and operator reference for Sol Advisor's native custom-agent
workflow. Keep the README user-facing; use this page when installing, delegating,
inspecting routing, or validating a release.

## Exact model groups and invocation boundary

There is one plugin `sol-advisor`, one skill `orchestration`, and exactly two groups.
The user selects the primary session in the client; never change global defaults.

| Effective primary / effort | Group | Routine / effort | Complex / effort | Reviewer / effort |
|---|---|---|---|---|
| gpt-5.6-sol / high | legacy | gpt-5.6-luna / max | gpt-5.6-terra / high | gpt-5.6-sol / high |
| gpt-6.1-sol / high | current | gpt-6-luna / max | gpt-6.1-sol / high | gpt-6.1-sol / high |

Reject every other entry, including gpt-6-sol, Astra variants, unknown models, and
non-high primary efforts. Never infer a group from prefixes, model self-description,
the global default, or old turns. Use effective current-turn metadata. If fields are
unavailable, obtain explicit user confirmation for those fields, record evidence as
user-confirmation, and stop until supplied; available conflicting metadata cannot
be overridden by confirmation. Use `confirm_primary` in `scripts/model-group.py`
for this comparison; its CLI arguments must come from that evidence, not guesses.

Every new explicit invocation in the same root task rereads the effective skill,
required references, source/version and current native role/tool schema. Discard
earlier group choices and role checks. Track root ID, new invocation unit ID,
primary model/effort and configuration fingerprint. A successful check is valid only
inside this unchanged unit; before each new spawn verify them again. If any changes
while an implementer/reviewer is unfinished, stop new delegation until a safe boundary;
do not reconfigure running children or mix group results. Preserve task history,
workspace, branch, uncommitted work, project constraints and completed progress.

The route declaration still precedes the first task tool, including preflight tools.
After primary confirmation, emit a short `MODEL GROUP: <group>; primary:
<model>/<effort>; evidence: runtime|user-confirmation; unit: <id>` receipt. Group
selection never spawns agents or expands the declared route. Select/check only the
roles required by that route. No cross-group fallback, per-spawn pin override,
extra entry point, nested Codex, independent App task mechanism, API substitute,
automatic model upgrade, Pro/Fast/Ultrafast or paid provider channel is introduced.

Routine, complex and reviewer below mean the selected group's separate native roles.
The Luna/Terra/Sol examples below are explicitly legacy examples; they do not
authorize legacy role calls in current. Current uses the same shared five-part
implementation packet, fresh read-only review packet, correction ownership,
escalation rules and observed isolation requirements. Current complex and current
reviewer share a model, but have distinct instructions, roles and fresh threads.

## Current group role mapping (same four routes)

| Kind | Exact role | Model / effort | Selective check with `--group current` |
|---|---|---|---|
| routine | sol_advisor_current_routine_implementer | gpt-6-luna / max | `--check-role routine` |
| complex | sol_advisor_current_complex_implementer | gpt-6.1-sol / high | `--check-role complex` |
| reviewer | sol_advisor_current_reviewer | gpt-6.1-sol / high | `--check-role reviewer` |

Use exactly these native spawn contracts, only when selected by the route:

~~~text
agent_type: sol_advisor_current_routine_implementer
fork_turns: none
~~~

~~~text
agent_type: sol_advisor_current_complex_implementer
fork_turns: none
~~~

~~~text
agent_type: sol_advisor_current_reviewer
fork_turns: none
~~~

`solo` checks/spawns none. `delegate` selects one routine/complex role and no
reviewer; `audit` selects only reviewer; `full` selects one implementer and reviewer.
Complex can be selected up front, or after newly observed risk from a routine result;
one specification-correction retry is never an escalation prerequisite. In audit,
root fixes; in full, the selected implementer fixes. A reviewer never fixes. Any fix
invalidates the verdict and requires parent verification plus a new fresh review.

## Legacy role pins and spawn contract

The installed TOMLs are the source of truth:

| Role type | Model | Effort | Use |
|---|---|---|---|
| sol_advisor_luna_implementer | gpt-5.6-luna | max | Delegate/full bounded routine implementation |
| sol_advisor_terra_implementer | gpt-5.6-terra | high | Delegate/full judgment-heavy or high-risk implementation |
| sol_advisor_sol_reviewer | gpt-5.6-sol | high | Audit/full fresh review; requests read-only sandbox |

Native spawn requests name the role and use a fresh context:

~~~text
agent_type: sol_advisor_luna_implementer
fork_turns: none
~~~

Use the Terra type only when the selected delegate or full route needs it:

~~~text
agent_type: sol_advisor_terra_implementer
fork_turns: none
~~~

Use a fresh Sol reviewer only for audit or full after parent verification:

~~~text
agent_type: sol_advisor_sol_reviewer
fork_turns: none
~~~

Do not attach model or reasoning overrides. A missing, conflicting, unavailable, or
unobservable role/model/effort is a hard stop; never substitute another role.

## Selective route declaration, preflight, and caching

The primary session must be Sol / High. Companion installation is separate from task
routing because plugin installation does not register user-owned TOMLs.

At installation or update time, run the repository-relative installer and its exactness
check:

~~~sh
sh plugins/sol-advisor/scripts/install-agents.sh
sh plugins/sol-advisor/scripts/install-agents.sh --check
~~~

When operating from an installed skill, resolve the same script relative to this
reference's parent skill:

~~~sh
skill_dir=<directory-containing-this-SKILL.md>
installer="$skill_dir/../../scripts/install-agents.sh"
sh "$installer" --check
~~~

The installer is fail-closed and performs its own post-install exactness check. It
recognizes only byte-exact historical templates, including the shipped v0.2.0 profiles
and the v0.5.0 Luna/Terra profiles during a v0.5.1 update. Modified/unsafe/nonregular/
symlinked/conflicting destinations remain refusals, and all mutations are preflighted.

The root emits one machine-auditable declaration before its first task tool call:

~~~text
SELECTIVE ROUTE
mode: solo | delegate | audit | full
risk: <concise, task-specific rationale>
~~~

Solo is the default. One auxiliary is the default maximum; full is an explicit broad
or high-risk exception. The root may emit a later declaration only to escalate when
newly observed risk justifies it. It records that evidence and never silently
downgrades.

The existing --check flag verifies all three roles. For task-scoped preflight, check
only the auxiliaries selected by the declaration; every check is non-mutating and
fail-closed:

| Route | Required companion checks |
|---|---|
| solo | None |
| delegate (Luna) | `--check --check-role luna` |
| delegate (Terra) | `--check --check-role terra` |
| audit | `--check --check-role sol` |
| full (Luna) | `--check --check-role luna --check-role sol` |
| full (Terra) | `--check --check-role terra --check-role sol` |

For example:

~~~sh
sh plugins/sol-advisor/scripts/install-agents.sh --check --check-role luna
sh plugins/sol-advisor/scripts/install-agents.sh --check --check-role sol
~~~

Unknown or missing role arguments fail before any destination mutation. A selective
check ignores unselected role destinations, while the all-role --check behavior
remains unchanged. Cache successful checks only for the current unchanged invocation unit; never carry
them across a later invocation, installation/update, or routing/configuration change.

Luna / Max is for bounded, fully specified work. Terra / High is selected for
judgment-heavy, high-risk, context-heavy, or wide-blast-radius work. A Luna result
may justify a declared Terra escalation only when it shows newly observed risk. One
corrected Luna attempt is reserved for a specification error and is not a prerequisite
for Terra.

If public metadata omits model or effort, use the local inspector below as a fallback
for those omitted fields only. Do not use it to replace available public evidence.

## Runtime routing evidence

The public spawn/details record is authoritative for the selected role and any exposed
model/effort. When model or effort is omitted, resolve the helper relative to the
installed skill and inspect the exact native thread ID:

~~~sh
skill_dir=<directory-containing-this-SKILL.md>
runtime_inspector="$skill_dir/../../scripts/inspect-agent-runtime.sh"
sh "$runtime_inspector" <native-subagent-thread-id>
~~~

For a disposable fixture or non-default session root:

~~~sh
sh "$runtime_inspector" --sessions-dir /absolute/path/to/sessions <native-subagent-thread-id>
~~~

The helper searches one exact rollout filename suffix and emits only allowlisted
routing fields. It refuses invalid IDs, zero/multiple matches, missing fields, or
conflicting model/effort/sandbox/permission/working-directory values. It never prints
prompts, messages, environment variables, tokens, configuration, or arbitrary rollout
payloads.

Legacy accepted routing is Luna / max for bounded delegate/full implementation, Terra / high
for higher-risk delegate/full implementation, and Sol / high for audit/full review.
If public and local evidence both exist, they must agree. The local inspector is not a
model-selection fallback.

## Read-only reviewer interpretation

The reviewer TOML requests sandbox_mode = read-only. Capture the observed sandbox
policy type and permission profile type from public metadata or the inspector:

- Observed read-only sandbox: isolation is enforced.
- Broader host policy: continue only when hard isolation is not required, the prompt
  forbids edits, and the parent captures exact before/after repository and artifact
  state. Report the broader policy and profile as residual risk.
- Unobservable isolation, required hard isolation, or any mutation: stop the review and
  do not claim read-only isolation.

A reviewer returns exactly ship, fix-first, or rethink. A fix invalidates the prior
verdict; parent verification and a new fresh review are required.

## Worker packet and parent acceptance

Every Luna or Terra prompt uses the five-part packet in role-contracts.md:

- OBJECTIVE
- FILES AND OWNERSHIP
- INTERFACES
- CONSTRAINTS
- VERIFICATION

It must also request the structured implementation report. The parent owns architecture,
complete diff inspection, verification reruns, correction/escalation decisions, and
acceptance. Worker claims never replace direct inspection.

In solo, the root plans, implements, tests, and self-reviews with no auxiliary. In
delegate, one selected Luna or Terra implementer completes the spec and the root
verifies with no fresh reviewer. In audit, the root implements and verifies, then a
fresh Sol reviewer reviews. In full, one selected implementer completes the spec, the
root verifies, and a fresh Sol reviewer reviews. Auxiliary work substitutes for root
work; it does not duplicate it. A reviewer never fixes its own findings.

## Maintainer verification

From the repository root, run:

~~~sh
sh plugins/sol-advisor/scripts/verify.sh
git diff --check
git status --short
git diff --stat
~~~

The verifier covers the candidate manifest, exact six-role TOMLs, selective-routing
contracts, concise README journey, absence of retired workflow references, installer
safety fixtures, both groups' runtime fixtures, JSON/TOML validity, shell syntax,
active-unit boundaries, discovery/pin refusals and scoped backup/restore.

## Group checks, receipts, sources and same-root acceptance

Old commands without `--group` retain legacy install/check semantics and historical
migration. `--group current` touches/checks only current; `--group all` installs or
checks all six. Exact native names may replace shorthand check names. Unknown groups,
unknown/cross-group role names, and missing arguments refuse before writing.
Unselected role destinations/templates do not block a selective check.

~~~sh
# Explicit paths; these examples are not authorization to deploy.
sh plugins/sol-advisor/scripts/install-agents.sh --target-dir /isolated/agents --group all
sh plugins/sol-advisor/scripts/install-agents.sh --target-dir /isolated/agents --group current --check-role routine
sh plugins/sol-advisor/scripts/install-agents.sh --target-dir /isolated/agents --group current --check-role complex --check-role reviewer
python3 plugins/sol-advisor/scripts/model-group.py --model gpt-6.1-sol --effort high --route full --implementer complex --thread-id <existing-root-id> --unit-id <new-unit-id>
~~~

Plan receipts select pins; they do not prove host registration or actual execution.
Feed actual effective primary evidence to the helper, retain the receipt only for
this unit, and revalidate against `--previous-unit <receipt.json> --in-flight` before
new delegation inside an unfinished unit. Do not store receipts in conversation logs
or replace user history. `check_discovery` checks only selected roles against actual
host discovery; duplicate/shadowed or missing entries refuse. Installed TOMLs alone
are not discovery evidence. `check_runtime` compares the exact role/model/effort,
child ID, parent ID and working directory. Use allowlisted public metadata first and
the unchanged inspector for omitted child fields only. Never run the child lifetime
inspector over a root history that legitimately contains previous models.

Before deployment, inspect `codex --version`, `codex plugin list --json`, marketplace
source/version, duplicate local/project skills and same-name agent overrides. Require
one effective sol-advisor source. Do not delete unknown configuration or edit caches.
Use `backup-roles.py snapshot --target-dir <agents> --backup-dir <new-backup>` before
an authorized install. Restore with the same helper's `restore` command. It restores
only recorded relevant items, refusing changed or unsafe destinations and altered
backups. Installation/restore preflight is not a cross-file transaction: preserve
reported earlier writes on failure and inspect them, never claim automatic rollback.

Same-root acceptance requires three separate observed proofs: (1) exact disk source,
version and role bytes, (2) the already-existing root reads the current contract and
discovers selected native roles, (3) actual child execution from that root with exact
pins/parent relationship and observed permission profile. Skill auto-discovery does
not prove agent hot reload. Do not invent reload commands or override higher-priority
stale host instructions. Do not start/fork a new root, alter databases, restart other
clients, or run nested resume. If user-mediated reload/resume is supported, preserve
the same session ID and history and record interruption honestly. Report:

- DIRECT_PASS: all three proofs from the unchanged existing root without restart.
- RESUMED_PASS: all three after actual host reload/resume of the same root ID.
- NEEDS_USER_ACTION / NOT_VERIFIED: missing isolation, metadata, discovery or execution.
- BLOCKED_REQUIRES_NEW_ROOT: evidence that only a new root works; do not create one.

An isolated test's PASS never certifies a business thread. Before business install,
require external approval, safe handoff with no active old children/state writers,
recorded task/Git/progress state, and explicit installation authorization. Then the
user selects 6.1 Sol/High in that same task and invokes the canonical skill again.
This candidate is not authorization to install or cut over a running business task.

Official references (checked 2026-10-04):
- https://learn.chatgpt.com/docs/build-skills (skill discovery; restart caveat)
- https://learn.chatgpt.com/docs/agent-configuration/subagents (custom pins/inheritance)
- https://learn.chatgpt.com/docs/developer-commands?surface=cli (installed sources/session commands)
