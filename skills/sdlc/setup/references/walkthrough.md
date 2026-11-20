# Detection and question groups

## Detection

Detect first. Each question then shows the detected value, or the schema default when detection found nothing.

| Key | How to detect |
|---|---|
| `default_branch` | `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`. If that fails, `git symbolic-ref --short refs/remotes/origin/HEAD` without the `origin/` part. |
| `issue.tracker` | `github` when the `origin` URL has the host `github.com`. Any other host: no tracker. |
| `issue.estimation` | `fibonacci` when the repo already has labels for story points (`gh label list`). If not, `none`. |
| `guides.development` | A file named `DEVELOPMENT.md`, `CONTRIBUTING.md`, `CONVENTIONS.md` or `STYLEGUIDE.md` |
| `guides.code_review` | A file named `CODE_REVIEW.md`, `REVIEW.md` or `REVIEWING.md` |
| `guides.qa` | A file named `QA.md` or `TESTING.md` |
| `guides.labeling` | A file named `LABELS.md` or `LABELING.md` |
| `sizing.risk_paths` | Tracked folders (`git ls-files`) whose name holds `migration`, `security`, `auth`, `payment` or `checkout`. Suggest `<folder>/**` for each. Skip vendored and generated folders. |
| `research.engine` | A web search or documentation tool that is connected in this session. Use its name as the harness lists it. None: `null`. |

- Look for guide files at the repo root and in `.sdlc/`. Compare names without case. When several files match, show all of them. With `--auto`, take the first match in the order above.
- A path in the settings file is relative to the repo root.

## Groups

Ask in this order. Each group is one message.

1. Repository: `default_branch`, `issue.tracker`, `issue.estimation`.
2. Guides: `guides.development`, `guides.code_review`, `guides.qa`, `guides.labeling`. Tell the person that a skill with a `null` guide runs without one and says so.
3. Tasks and specs: `task.path`, `task.keep` (keep task folders after merge), `spec.storage` (where the spec lives), `spec.review` (whether specs are reviewed).
4. Review: `review.resolve` (who resolves a fixed thread), `review.prefix` (the mark on agent replies).
5. Sizing: Confirm the suggested `sizing.risk_paths`. Show the thresholds with their defaults. Change a threshold only when the person asks.
6. Retro and research: `retro.scope` (which chats the feature retro reads), `research.engine`.
