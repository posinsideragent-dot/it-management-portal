# ChangeLog

## Unreleased

- Repo created with CLAUDE.md and the docs skeleton (Phase 1, step 1).
- Admin setup runbook for ITDMP-DEV; SharePoint groups reduced from 5 to 3.
- Auth spike option 1 (Flutter MSAL package) failed: no Windows support.
- Auth spike option 2 code (Dart PKCE sign-in, Graph client, test page). Not yet compiled or tested on Windows. See docs/SpikeRunbook.md.
- Phase 1 spike result: 5 of 6 gate checks passed on Windows. Unauthorised-user check deferred by the project owner.
- Phase 1 steps 6-7 (branch feature/app-shell): Fluent shell, Riverpod, go_router, sign-in page, identity lookup against `IT_Employees`, blocked-user handling, Malaysia time helper, tests. Not yet compiled; see docs/SpikeRunbook.md section 9.
