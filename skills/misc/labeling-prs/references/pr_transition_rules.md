# Pull request transition rules

Apply the rules in this order. Each rule reads the labels as the earlier rules left them. Skip a rule when its label group is partial or missing. Do not change a namespace that has `X: human needed`.

## Terms

- **Current head** - `headRefOid` of the pull request.
- **Human review** - a review from `gh api repos/{owner}/{repo}/pulls/<pr-number>/reviews` with `user.type` equal to `User`. A review with `user.type` equal to `Bot` is not a human review.
- **State SHA** - the commit that a `code-review:` or `qa:` state refers to. Find it in this order:
  1. For a state that mirrors a human review: the `commit_id` of that review.
  2. For a state that an agent set: the `head <sha>` value in the newest agent comment for that namespace. This is the `<!-- sdlc-lock -->` comment with that namespace, or a review or QA report comment that names a head SHA.
  3. If no SHA is found, the state SHA is unknown.
- **SHA match** - two SHAs match when the shorter one is a prefix of the longer one.
- **Linked issue** - an issue in `closingIssuesReferences`.
- **Workflow terms** - Spec gate open, Development done, Human review required and Review passed have the meanings that `workflow.md` gives. Gates G3, G4 and G5 are defined there too.

## 1. Wrong-target labels

1. For each issue-only label on the pull request (see `pr_label_catalog.md`), plan to remove it. Reason - "issue-only label".
2. If the label is human-only (`spec: approved`, `dev: ready`), do not remove it. Recommend in the report that a human removes it.

## 2. Labels that are not in the catalog

Do not change a label that is not in the catalog and does not start with a catalog namespace. List it in the report.

## 3. type (core group)

1. If the pull request has one linked issue with exactly one `type:` label, the pull request must have that `type:` label. Plan to add it and to remove each other `type:` label.
2. If the linked issues have different `type:` labels, ask the user which type to use.
3. If the pull request has no linked issue, or the linked issue has no `type:` label:
   - If the pull request already has exactly one `type:` label, keep it.
   - If the author is Dependabot (`author.login` is `app/dependabot` or `dependabot[bot]`), the pull request must have `type: chore`.
   - If not, classify the pull request from its title, body and changed files. Use `type: feature` for a new capability or behaviour change, `type: bug` for a fix, and `type: chore` for a refactor, dependency, tooling or docs change. Do not add `type: spec`. A human sets it.
   - If the pull request has two or more `type:` labels, ask the user which type to keep.

## 4. area (tracking group)

1. If the pull request has a linked issue, plan to add each `area:` label of the linked issue that the pull request does not have.
2. Add only `area:` labels that exist in the repository.
3. If the result has more than one `area:` value, ask the user which value to keep.
4. If the pull request has no linked issue, do not add an `area:` label.

## 5. code-review (review group)

Do these checks in order. Stop at the first check that gives a value.

1. **Frozen** - If the pull request has `code-review: human needed`, do not change the namespace. If a human review on the current head approves or requests changes, write it in the report. A human removes `code-review: human needed`.
2. **Gate G3** - Gate G3 is closed when the pull request is a draft, or when a linked issue does not have its spec gate open. If gate G3 is closed, the namespace must have no label. Plan to remove the `code-review:` label. Reason - "G3: pull request is a draft" or "G3: spec of #N is not approved". If the label shows that a review started or ended (`in progress`, `changes requested`, `ai done`, `done`), add it to the workflow comment. Go to rule 6.
3. **Mirror human reviews** - Use the newest `APPROVED` or `CHANGES_REQUESTED` human review of each reviewer. Use only the reviews whose `commit_id` matches the current head.
   - If one of these reviews is `CHANGES_REQUESTED`, the value is `code-review: changes requested`.
   - If not, and one of these reviews is `APPROVED`, the value is `code-review: done`.
