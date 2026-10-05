# Sol Advisor — GPT-6.1 compatibility preview

**GPT-6.1 compatibility community fork / public preview: `0.7.0-rc.2`.**
Maintained by [p2pplayer](https://github.com/p2pplayer); based on
[Daniel McAteer's original Sol Advisor](https://github.com/DannyMac180/sol-advisor).
[MIT licensed](LICENSE). This community release is not an OpenAI-official release.

**Sol / High runs the show.** It owns architecture, delivery and verification,
declares a risk-gated route, and keeps solo as the default.

## Two exact model groups, one entry

| Primary / effort | Group | Routine / effort | Complex / effort | Fresh reviewer / effort |
|---|---|---|---|---|
| `gpt-5.6-sol/high` | legacy | `gpt-5.6-luna/max` | `gpt-5.6-terra/high` | `gpt-5.6-sol/high` |
| `gpt-6.1-sol/high` | current | `gpt-6-luna/max` | `gpt-6.1-sol/high` | `gpt-6.1-sol/high` |

Both use `$sol-advisor:orchestration`. Complex and reviewer are separate roles and
fresh contexts. Other primaries refuse, including GPT-6 Sol and Astra; no automatic
model upgrade, cross-group fallback, or new execution mechanism is introduced.

## Quick start: new installations

Use Codex native custom agents, Git, Bash (Git Bash on Windows), jq, and Python
3.11+ available as `python3`. Legacy Luna / Max or Terra / High access is needed only when
delegating; current uses GPT-6 Luna/max or the separate GPT-6.1 Sol/high roles.
Run under the intended desktop user's account, at a safe boundary for all shared tasks.
If a same-name marketplace/plugin already exists, follow migration below first.

~~~bash
set -euo pipefail
codex plugin marketplace add p2pplayer/sol-advisor --ref v0.7.0-rc.2
codex plugin add sol-advisor@sol-advisor
plugin_dir="$(codex plugin list --json | jq -er '[.installed[] | select(.pluginId == "sol-advisor@sol-advisor" and .version == "0.7.0-rc.2" and .enabled == true)] | if length == 1 then .[0].source.path else error("expected one enabled rc.2") end')" && test -n "$plugin_dir" && test "$plugin_dir" != null && test -d "$plugin_dir" && test -f "$plugin_dir/scripts/install-agents.sh" && sh "$plugin_dir/scripts/install-agents.sh" --group all || exit 1
~~~

The companion installer installs and verifies all six exact role files; it leaves
modified, unsafe, nonregular, symlinked or conflicting destinations untouched.
For the separate post-install verification command and source checks, see the
[public release and installation notes](docs/RELEASE_v0.7.0-rc.2.md).

Select the exact primary and effort in your existing task, then use:

~~~text
Use $sol-advisor:orchestration to build this feature and verify it. Declare the selective route before task tools.
~~~

## What you do

Give Sol the outcome, constraints and repository context. You do not need to select or manage a lane;
Sol records the route and owns verification and acceptance.

## Routes

| Mode | Use it when | Delivery |
|---|---|---|
| `solo` | Default; risk is contained. | Root implements, tests and self-reviews. |
| `delegate` | A complete spec benefits from one implementer. | Selected group's routine or complex role; root verifies. |
| `audit` | Independent final scrutiny matters. | Root implements; a fresh read-only reviewer reviews. |
| `full` | Explicit broad or high-risk exception. | One implementer, root verification and fresh review. |

Solo is the default. One auxiliary is the default maximum; full is exceptional.
Sol emits `SELECTIVE ROUTE` before the first task tool call; escalation requires
newly observed risk, and it never silently downgrades. Auxiliary work substitutes
for root work. The root checks the actual diff and reruns tests; reviewer verdicts
are ship, fix-first or rethink. Any implementation fix requires a fresh review.

## Existing upstream installs and updates

Read the [migration checklist](docs/RELEASE_v0.7.0-rc.2.md#existing-installations)
first: verify source and account, back up, preflight role conflicts, and pause shared
work safely. A generic marketplace upgrade does not switch an upstream source to this fork.
Only after those checks, replace the identified same-name registration:

~~~bash
set -euo pipefail
codex plugin remove sol-advisor@sol-advisor
codex plugin marketplace remove sol-advisor
codex plugin marketplace add p2pplayer/sol-advisor --ref v0.7.0-rc.2
codex plugin add sol-advisor@sol-advisor
plugin_dir="$(codex plugin list --json | jq -er '[.installed[] | select(.pluginId == "sol-advisor@sol-advisor" and .version == "0.7.0-rc.2" and .enabled == true)] | if length == 1 then .[0].source.path else error("expected one enabled rc.2") end')" && test -n "$plugin_dir" && test "$plugin_dir" != null && test -d "$plugin_dir" && test -f "$plugin_dir/scripts/install-agents.sh" && sh "$plugin_dir/scripts/install-agents.sh" --group all || exit 1
~~~

Stop on any failure; preserve partial state and backups. Verify all six roles and
their discovery in the original task. If roles are stale, stop delegation; a normal
client exit/reopen into the same task may be needed. Hot reload is not guaranteed.
See [advanced native operations](plugins/sol-advisor/skills/orchestration/references/operations.md).

## Preview validation and limits

Windows, Codex CLI 0.160.0 and desktop 26.930.3930.0: all three current roles ran
from one original development task after client reopen; 7+13 fixture tests passed.
Reviewer returned ship, with behaviorally read-only review under broader host permissions.
Legacy configuration/offline checks passed; its full live run was not repeated.
Other platforms and separate business-task continuity remain unverified.
See the [validation scope](docs/RELEASE_v0.7.0-rc.2.md#validation-scope) before adopting this preview.

## Go deeper

Original author Daniel McAteer writes [**Attention Heads**](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor),
including **Agentic Engineering Field Notes**. [Subscribe to his newsletter](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor).
