# Architecture

## Overview

**Flutter Windows Desktop -> Microsoft Entra ID -> Microsoft Graph / SharePoint REST -> SharePoint Online**

Supporting parts:

- Power Automate: notifications and scheduled reports only. It is not the real-time timer.
- GitHub: source code, review and releases.
- Claude Code: development help only. No AI at runtime in Version 1.

SharePoint is the only business-data store in Version 1. No external or local database.

## Technology

| Part | Choice |
|---|---|
| UI | Flutter, Fluent UI for Flutter |
| State | Riverpod |
| Routing | go_router |
| Models | Freezed, json_serializable |
| HTTP | Dio or an equivalent maintained client |
| Auth | Microsoft Entra ID (see `Authentication.md`) |
| Data | SharePoint Lists and Document Libraries |
| API | Microsoft Graph first, SharePoint REST when needed |
| Installer | MSIX |
| Tests | flutter_test, integration_test |

Package rule: use maintained packages with verified Windows support. Pin versions. Commit `pubspec.lock`.

## Rules

1. UI widgets never call Graph directly.
2. All SharePoint access goes through repositories and services.
3. Business rules live in services, not in UI code.
4. A dedicated auth service handles sign-in.
5. List and field names live in one central config.
6. Store dates in UTC. Show Malaysia time (UTC+8).
7. Every API operation handles loading, success, empty and error states.
8. Important changes are auditable.
9. No credentials or secrets in source code.
10. No local database as a second source of truth.

## Layers

| Layer | Job | Must not |
|---|---|---|
| UI | Screens, forms, tables, dialogs, navigation, charts | Call SharePoint or hold business rules |
| State (Riverpod) | Hold and expose app state | Become one giant provider |
| Service | Business rules: validation, status changes, timer rules, report and KPI math, UI permission checks | Know HTTP details |
| Repository | Data access: CRUD, queries, paging, ETags, uploads | Hide API failures |
| API client | Graph and REST calls, auth header, retries, throttling, error mapping | Log tokens |
| Model | Typed Dart models with `fromJson`, `toJson`, validation, date handling | Use `dynamic` where a type fits |

## Project structure

```text
lib/
  main.dart, app.dart, spike_main.dart (sign-in spike only)
  state/         Riverpod providers and the session controller
  routing/       go_router config and route paths
  core/          authentication, configuration, errors, logging, utilities
  data/          api (graph_client, sharepoint_rest_client, api_error_handler), repositories, dto
  models/        employee, task, time_log, daily_report, issue, project, document, kpi_record
  services/      employee, task, timer, report, issue, project, document, kpi
  features/      dashboard, employee_management, task_management, time_tracking,
                 daily_reports, issue_management, project_management, documentation, kpi_management
  shared/        widgets, layouts, themes, validators
  routing/
windows/  test/  integration_test/  docs/  scripts/
```

## App shell and sign-in flow (Phase 1, steps 6-7)

| Part | File | Job |
|---|---|---|
| Entry | `lib/main.dart`, `lib/app.dart` | `ProviderScope`, Fluent theme, `go_router` |
| Providers | `lib/state/providers.dart` | Wires config, auth, Graph client, repositories, session |
| Session rules | `lib/services/session_service.dart` | Sign in, read `/me`, find the Object ID in `IT_Employees`, block unknown or inactive users |
| Session state | `lib/services/session_state.dart` | Checking, SignedOut, SigningIn, Blocked, Failed, Active |
| Router | `lib/routing/app_router.dart` | Redirects signed-out users to the sign-in page. Usability only, not security. |
| Shell | `lib/shared/layouts/app_shell.dart` | Sidebar, top bar, page body |
| Pages | `lib/features/*` | Sign in, Dashboard, Time Tracker (start, pause, resume, end), Settings |

A blocked user's saved session is cleared. A server or network error is shown as a failure and keeps the session, so the user can retry.
The sign-in spike test page is still available: `flutter run -d windows -t lib/spike_main.dart`.

## Employees module

