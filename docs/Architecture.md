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
  main.dart, app.dart
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