4. **Reset on a new head** - If the label is `code-review: done`, `code-review: ai done` or `code-review: changes requested`, and the state SHA does not match the current head, the value is `code-review: needed`. Reason - "new commits after the review on <state SHA>".
5. **Unknown SHA** - If the state SHA is unknown, keep the label. Write in the report that the state is not bound to a SHA.
6. **Entry** - If the pull request has no `code-review:` label, the value is `code-review: needed`. Reason - "G3 open: development is done".
7. **In progress without a lock** - If the label is `code-review: in progress`, keep it. Write in the report that no `lock: ai` holds the pull request.

If the value is different from the current label, plan to add the value and remove the current label.

## 6. qa (qa group)

Do these checks in order. Stop at the first check that gives a value.

1. **Frozen** - If the pull request has `qa: human needed`, do not change the namespace.
2. **Waived** - If the pull request has `qa: skipped`, do not change the namespace. `qa: skipped` is human-only.
3. **Gate G4** - Use the `code-review:` value that rule 5 gave. Gate G4 is closed when the review did not pass on the current head. If gate G4 is closed, the namespace must have no label. Plan to remove the `qa:` label. Reason - "G4: code review has not passed on <current head>". If the label is `qa: in progress`, `qa: done` or `qa: failed`, and its state SHA is unknown or matches the current head, QA ran before the review passed: add the label to the workflow comment. If its state SHA does not match the current head, a new push reset the stage: give only the reason.
4. **Reset on a new head** - If the label is `qa: done` or `qa: failed`, and the state SHA does not match the current head, the value is `qa: needed`. Reason - "new commits after QA on <state SHA>".
5. **Unknown SHA** - If the state SHA is unknown, keep the label. Write in the report that the state is not bound to a SHA.
6. **Entry** - If the pull request has no `qa:` label, the value is `qa: needed`. Reason - "G4 open: code review passed on <current head>".
7. **In progress without a lock** - If the label is `qa: in progress`, keep it. Write in the report that no `lock: ai` holds the pull request.

If the value is different from the current label, plan to add the value and remove the current label.

## 7. status and resolution (tracking group)

1. `status: blocked` - If the body or a comment says "blocked by #N" or "depends on #N", and item #N is open, the pull request must have `status: blocked`. If all such items are closed, plan to remove `status: blocked`. If the pull request has `status: blocked` but no such link, keep it. Write in the report that the blocking item is not linked.
2. `resolution: duplicate` - Do not add or remove it. If another open pull request closes the same linked issue, write in the report that the pull request can be a duplicate.

## 8. Namespace conflicts

After rules 1 to 7, each namespace must have one value.

1. If a rule gave a value for the namespace, that value replaces all other values in the namespace.
2. If no rule gave a value, ask the user which value to keep.
3. If a value to remove is human-only, do not remove it. Ask the user to remove it.
4. For `merge:` and `lock:` conflicts, change nothing. Write the conflict in the report.

## 9. Human-only recommendations

Recommend each human-only label that comes next. Do not add it.

- Review passed, `qa: done` or `qa: skipped` (or the qa group is partial or missing), and no `merge:` label - recommend that a human adds `merge: auto` (delivery group).
- `qa: needed` and the change cannot be tested by an agent (payments, emails, visual checks) - recommend `qa: human needed` or `qa: skipped`, with the reason in a comment.

## 10. Merge-gate status (delivery group)

Report each gate as pass, fail or unknown. Do not change a `merge:` label.

1. All required checks pass. Use `bucket` from `gh pr checks`.
2. `code-review: done`, or `code-review: ai done` when the AI-only policy applies. The default AI-only policy is `type: chore` on the pull request and `size: s` on the linked issue.
3. Gate G5 - `qa: done` or `qa: skipped`. A pull request with no `qa:` label fails this gate, because `qa: needed` comes only after the review passes. Skip this gate when the qa group is partial or missing.
4. No `lock:` label, no `merge: blocked` and no `X: human needed` label.
5. `mergeStateStatus` is not `BEHIND`, `DIRTY` or `BLOCKED`.

Write `merge: auto` and `merge: parked` as they are. If the pull request has `merge: parked`, write that a human removes it to retry.
