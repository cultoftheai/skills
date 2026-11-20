# Issue label catalog

Source: "AI SDLC GitHub Label System" (2026-11-19). The names, colours and descriptions are exact copies. Copy them exactly.

Column "This skill" says what `labeling-issues` can do with the label. "Not stated" in the column "Set by" means that the source document does not give a value.

## Groups

| Group | Namespaces | Status for this skill |
|---|---|---|
| core | `type`, `lock` | Required. Stop if it is not installed. |
| planning | `spec`, `dev` | Optional. Skip its rules if it is not installed. |
| tracking | `priority`, `size`, `status`, `resolution`, `area` | Optional. Skip its rules if it is not installed. |
| community | `good first issue`, `help wanted` (no namespace) | Optional. Skip its rules if it is not installed. |

## core

| Label | Colour | Description | Set by | This skill |
|---|---|---|---|---|
| `type: spec` | `#5319E7` | Write or refine a specification before any code | human | Recommend only |
| `type: feature` | `#1D76DB` | New capability or behaviour change | human, agent at triage | Add when the issue has no `type:` label |
| `type: bug` | `#D73A4A` | Something isn't working as specified | human, agent at triage | Add when the issue has no `type:` label |
| `type: chore` | `#6A737D` | Refactor, dependency, tooling or docs; no behaviour change | human, agent, Dependabot | Add when the issue has no `type:` label |
| `lock: ai` | `#24292F` | An agent holds this item; see the lock comment | agent | Never. Read only. |
| `lock: stale` | `#E99695` | Agent lock expired; a human checks the runner, then removes | watchdog | Never. Read only. |
| `lock: human` | `#D93F0B` | A human owns this item; agents keep out entirely | human only | Never. Read only. |

## planning

| Label | Colour | Description | Set by | This skill |
|---|---|---|---|---|
| `spec: needed` | `#C5DEF5` | A spec must be written and approved before development | human | Recommend only |
| `spec: in progress` | `#FBCA04` | An agent is drafting the spec | agent | Read only (claim protocol sets it) |
| `spec: changes requested` | `#B60205` | Reviewer asked for spec changes; agent may revise | human | Read only |
| `spec: human needed` | `#D93F0B` | Spec awaits human review or decision; agents keep out | agent, human | Add with a comment. Never remove. |
| `spec: approved` | `#0E8A16` | Spec accepted; development may start | human only | Never. Recommend only. |
| `dev: ready` | `#C5DEF5` | Human-confirmed: an agent may implement this | human only | Never. Recommend only. |
| `dev: in progress` | `#FBCA04` | An agent is implementing; see the lock comment | agent | Add or remove per transition rules 7 and 8 |
| `dev: done` | `#0E8A16` | Implementation is in a linked PR | agent | Add or remove per transition rules 7 and 8 |
| `dev: human needed` | `#D93F0B` | Needs a human developer or decision; agents keep out | agent, human | Add with a comment. Never remove. |

## tracking

| Label | Colour | Description | Set by | This skill |
|---|---|---|---|---|
| `priority: critical` | `#B60205` | Outage, data loss or security incident | Not stated | Add during triage |
| `priority: high` | `#D93F0B` | Release-blocking | Not stated | Add during triage |
| `priority: medium` | `#FBCA04` | Ordinary bug or feature | Not stated | Add during triage |
| `priority: low` | `#C2E0C6` | Cosmetic or follow-up work | Not stated | Add during triage |
| `size: s` | `#EDEDED` | Under half a day; safe for unattended agent work | Not stated | Add during triage |
| `size: m` | `#D4D4D4` | One to two days | Not stated | Add during triage |
| `size: l` | `#BDBDBD` | Several days; consider splitting | Not stated | Add during triage |
| `size: xl` | `#9E9E9E` | Must be split before development | Not stated | Add during triage. Always add a note that the issue must be split. |
| `status: triage` | `#FEF2C0` | New; needs type, priority and size | Not stated | Add to a new issue without a `type:` label. Never remove. |
| `status: blocked` | `#B60205` | Waiting on another issue or external party; link it | Not stated | Add or remove per transition rule 10 |
| `resolution: duplicate` | `#CFD3D7` | Already tracked elsewhere; link the original | Not stated | Propose only |
| `resolution: wont-fix` | `#CFD3D7` | Deliberately not doing this | Not stated | Propose only |
| `resolution: invalid` | `#CFD3D7` | Not reproducible or not a real problem | Not stated | Propose only |
| `area: <name>` | `#BFDADC` | Project-specific, e.g. `area: checkout`, `area: catalog`, `area: admin`, `area: api` | Not stated | Add during triage. Use only names that exist in the repository. |

## community

| Label | Colour | Description | Set by | This skill |
|---|---|---|---|---|
| `good first issue` | `#7057FF` | Kept verbatim: GitHub surfaces this name to newcomers | Not stated | Propose only |
| `help wanted` | `#008672` | Kept verbatim: GitHub surfaces this name to contributors | Not stated | Propose only |

## Shared labels

These labels are also valid on pull requests: all `type:` labels, all `lock:` labels, `status: blocked`, `resolution: duplicate` and `area:` labels. A lock on an issue and a lock on its pull request are independent.

## Human-only labels

Agents never add or remove these labels: `spec: approved`, `dev: ready`, `qa: skipped`, `merge: auto`, `merge: blocked`, `lock: human`. Agents never remove `lock: stale`.

## Wrong-target labels

These labels are valid only on pull requests. On an issue, they are wrong-target labels.

| Namespace | Labels |
|---|---|
| `code-review` | `code-review: needed`, `code-review: in progress`, `code-review: changes requested`, `code-review: ai done`, `code-review: human needed`, `code-review: done` |
| `qa` | `qa: needed`, `qa: in progress`, `qa: failed`, `qa: human needed`, `qa: done`, `qa: skipped` |
| `merge` | `merge: auto`, `merge: parked`, `merge: blocked` |

`qa: skipped`, `merge: auto` and `merge: blocked` are also human-only labels.
