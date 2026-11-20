# Auto mode

With `--auto`, the skill asks nothing.

- Take each detected value. Where detection found nothing, take the schema default.
- Do not show the file for a yes. Write it and validate it.
- Skip steps 7, 8 and 9. Never create labels, scripts or workflow files. List each one in the report as left to do, with its command.
- Hard stops: no Git repo, no tracker detected. Say which one in the step 10 report.
- The settings file cannot hold notes. Put every key that was not kept from an earlier file under an `## Assumptions` heading in the report: the key, the value, and "detected from <source>" or "schema default".
