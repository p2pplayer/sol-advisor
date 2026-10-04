# Sol Advisor

**Sol / High runs the show. It declares a risk-gated route before task tools, keeps
solo as the default, and uses a single auxiliary only when that improves delivery.**

Sol Advisor is a Codex-only workflow for capability-routed software delivery. You
bring the goal and constraints; Sol owns the plan, implementation or delegation,
verification, and acceptance.

## Go deeper

I write [**Attention Heads**](https://attentionheads.substack.com/?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) — deep, evidence-backed writing on AI, cognition, and agentic engineering. The **Agentic Engineering Field Notes** series is where I publish practical advice on the craft of using AI. [Subscribe](https://attentionheads.substack.com/subscribe?utm_source=github&utm_medium=readme&utm_campaign=sol-advisor) to get new posts to your inbox.

## Quick start

You need native custom agents, jq, and Python 3.11+. GPT-5.6 Sol/high selects
legacy; GPT-6.1 Sol/high selects current. Other primary combinations refuse.
Legacy Luna / Max or Terra / High access is needed only when delegating; current
uses GPT-6 Luna/max or a separate GPT-6.1 Sol/high complex role and reviewer.

~~~sh
codex plugin marketplace add p2pplayer/sol-advisor --ref feature/sol61-model-group
codex plugin add sol-advisor@sol-advisor
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')" && test -n "$plugin_dir" && test "$plugin_dir" != null && test -d "$plugin_dir" && test -f "$plugin_dir/scripts/install-agents.sh" && sh "$plugin_dir/scripts/install-agents.sh" --group all
~~~

Candidate 0.7.0-rc.2: install only after external review and explicit authorization.
The companion installer verifies all six exact role files after installation. It is
fail-closed: modified, unsafe, nonregular, symlinked, unknown, or differing files
are left untouched. It does not edit Codex configuration. Preserve the existing root task;
verify discovery and actual execution there. If roles are stale, stop delegation
and follow the host-specific same-session steps in advanced native operations.

Use this one prompt in the existing task at a safe implementation boundary:

~~~text
Use $sol-advisor:orchestration to build this feature and verify it. Declare the selective route before task tools.
~~~

## What you do

Give Sol the outcome, constraints, and any important repository context. You do not
need to select or manage a lane; Sol records the route and owns verification and
acceptance.

## Routes

| Mode | Use it when | Delivery |
|---|---|---|
| `solo` | Default; risk is contained. | Root plans, implements, tests, and self-reviews. |
| `delegate` | A complete spec is better executed by one implementer. | Luna / Max for bounded work, or Terra / High for judgment-heavy or high-risk work; root verifies. |
| `audit` | Independent final scrutiny matters more than delegation. | Root implements; a fresh read-only Sol / High reviews. |
| `full` | Explicit broad or high-risk exception. | One selected implementer, root verification, and a fresh Sol / High review. |

Solo is the default. One auxiliary is the default maximum; `full` is the explicit
exception. Sol emits a `SELECTIVE ROUTE` declaration with the mode and concise risk
rationale before the first task tool call. It can escalate only when newly observed
risk justifies it and never silently downgrades.

## What happens automatically

Sol / High keeps architecture, decomposition, route selection, parent verification,
escalation decisions, and acceptance in the primary task. Auxiliary work substitutes
for root work; it does not duplicate it. The root inspects the complete diff and
reruns the requested checks. When the selected route includes a review, a fresh Sol /
High reviewer returns ship, fix-first, or rethink; any fix requires a new review.

## Updating

After review and explicit install authorization, update the plugin and roles.
Reconfirm the effective primary each invocation in the same root task; no hot-reload
guarantee is made. Do not switch mappings while old children remain active:

~~~sh
codex plugin marketplace upgrade sol-advisor
codex plugin add sol-advisor@sol-advisor
plugin_dir="$(codex plugin list --json | jq -r '.installed[] | select(.pluginId == "sol-advisor@sol-advisor") | .source.path')" && test -n "$plugin_dir" && test "$plugin_dir" != null && test -d "$plugin_dir" && test -f "$plugin_dir/scripts/install-agents.sh" && sh "$plugin_dir/scripts/install-agents.sh" --group all
~~~

For exact spawn, runtime-evidence, sandbox, installer, and maintainer verification
details, read [advanced native operations](plugins/sol-advisor/skills/orchestration/references/operations.md).
For isolated local tests only, set a disposable process-scoped CODEX_HOME first.
Never register a candidate in a shared or active business environment:

~~~sh
cd /absolute/path/to/sol-advisor
codex plugin marketplace add /absolute/path/to/sol-advisor
codex plugin add sol-advisor@sol-advisor
~~~
