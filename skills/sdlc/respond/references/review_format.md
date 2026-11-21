# REVIEW.md format

Path: `<task.path>/<issue>/REVIEW.md`. `<issue>` is the issue that the pull request closes. Find it with `gh pr view <pr> --json closingIssuesReferences`. If the pull request closes no issue, use `pr-<pr>` for `<issue>`.

Put each new round at the top, under the title. Keep the older rounds. Write one row for each thread that the round answered.

Fill in the template at `templates.review`. If that setting or file does not exist, use `assets/templates/review.md` and say so in the report.

- **Concern.** Write the concern in your own words. Do not copy the comment.
- **Evidence.** For fix and fix differently, the commit SHA. For decline, the reason. For needs-you, the decision that a person must make. For follow-up, the issue URL.
- **Assumptions.** Only `--auto` runs write this section.
