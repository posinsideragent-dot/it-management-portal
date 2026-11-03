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
- Tasks module step 2 (branch feature/tasks): estimate revisions (request, Team Lead approve or refuse; the original estimate never changes), documentation flow (submit, accept, send back, waive with reason), Details dialog, `TaskCapabilities` shared by the service and the screen, and a fix so changing "Documentation required" in the form resets the documentation status. New IT_Tasks columns `ProposedEstimatedHours` and `DocumentationRemarks` (run `scripts\Create-ItdmpLists.ps1 -Lists IT_Tasks`; it only adds the missing columns). `RevisedEstimatedHours` now holds only an approved revision. Tests in `test/task_step2_test.dart`. Not yet compiled or run.
- UI redesign (branch feature/tasks): dark mode by default with a light option (top bar button or Settings), collapsible sidebar (top bar menu button; icons only below 900 px wide), rounded row cards with padded columns, status chips, progress bars, and stacked cards for the Tasks table below 1000 px wide. Theme lives in `lib/core/theme/app_theme.dart`; UI state in `lib/state/ui_state.dart`; shared table parts in `lib/shared/widgets/`. The theme and sidebar choice last until the app closes (not saved). Not yet compiled.
- `scripts/Create-ItdmpLists.ps1` and `scripts/itdmp_lists.json`: create the SharePoint lists and columns with exact internal names through Graph. Replaces the Excel import, which produced `field_N` column names and was removed. AdminSetup-DEV.md Part I.
