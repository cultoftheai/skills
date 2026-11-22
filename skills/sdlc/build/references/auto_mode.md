# Auto mode

With `--auto`, the skill does not check in. It stops only on a hard stop: no tool is connected for the tracker, a decision that the spec did not cover, a diff past `sizing.review_limit`, or a local review that stops.

- Do not show the data shape for a yes. Build it as the spec says.
- In the local review, take the recommendation for each finding. A `stop` finding is a decision that the spec did not cover.
- Where the spec allows more than one reading and the choice is not a decision of its own, take the reading closest to the existing code. Write each such choice in a comment on the task, under an `## Assumptions` heading. For XS, put the choices in the report.
