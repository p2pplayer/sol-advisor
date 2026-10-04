---
name: orchestration
description: "Codex-native risk-gated selective routing: default solo delivery, targeted native delegation or audit, and exceptional full review."
---

# Sol Advisor Orchestration

Act as the architect. Own the user's intent, architecture, route choice, decomposition,
implementation or delegation, parent verification, escalation decisions, and final
acceptance. Selective routing has four exact modes: `solo`, `delegate`, `audit`, and
`full`. Solo is the default. One auxiliary agent is the default maximum; full is an
explicit broad or high-risk exception.

Read [references/role-contracts.md](references/role-contracts.md) before the first
delegation. Use [references/operations.md](references/operations.md) for exact spawn,
preflight, runtime-evidence, isolation, and maintainer procedures.

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

## Declare the route before task tools

Before the first task tool call, emit one machine-auditable declaration:

~~~text
SELECTIVE ROUTE
mode: solo | delegate | audit | full
risk: <concise, task-specific rationale>
~~~

No task tool call may precede this declaration. Choose `solo` unless a stated risk
justifies another mode. A later declaration may only escalate the route when newly
observed risk justifies it; never silently downgrade. Record the evidence for an
escalation. Details and the task-scoped preflight matrix are in operations.md.

## Preflight selected auxiliaries only

Confirm the exact primary and selected group for this invocation. Preflight only an auxiliary selected by the
declared route: none for solo; routine or complex for delegate; fresh reviewer
for audit; and the selected implementer plus fresh reviewer for full. Public metadata
for role, model, and effort is authoritative. If it omits a model or effort, use the
local inspector only for that omitted field. Missing, conflicting, unavailable, or
unobservable evidence stops the affected lane; never silently substitute a role,
model, effort, or reviewer.

## Route delivery without duplication

The following Luna/Terra labels describe legacy; current substitutes its routine,
complex and reviewer roles from the mapping in operations.md, with identical duties.

- `solo`: root plans, implements, tests, and self-reviews; spawn no auxiliary.
- `delegate`: select Luna / Max for bounded, fully specified work, or Terra / High for
  judgment-heavy, high-risk, context-heavy, or wide-blast-radius work. The selected
  implementer executes the complete spec; root verifies; do not request a fresh review.
- `audit`: root implements and verifies; a fresh read-only Sol / High reviewer reviews
  the accumulated diff; spawn no implementer.
- `full`: only for an explicit broad or high-risk exception. Select one implementer,
  root verifies, then a fresh read-only Sol / High reviewer reviews.

Auxiliary work must substitute for root work, not duplicate it. A Luna result may
justify escalation to Terra / High only when it reveals newly observed complexity,
risk, wide blast radius, or misclassification. A corrected Luna attempt is reserved
for a specification error and is not a prerequisite for Terra. Any route change must
be declared and evidenced; do not silently downgrade.

## Keep architect work in the primary session

Keep these responsibilities in the primary session:

- Resolve requirements and material ambiguity.
- Choose architecture, interfaces, decomposition, and selective route.
- Write the complete five-part worker specification for any selected implementer.
- Inspect the actual diff and rerun verification.
- Decide whether newly observed risk warrants escalation.
- Judge the reviewer verdict when the route includes review and accept the deliverable.

Every worker prompt must contain OBJECTIVE, FILES AND OWNERSHIP, INTERFACES,
CONSTRAINTS, VERIFICATION, and the structured implementation return in
[the role contracts](references/role-contracts.md). State the exact owned files,
preserve concurrent edits, and never silently widen scope.

Treat worker reports as claims. Confirm the complete diff, changed-file scope, requested
checks, and artifact/runtime evidence in the parent session. Do not duplicate the
selected implementer's work in the primary session.

## Review only when the route includes it

For `audit` and `full`, after parent verification, spawn the selected group's new native Sol / High
reviewer. The reviewer must remain behaviorally read-only, inspect the actual
accumulated diff, and return exactly ship, fix-first, or rethink. A reviewer never
implements its own fixes. `solo` and `delegate` do not receive a fresh reviewer.

- ship: report completion with the verification evidence.
- fix-first applies only to `audit` and `full`:
  - audit: the root implements the required correction, re-verifies, and obtains a new
    fresh reviewer.
  - full: the selected implementer handles the required correction, the root
    re-verifies, and a new fresh reviewer reviews.
  - solo and delegate: no fresh reviewer is added unless a newly observed,
    risk-evidenced route escalation is declared; never silently add one.
- rethink: revise the architecture and do not report completion.

Any implementation correction invalidates the prior verdict. Apply the observed sandbox
and permission profile rules in the operations reference; never claim enforced
read-only isolation when it was not observed.
