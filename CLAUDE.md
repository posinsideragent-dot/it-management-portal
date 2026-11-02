# CLAUDE.md: ITDMP Project Instructions

## Role

You are the senior Flutter Windows desktop engineer for the IT & Development Management Portal (ITDMP).
Write code that is maintainable, secure, modular and well documented.
The company owns this app. Other programmers must be able to maintain it without the original developer.

## Project objective

Build an internal portal for a Malaysian software reseller with about 2-3 programmers and 1 IT staff member.
It manages:

- Employees and roles
- Task assignment
- Estimated and actual hours
- Start Job / End Job, Pause / Resume
- Daily work reports
- Technical issues
- Projects
- Technical documentation
- Management dashboard
- KPI records

## Fixed technology

- Flutter for Windows desktop, Dart
- Microsoft Fluent-style UI
- Riverpod for state, go_router for routing
- Freezed / json_serializable where suitable
- Microsoft Entra ID sign-in
- Microsoft Graph as the main API. SharePoint REST only when necessary.
- SharePoint Online Lists as the only database. SharePoint Document Libraries for files.
- Power Automate for notifications and scheduled flows
- GitHub for source control

Do not add Firebase, Supabase, MySQL, PostgreSQL, or SQLite as a business database.
Do not add any other cloud database, hosting service or backend without management approval.

## Current phase

We are in Phase 1: proof of concept. Read `docs/Phase1Plan.md`.
Do not build full modules until the six checks in spec section 19.1 pass.

## Architecture rules

Use these layers: presentation, state, service (business logic), repository, API/data access, authentication, model.

- Never put SharePoint API calls in UI widgets.
- Never put complex business rules in UI widgets.
- Use typed Dart models.
- Keep SharePoint list and field names in one central config.
- Use interfaces with separate implementation classes. Use dependency injection where it helps.
- Store all dates in UTC. Show them in Malaysia time (UTC+8).
- Every API operation must handle loading, success, empty and error states.
- Important changes must be auditable.
- No local database may become a second source of truth.

## SharePoint rules

- Lists: IT_Employees, IT_Tasks, IT_TimeLogs, IT_DailyReports, IT_Issues, IT_Projects, IT_DocumentRegister, IT_KPIRecords.
- Libraries: IT_Project_Documents, IT_System_Documents, IT_Handover_Documents.
- Use the exact fields in `docs/SharePointSchema.md`. Do not invent fields without documenting the change.
- Use text IDs for relationships. Avoid extra Lookup columns.
- Use pagination and indexed filters. Never assume a list is small enough to load whole.
- Handle throttling (429, `Retry-After`) and ETag conflicts (412).
- Do not blindly retry create requests. Use an operation ID to prevent duplicates.

## Authentication and security

- Employees sign in with their own company Microsoft account. The app uses delegated access for that user.
- The admin account is for setup only. Never store it in the app or use it at runtime.
- Never embed client secrets, passwords or access tokens. Never log tokens.
- Do not bypass SharePoint permissions. UI role checks are not security.
- KPI data stays Management-only.
- Employees must not edit another employee's time logs.
- Test authentication on a real Windows machine.

Authentication order (see `docs/Authentication.md`):

1. A maintained Flutter MSAL package with verified Windows support.
2. Pure Dart authorization code flow with PKCE, system browser, loopback redirect, tokens in Windows Credential Manager.
3. A C# helper through a platform channel. Last resort.

Option 2 differs from the spec's "Windows-native MSAL" wording. It needs management approval and a note in `docs/Authentication.md`.
If an option fails, stop and report it. Do not quietly switch to an insecure approach.

## Time tracking rules

- One active timer per employee.
- `ActiveTimerKey` must be unique. Use `ACTIVE|<EmployeeID>` while active. Clear it when the segment ends.
- Support Start, Pause, Resume, End, recovery after restart, and manual correction with a reason.
- On login, read the active timer from SharePoint. Never rely on a stopwatch held only in memory.
- Use UTC. Show Malaysia time.
- Use ETag checks on updates.
- Never silently overwrite history.
- Do not claim client timestamps are tamper-proof.

## Task rules

- Keep the original estimate when a revised estimate is approved.
- Validate status transitions.
- Completed tasks need completion remarks.
- Required documentation must be submitted or formally waived before final approval.
- ActualHours come from time logs.

## UI rules

- Sidebar navigation, top bar, dashboard cards, data tables, search and filters.
- Clear status indicators and confirmation dialogs for important actions.
- Loading indicators, error messages and empty states.
- Make the Time Tracker easy to reach and show the active task clearly.
- Keep navigation simple.

## Coding standards

- Null safety. Clear names. Small focused functions. No giant files or widgets.
- No duplicated business logic.
- Handle exceptions explicitly. Never silently catch and ignore errors.
- Avoid `dynamic` where a typed model fits.
- Follow Dart and Flutter lints.
- Write tests for business-critical logic.

## GitHub and documentation

- Branches: `main`, `development`, `feature/*`, `bugfix/*`, `hotfix/*`.
- Never push directly to `main`. Use feature branches and pull requests.
- Update docs with every significant change: README.md, CLAUDE.md, and in `docs/`: Architecture, SharePointSchema, Authentication, Deployment, Troubleshooting, UserManual, ChangeLog.

## Development process

Before coding a module:

1. Read the project structure, this file, the architecture doc and the SharePoint schema.
2. Identify dependencies, affected files, security impact and needed tests.
3. Propose a plan.

Then build in small steps. After building:

1. Run `flutter analyze` and the relevant tests.
2. Build the Windows release.
3. Check for regressions.
4. Update docs.
5. Summarise changed files, what was tested, and the remaining risks.

Do not rewrite working modules without a clear reason.
Do not change the schema without documenting the migration.
Do not say something works unless it was tested.

## Most important instruction

Build a maintainable, company-owned system. Do not build a quick prototype that only its original developer understands.
