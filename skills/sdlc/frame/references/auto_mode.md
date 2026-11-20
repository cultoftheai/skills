# Auto mode

With `--auto`, the skill asks nothing and stops only on a hard stop: a duplicate exists, or no acceptance criterion can be written.

- Skip step 4 questions. Where a question would change the scope, take the narrower scope.
- Take the size from the signals. Skip step 8 and treat the story as approved.
- Write each assumption that replaced a question in a comment on each issue that you create, under an `## Assumptions` heading: the question and the answer that you took. For XS, put the assumptions in the report.
