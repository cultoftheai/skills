# Issue transition rules

Apply the rules in this order. Each rule says the group that it needs. Skip a rule when its group is not usable. Later rules use the labels as the earlier rules changed them.

Terms:

- **Linked pull request** - An open pull request that closes the issue (`closedByPullRequestsReferences`).
- **Dependency** - An issue in `blockedBy` of the issue, or an issue that the body names as "blocked by #N" or "depends on #N".
- **Frozen namespace** - Namespace X when the issue has `X: human needed`. Do not move a frozen namespace to a different label.

## 1. Wrong-target labels (core)

- If the issue has a label from "Wrong-target labels" in `issue_labels.md`, remove it. Reason: valid only on pull requests.
- If that label is human-only (`qa: skipped`, `merge: auto`, `merge: blocked`), do not remove it. Recommend in the report that a human removes it.

## 2. One value per namespace (core)

Namespaces: `type`, `spec`, `dev`, `priority`, `size`, `status`, `resolution`, `area`.

- If the issue has two or more labels in one namespace and one of them is human-only, ask the user which label to keep. Do not propose a choice. Remove only the labels that are not human-only. Recommend that a human removes a human-only label.
- If one of the labels is `X: human needed`, keep it. Remove the other labels of namespace X.
- In all other cases, propose the label to keep with a reason. Use the issue content and the later rules of this file. Remove the other labels of that namespace.

## 3. Type (core)

- If the issue has a `type:` label, do not change it. If you think that it is wrong, say so in the report.
- If the issue has no `type:` label:
  1. If the tracking group is usable and the issue has no `status:` label, add `status: triage`.
  2. Classify the issue with the descriptions of the `type:` labels. Add `type: bug`, `type: feature` or `type: chore`.
  3. If the issue asks for a specification before any code, do not add `type: spec`. Recommend it in the report. A human sets it.
  4. If no type fits with confidence, add no `type:` label. Say so in the report.

## 4. Triage (tracking)

Apply this rule only when the issue has `status: triage`.

- If the issue has no `priority:` label, add one. Use the descriptions: `critical` for an outage, data loss or security incident. `high` for a release-blocking problem. `medium` for an ordinary bug or feature. `low` for cosmetic or follow-up work.
- If the issue has no `size:` label, add one. Use the descriptions: `s` under half a day. `m` one to two days. `l` several days. `xl` must be split before development.
- If the issue has no `area:` label and exactly one existing `area:` label of the repository matches the issue, add it.
- If rule 3 or rule 4 added one or more labels, post the triage comment (template below).
- Do not remove `status: triage`. A human confirms the proposal and removes it.

## 5. Size xl (tracking)

- If the issue has `size: xl`, add a note to the report: the issue must be split before development. Agents do not pick up `size: xl`.

## 6. Routing advice (planning)

The next label after the type is human-set. Recommend it in the report. Do not add it.

| Issue labels | Recommendation |
|---|---|
| `type: spec`, no `spec:` label | A human adds `spec: needed`. |
| `type: feature`, no `spec:` or `dev:` label | A human adds `spec: needed` if the feature needs design, or `dev: ready` if it is small and clear. |
| `type: feature`, `spec: approved`, no `dev:` label | A human adds `dev: ready`. |
| A `spec:` label other than `spec: approved` | No `dev:` label until a human adds `spec: approved` (gate G1). |
| `type: spec`, `spec: approved` | The output is one or more `type: feature` issues that link to this issue. |
| `type: bug` or `type: chore`, no `dev:` label | A human adds `dev: ready`. |

## 7. Stage gates (planning)

Read `workflow.md`. This rule uses gates G1 and G2.

- Gate G1 is closed when the issue has `spec: needed`, `spec: in progress`, `spec: changes requested` or `spec: human needed`, or when the issue has `type: spec`.
- If gate G1 is closed and `dev` is a frozen namespace, do not change the `dev:` label.
- If gate G1 is closed and the issue has `dev: in progress` or `dev: done`, remove the label. Reason: "G1: spec is not approved", or "G1: a type: spec issue has no development". Add the label to the workflow comment.
- If gate G1 is closed and the issue has `dev: ready`, do not remove it, because it is human-only. Flag it in the report and in the workflow comment.
- If the tracking group is usable, gate G2 is closed, and the issue has `dev: ready`, write in the report that agents may not pick up the issue, and why. Do not change labels for gate G2.
- If this rule removed or flagged a label, post the workflow comment of `workflow.md`.

## 8. Development state (planning)

Skip this rule when `dev` is a frozen namespace or gate G1 is closed. "Rework label" means `code-review: changes requested` or `qa: failed` on a linked pull request. "Ready pull request" means a linked pull request that is not a draft: development is done only when the pull request is ready for review.

- If the issue has `dev: done` and a linked pull request has a rework label, remove `dev: done` and add `dev: in progress`.
- If the issue has `dev: done` and has no ready pull request, remove `dev: done` and add `dev: in progress`. Reason: development is not done, the linked pull requests are drafts.
- If the issue has `dev: in progress`, the issue has one or more ready pull requests, and no linked pull request has a rework label, remove `dev: in progress` and add `dev: done`.
- In all other cases, do not change the `dev:` label.

## 9. Spec state (planning)

- Do not change `spec:` labels with this rule. Humans and the claim protocol move them. Only rules 1 and 2 can remove a `spec:` label.

## 10. Blocked status (tracking)

- If one or more dependencies are open and the issue has no `status:` label, add `status: blocked`. Name the open dependencies in the reason.
- If one or more dependencies are open and the issue has `status: triage`, do not add `status: blocked`. Name the open dependencies in the report.
- If the issue has `status: blocked`, it has one or more dependencies, and all of them are closed, remove `status: blocked`.
- If the issue has `status: blocked` and no dependencies, keep the label. It can wait on an external party. Recommend in the report that a human links the dependency.

## 11. Resolution proposals (tracking)

- If the issue is a duplicate, will not be done, or is not a real problem, propose `resolution: duplicate`, `resolution: wont-fix` or `resolution: invalid` in the report. Give the evidence, for example the number of the original issue. Do not add the label.

## 12. Community proposals (community)

- If the issue matches the description of `good first issue` or `help wanted`, propose the label in the report. Do not add it.

## Comment templates

Replace each `<...>` part. Remove each line that does not apply.

Triage comment:

```markdown
**Triage proposal** (labeling-issues)

- Type: `<type label>` - <reason>
- Priority: `<priority label>` - <reason>
- Size: `<size label>` - <reason>
- Area: `<area label>` - <reason>
- `size: xl`: split this issue before development.

A human confirms this proposal: change each wrong label, then remove `status: triage`.
```

Human-needed comment (post it each time you add `X: human needed`):

```markdown
**Human decision needed** (`<X>: human needed`)

- Decision: <the decision that a human must make>
- Reason: <why an agent cannot make it>
```
