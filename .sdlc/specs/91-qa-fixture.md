# Spec: QA fixture for verify-spec

Task: #91. Story: #87.

## Data shape
- Uses `verify_spec_helper` from `skills/sdlc/verify-spec/nonexistent.md`.

## Seam
- Calls `install_spec_layout` in `skills/sdlc/setup/scripts/install.sh` to copy `skills/sdlc/verify-spec/SKILL.md`.

## Files
- `skills/sdlc/verify-spec/SKILL.md` - Existing skill file.
- `skills/sdlc/verify-spec/nonexistent.md` - Referenced missing file.

## Test plan
- Run lint check.

## Open questions
- None.
