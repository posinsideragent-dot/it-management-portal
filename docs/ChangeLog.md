# ChangeLog

## Unreleased

- Repo created with CLAUDE.md and the docs skeleton (Phase 1, step 1).
- Admin setup runbook for ITDMP-DEV; SharePoint groups reduced from 5 to 3.
- Auth spike option 1 (Flutter MSAL package) failed: no Windows support.
- Auth spike option 2 code (Dart PKCE sign-in, Graph client, test page). Not yet compiled or tested on Windows. See docs/SpikeRunbook.md.
- Phase 1 spike result: 5 of 6 gate checks passed on Windows. Unauthorised-user check deferred by the project owner.
- Phase 1 steps 6-7 (branch feature/app-shell): Fluent shell, Riverpod, go_router, sign-in page, identity lookup against `IT_Employees`, blocked-user handling, Malaysia time helper, tests. Built and run on Windows on 2026-11-03: analyze clean, app opens, sign-in shell works.
- Phase 1 gate: all six checks passed on 2026-11-03. Unauthorised user gets HTTP 403 from SharePoint.
- Employees module (branch feature/employees): list with paging, add, edit, deactivate, validation, app-level role checks, tests. Not yet compiled or run.
- Docs: IT_Employees indexes added to the schema; Part G (admin steps) added to AdminSetup-DEV.md.
- Tasks module step 1 (branch feature/tasks): task list with paging and filters, create, edit, status workflow with reasons, progress, TaskCode generation, estimate lock, tests. Admin Part H added. IT_Tasks gets 3 audit columns (EstimateRevisionReason, EstimateApprovedBy, EstimateApprovedAtUTC). Not yet compiled or run; needs the IT_Tasks list and its List ID.
- Shared `GraphException.isDuplicateValue` replaces the private check in the Employees service.
- Excel import file for the 7 remaining SharePoint lists (`docs/import/`) and its generator `scripts/make_sharepoint_import.py`. AdminSetup-DEV.md Part I.
