# Local review
Reviewed: e521ff7. Verified: no.

| # | Axis | Severity | Location | Finding | Recommendation | Decision | Fix | Verify |
|---|------|----------|----------|---------|----------------|----------|-----|--------|
| 1 | consistency | blocking | qa-fixture/grade.sh:5 | `-gt 90` gives B for a score of 90, but the header says A from 90. | fix | fix | b0e2881 | |
| 2 | consistency | should-fix | qa-fixture/grade.sh:3 | The header says the script exits 2 on a score outside 0 to 100, but there is no range check. | fix | fix | b0e2881 | |
| 3 | guide | nit | qa-fixture/grade.sh:2 | Typo "Pritn" in the header. | skip | skip | | |