| Layer | Files |
|---|---|
| Presentation | `lib/features/employee_management/` (list page, form dialog) |
| State | `employee_list_controller.dart`, `employee_list_state.dart` |
| Service | `lib/services/employee_service.dart` (rules), `employee_validator.dart`, `employee_ids.dart`, `employee_access.dart` |
| Repository | `lib/data/repositories/employee_repository.dart` (`EmployeeDirectory` interface) |
| Models | `employee.dart`, `employee_draft.dart`, `employee_page.dart`, `app_role.dart` |

Decisions:
- **Audit:** SharePoint version history on `IT_Employees` (no separate audit list yet).
- **Duplicates:** `EmployeeID` and `EntraObjectID` enforce unique values in SharePoint. A failed create is safe to retry with a new number, because nothing was saved. This is the duplicate guard instead of a separate operation ID column.
- **Roles:** checked in the service for usability. SharePoint permissions are the real boundary. `ITDMP Members` can edit rows in SharePoint, so a determined member could bypass the app. Decide on list or item permissions before production.
- **Paging:** Graph `@odata.nextLink`. The link is followed only if it points to `graph.microsoft.com`.
- **Search and role filter** work on loaded rows. Only the Active/Inactive filter runs in SharePoint.

## Tasks module (step 1)

| Layer | Files |
|---|---|
| Presentation | `lib/features/task_management/` (list page, form, status and progress dialogs) |
| State | `task_list_controller.dart`, `task_list_state.dart` |
| Service | `lib/services/task_service.dart`, `task_workflow.dart` (the only status table), `task_validator.dart`, `task_codes.dart`, `task_access.dart`, `task_variance.dart` |
| Repository | `lib/data/repositories/task_repository.dart` (`TaskDirectory` interface) |
| Models | `task_item.dart`, `task_draft.dart`, `task_enums.dart`, `task_page.dart` |

Decisions:
- **Status changes** go through `TaskWorkflow`. Assignee: accept, start, hold, resume, submit. Team Lead, Management and Admin: cancel, approve, return.
- **Reasons** for hold, cancel and return are saved in `BlockerRemarks` with a prefix (`On hold:`, `Cancelled:`, `Returned:`). Version history keeps the earlier text.
- **TaskCode** is the highest code plus one, restarting each Malaysia year. SharePoint rejects duplicates, and the service retries up to 3 times.
- **Original estimate** is editable only while the task is New. Revised estimates arrive in step 2.
- **Actual hours** are not shown yet. They must come from time logs. Time Tracker step 2 adds the per-task total.
- Server-side filters: Status and AssignedEmployeeID (indexed). Search runs on loaded rows.

## Workspaces

One codebase, three role-based workspaces: Management, Team Lead, Employee.
Role menus are for usability only. SharePoint permissions are the real security boundary.

## Graph client

One reusable client handles: base URL, auth header, token retrieval, timeout, retry, error handling, paging, and safe logging.

Pattern: `https://graph.microsoft.com/v1.0/sites/{site-id}/lists/{list-id}/items`
Read with `expand=fields` and `$top`. Verify field payloads against the real list schema.

Error handling:

| Code | Meaning | App action |
|---|---|---|
| 401 | Token expired | Refresh or sign in again |
| 403 | No permission | Clear message to the user |
| 404 | Not found | Report missing item or list |
| 409 | Conflict or duplicate unique value | Handle per case (for example active timer) |
| 412 | ETag mismatch | Reload and ask the user |
| 429 | Throttled | Respect `Retry-After`, bounded backoff |
| 5xx, network, timeout | Service or connection problem | Retry safely, then show an error |

Do not blindly retry creates. Use an operation ID so a retry cannot make a duplicate.

## Time tracking design (summary)

- One active timer per employee, enforced by the unique `ActiveTimerKey` column.
- Pause closes the current segment. Resume starts a new segment for the same task.
- The app reads the active timer from SharePoint at startup. It never trusts memory alone.
- Updates use ETag / If-Match.
- `IT_TimeLogs` is the source of truth for actual hours.
- Client timestamps are not tamper-proof. If management needs that, add a small secured API later.

Full rules: spec section 10.

## Known open risks

- Per-user "own records only" enforcement in SharePoint is unproven. Test in Phase 1 step 9.
- `Sites.Selected` in the delegated case needs real-account testing.
- Sign-in method may differ from the spec's MSAL wording. See `Authentication.md`.
