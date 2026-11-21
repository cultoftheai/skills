# Detection and question groups

## Detection

Detect first. Each question then shows the detected value, or the schema default when detection found nothing.

| Key | How to detect |
|---|---|
| `default_branch` | `gh repo view --json defaultBranchRef --jq .defaultBranchRef.name`. If that fails, `git symbolic-ref --short refs/remotes/origin/HEAD` without the `origin/` part. |
| `issue.tracker` | `github` when the `origin` URL has the host `github.com`. Any other host: nothing detected. |
| `issue.estimation` | `fibonacci` when the repo already has labels for story points (`gh label list`). If not, `tshirt`. |
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
   - Unless step 3 kept `issue.tracker`, ask it even when it was detected. Offer GitHub (marked as detected when it was), Jira and Linear, and let the person type another tracker. A typed tracker that the schema does not allow is a hard stop: name it and go to step 9. For Jira and Linear, say that the skills work through the connected Jira or Linear tool.
   - `issue.estimation`: `tshirt` estimates with the size labels XS to XL, `fibonacci` with story points, `none` not at all.
2. Tracker: `issue.project`, `issue.stages`, `issue.size_field`, `issue.types`. Ask only the keys that step 3 did not keep. Read `references/trackers.md` for the tracker in `issue.tracker`. Detect those keys as it says, then ask.
3. Guides: `guides.development`, `guides.code_review`, `guides.qa`, `guides.labeling`. Tell the person that a skill with a `null` guide runs without one and says so.
4. Tasks and specs: `task.path`, `task.keep` (keep task folders after merge), `spec.storage` (where the spec lives), `spec.review` (whether specs are reviewed), `templates.*` (the templates of issue bodies and task files, which step 8 copies in).
5. Review: `review.resolve` (who resolves a fixed thread), `review.prefix` (the mark on agent replies).
6. Sizing: Confirm the suggested `sizing.risk_paths`. Show the thresholds with their defaults. Change a threshold only when the person asks.
7. Retro and research: `retro.scope` (which chats the feature retro reads), `research.engine`.
