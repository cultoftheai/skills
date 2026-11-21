# Sizing

Size measures process weight, not hours. Read the thresholds from `sizing.*` in `.sdlc/settings.json`. When in doubt between two sizes, take the smaller one.

## The four questions

Ask them in order. The first one that decides ends the procedure. Each answer must point at something countable in the request, the tracker or the code.

1. Is there more than one outcome that is worth shipping alone? Two outcomes are separate when either one can be released without the other and still help someone. Yes: XL. Split into stories.
2. Would anyone notice a change in behaviour? Anyone means a user, an API client or an operator. No, and every XS condition holds: XS.
3. Do the parts of the work depend on a shared decision? Check the L triggers against the request and a quick code search. Any trigger: L.
4. How many slices can ship on their own? Group the acceptance criteria. Each group that can be demoed alone is one slice. One: S. From two to `m_max_tasks`: M. More: L.

## XS conditions

All must hold:

- No behaviour that a user, an API client or an operator would notice.
- At most `xs_max_files` files and about `xs_max_lines` changed lines.
- No file under a glob in `risk_paths`.

## L triggers

Any one is enough:

- Data model change: a new or changed entity, column or relation, or any migration.
- Changed public contract: an API endpoint, an event or message, a CLI command, a configuration schema, or an extension point that others build on.
- Module boundaries: work in `l_min_modules` or more top-level modules, or a new dependency between modules.
- Hard to reverse: data that is transformed or dropped, or an effect outside the system such as an email, a payment or a call to a third party.
- Sensitive area: a file under a glob in `risk_paths`.

## Modules and risk paths

Search the code for the domain terms of the story. Count the top-level modules of the files that match. Match those file paths against each glob in `risk_paths`. This count is rough. `shape` counts again after it reads the code.

## The size line

Print one line with the size and every signal in question order, each with its count or the evidence:

`Size: M. 1 outcome, behaviour change, no L trigger (2 modules: billing, accounts; no risk path), 6 criteria in 2 groups.`

A person corrects the size by correcting one signal. Put the line in the issue body under `## Size`.
