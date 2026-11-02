# IT & Development Management Portal (ITDMP)

Internal Flutter Windows desktop app. Data lives in SharePoint Online. Sign-in uses Microsoft Entra ID.

**Status:** Phase 1, proof of concept. See `docs/Phase1Plan.md`.

## Read first

- `CLAUDE.md`: rules for Claude Code and developers
- `docs/Phase1Plan.md`: current plan and gate checklist
- `docs/Architecture.md`: layers and rules
- `docs/SharePointSchema.md`: lists, fields, indexes, access
- `docs/Authentication.md`: sign-in decision record

## Rules in short

- Company owns this repo. At least two admins.
- Never push to `main`. Use feature branches and pull requests.
- No secrets, tokens or passwords in the repo.
- Update docs with every significant change.
