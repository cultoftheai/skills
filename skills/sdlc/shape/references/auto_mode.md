# Auto mode

With `--auto`, the skill asks nothing. It stops only on a hard stop: no tool is connected for the tracker, or an open question that changes the data model or a public contract.

- In step 8, when `spec.review` is not `pr`, run `verify-spec` even when `spec.review` is `manual` or `off`. Apply each blocking finding. Ask the person nothing.
- Write each choice that a person would have made in the spec, under an `## Assumptions` heading.
