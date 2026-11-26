# review-triage.md format

Path: `<work.path>/<id>/review-triage.md` (fallback `.sdlc/work/<id>/review-triage.md`). Never stage or commit this file. `<id>` is the issue linked to the pull request: check `closingIssuesReferences` first, then `Spec for #<id>` or `Design for #<id>` in the PR body (`gh pr view <pr> --json body,closingIssuesReferences`). If the pull request links no issue, use `pr-<pr>` for `<id>`.

Put each new round at the top, under the title. Keep the older rounds. Write one row for each thread that the round answered.

Fill in the template at `templates.review`. If that setting or file does not exist, use `assets/templates/review.md` and say so in the report.

- **Concern.** Write the concern in your own words. Do not copy the comment.
- **Evidence.** For `fix` and `fix differently`, the commit SHA. For `decline`, the reason. For `needs-you`, the decision that a person must make. For `follow-up`, the issue URL.
- **Assumptions.** Only `--auto` runs write this section.
