# Label catalog

The full catalog of the AI SDLC GitHub label system. `scripts/check_labels.py` reads this file. Keep the format: one `## Group` heading per group, one `Requires -` line, one table row per label.

- **On** - The target where the label is valid: `issue`, `PR`, or `issue, PR`.
- **Colour** - Hex colour. `gh` takes it without the `#`.
- **Description** - Exact text. Each description fits the GitHub limit of 100 characters.
- A group is installed when all its labels exist in the repository.
- `area: <name>` is a pattern, not one label. The area names are project-specific. The pattern does not count for the install status of the tracking group.

## Group `core`

Requires - none

Install when - always. Every other group relies on the lock and on type routing.

| Label | On | Colour | Description |
|---|---|---|---|
| `type: spec` | issue, PR | `#5319E7` | Write or refine a specification before any code |
| `type: feature` | issue, PR | `#1D76DB` | New capability or behaviour change |
| `type: bug` | issue, PR | `#D73A4A` | Something isn't working as specified |
| `type: chore` | issue, PR | `#6A737D` | Refactor, dependency, tooling or docs; no behaviour change |
| `lock: ai` | issue, PR | `#24292F` | An agent holds this item; see the lock comment |
| `lock: stale` | issue, PR | `#E99695` | Agent lock expired; a human checks the runner, then removes |
| `lock: human` | issue, PR | `#D93F0B` | A human owns this item; agents keep out entirely |

## Group `planning`

Requires - core

Install when - agents write specs or implement issues.

| Label | On | Colour | Description |
|---|---|---|---|
| `spec: needed` | issue | `#C5DEF5` | A spec must be written and approved before development |
| `spec: in progress` | issue | `#FBCA04` | An agent is drafting the spec |
| `spec: changes requested` | issue | `#B60205` | Reviewer asked for spec changes; agent may revise |
| `spec: human needed` | issue | `#D93F0B` | Spec awaits human review or decision; agents keep out |
| `spec: approved` | issue | `#0E8A16` | Spec accepted; development may start |
| `dev: ready` | issue | `#C5DEF5` | Human-confirmed: an agent may implement this |
| `dev: in progress` | issue | `#FBCA04` | An agent is implementing; see the lock comment |
| `dev: done` | issue | `#0E8A16` | Implementation is in a linked PR |
| `dev: human needed` | issue | `#D93F0B` | Needs a human developer or decision; agents keep out |

## Group `review`

Requires - core

Install when - agents open or review PRs.

| Label | On | Colour | Description |
|---|---|---|---|
| `code-review: needed` | PR | `#C5DEF5` | Ready for review of the current head |
| `code-review: in progress` | PR | `#FBCA04` | An agent is reviewing the current head |
| `code-review: changes requested` | PR | `#B60205` | Blocking findings; author must push fixes |
| `code-review: ai done` | PR | `#D4C5F9` | AI review passed for the current head; human review pending |
| `code-review: human needed` | PR | `#D93F0B` | AI escalated; a human must review before merge |
| `code-review: done` | PR | `#0E8A16` | Approved for the current head |

## Group `qa`

Requires - core

Install when - the product has behaviour worth testing before merge.

| Label | On | Colour | Description |
|---|---|---|---|
| `qa: needed` | PR | `#C5DEF5` | Requires QA of the current head before merge |
| `qa: in progress` | PR | `#FBCA04` | QA running against the current head |
| `qa: failed` | PR | `#B60205` | QA found defects; see the report comment |
| `qa: human needed` | PR | `#D93F0B` | Manual QA only; agents never pick this up |
| `qa: done` | PR | `#0E8A16` | QA passed for the current head |
| `qa: skipped` | PR | `#EDEDED` | QA waived by a human; reason in a comment |

## Group `delivery`

Requires - core, review

Install when - you want gated auto-merge.

| Label | On | Colour | Description |
|---|---|---|---|
| `merge: auto` | PR | `#0E8A16` | Human-confirmed: merge once every gate is green |
| `merge: parked` | PR | `#D93F0B` | Auto-merge gave up; a human removes this to retry |
| `merge: blocked` | PR | `#B60205` | Hard merge block; overrides everything |

## Group `tracking`

Requires - core

Install when - GitHub Issues is your tracker.

| Label | On | Colour | Description |
|---|---|---|---|
| `priority: critical` | issue | `#B60205` | Outage, data loss or security incident |
| `priority: high` | issue | `#D93F0B` | Release-blocking |
| `priority: medium` | issue | `#FBCA04` | Ordinary bug or feature |
| `priority: low` | issue | `#C2E0C6` | Cosmetic or follow-up work |
| `size: s` | issue | `#EDEDED` | Under half a day; safe for unattended agent work |
| `size: m` | issue | `#D4D4D4` | One to two days |
| `size: l` | issue | `#BDBDBD` | Several days; consider splitting |
| `size: xl` | issue | `#9E9E9E` | Must be split before development |
| `status: triage` | issue | `#FEF2C0` | New; needs type, priority and size |
| `status: blocked` | issue, PR | `#B60205` | Waiting on another issue or external party; link it |
| `resolution: duplicate` | issue, PR | `#CFD3D7` | Already tracked elsewhere; link the original |
| `resolution: wont-fix` | issue | `#CFD3D7` | Deliberately not doing this |
| `resolution: invalid` | issue | `#CFD3D7` | Not reproducible or not a real problem |
| `area: <name>` | issue, PR | `#BFDADC` | Project-specific, e.g. `area: checkout`, `area: catalog`, `area: admin`, `area: api` |

## Group `community`

Requires - none

Install when - open-source repos with outside contributors. Opt-in: ask the user before you install it.

| Label | On | Colour | Description |
|---|---|---|---|
| `good first issue` | issue | `#7057FF` | Kept verbatim: GitHub surfaces this name to newcomers |
| `help wanted` | issue | `#008672` | Kept verbatim: GitHub surfaces this name to contributors |
