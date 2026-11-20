# Pull request label catalog

Source: "AI SDLC GitHub Label System". Copy each name exactly. A label name has a space after the colon.

The `configure-github` skill creates these labels. This skill only adds them to a pull request and removes them from it.

"Human-only" in the Set by column means: an agent never adds or removes the label.

## Shared labels (issue and pull request)

These labels are valid on issues and on pull requests. A lock on an issue and a lock on its pull request are independent.

| Label | Group | Colour | Description | Set by |
|---|---|---|---|---|
| `type: spec` | core | `#5319E7` | Write or refine a specification before any code | human |
| `type: feature` | core | `#1D76DB` | New capability or behaviour change | human, agent at triage |
| `type: bug` | core | `#D73A4A` | Something isn't working as specified | human, agent at triage |
| `type: chore` | core | `#6A737D` | Refactor, dependency, tooling or docs; no behaviour change | human, agent, Dependabot |
| `lock: ai` | core | `#24292F` | An agent holds this item; see the lock comment | agent |
| `lock: stale` | core | `#E99695` | Agent lock expired; a human checks the runner, then removes | watchdog (removal is human-only) |
| `lock: human` | core | `#D93F0B` | A human owns this item; agents keep out entirely | human only |
| `status: blocked` | tracking | `#B60205` | Waiting on another issue or external party; link it | not stated in the doc |
| `resolution: duplicate` | tracking | `#CFD3D7` | Already tracked elsewhere; link the original | not stated in the doc |
| `area: <name>` | tracking | `#BFDADC` | Project-specific, e.g. `area: checkout`, `area: catalog`, `area: admin`, `area: api` | not stated in the doc |

`area:` values are project-specific. Use only the `area:` labels that exist in the repository.

## Pull-request-only labels

| Label | Group | Colour | Description | Set by |
|---|---|---|---|---|
| `code-review: needed` | review | `#C5DEF5` | Ready for review of the current head | agent, human |
| `code-review: in progress` | review | `#FBCA04` | An agent is reviewing the current head | agent |
| `code-review: changes requested` | review | `#B60205` | Blocking findings; author must push fixes | agent, human |
| `code-review: ai done` | review | `#D4C5F9` | AI review passed for the current head; human review pending | agent |
| `code-review: human needed` | review | `#D93F0B` | AI escalated; a human must review before merge | agent, human |
| `code-review: done` | review | `#0E8A16` | Approved for the current head | human, or agent per policy |
| `qa: needed` | qa | `#C5DEF5` | Requires QA of the current head before merge | agent, human |
| `qa: in progress` | qa | `#FBCA04` | QA running against the current head | agent |
| `qa: failed` | qa | `#B60205` | QA found defects; see the report comment | agent, human |
| `qa: human needed` | qa | `#D93F0B` | Manual QA only; agents never pick this up | agent, human |
| `qa: done` | qa | `#0E8A16` | QA passed for the current head | agent, human |
| `qa: skipped` | qa | `#EDEDED` | QA waived by a human; reason in a comment | human only |
| `merge: auto` | delivery | `#0E8A16` | Human-confirmed: merge once every gate is green | human only |
| `merge: parked` | delivery | `#D93F0B` | Auto-merge gave up; a human removes this to retry | agent |
| `merge: blocked` | delivery | `#B60205` | Hard merge block; overrides everything | human only |

## Groups

| Group | Requires | Labels on a pull request |
|---|---|---|
| core | none | all `type:` and `lock:` labels |
| review | core | all `code-review:` labels |
| qa | core | all `qa:` labels |
| delivery | core, review | all `merge:` labels |
| tracking | core | `status: blocked`, `resolution: duplicate`, `area:` labels |

## Issue-only labels (wrong target on a pull request)

These labels are valid only on issues:

- `spec: needed`, `spec: in progress`, `spec: changes requested`, `spec: human needed`, `spec: approved` (human-only)
- `dev: ready` (human-only), `dev: in progress`, `dev: done`, `dev: human needed`
- `priority: critical`, `priority: high`, `priority: medium`, `priority: low`
- `size: s`, `size: m`, `size: l`, `size: xl`
- `status: triage`, `resolution: wont-fix`, `resolution: invalid`
- `good first issue`, `help wanted`

## Human-only labels

`spec: approved`, `dev: ready`, `qa: skipped`, `merge: auto`, `merge: blocked`, `lock: human`, and the removal of `lock: stale`.
