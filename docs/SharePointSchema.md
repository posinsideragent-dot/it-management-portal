# SharePoint Schema

Source: spec section 4. This file is the single reference for list and field names.
Create everything in ITDMP-DEV first. Production (ITDMP-PROD) copies the DEV schema after the gate passes.

**Phase 1 note:** create only `IT_Employees` and a throwaway `IT_PoC_Test` list at first. The other lists wait until the Phase 1 gate passes.

## Sites

| Environment | Site | Purpose |
|---|---|---|
| Development | ITDMP-DEV | Development, integration tests, UAT |
| Production | ITDMP-PROD | Real company operations |

URL pattern: `https://<tenant>.sharepoint.com/sites/ITDMP-DEV`. The admin supplies the tenant. Never test on production lists.

## Security groups

Three groups only. Roles (Management, TeamLead, Employee, Admin) are stored in `IT_Employees.AppRole`, not as SharePoint groups.

| Group | Permission level | Members |
|---|---|---|
| ITDMP-DEV Owners (built-in) | Full Control | Two company admins |
| ITDMP Management | Edit | Management users. With Owners, the only access to `IT_KPIRecords`. |
| ITDMP Members | Contribute | Programmers, IT staff, team leads |

The documentation libraries inherit from the site. There is no separate documentation group.

> **Warning:** create lists with `scripts/Create-ItdmpLists.ps1` (source: `scripts/itdmp_lists.json`). Never use "Create list from Excel": it names columns `field_N`. Keep the JSON file in sync with this document.

## Naming and relationships

- Relationships use text IDs, not Lookup columns.
- Never generate IDs from an item count. Use a collision-safe method and enforce uniqueness in SharePoint.
- ID formats: `EMP-0001`, `TASK-2026-00001`, `TIME-2026-00001`, `RPT-2026-00001`, `ISS-2026-00001`, `PRJ-2026-00001`, `DOC-2026-00001`, `KPI-2026-00001`.

| Parent | Child | Link |
|---|---|---|
| IT_Employees | IT_Tasks | EmployeeID = AssignedEmployeeID |
| IT_Employees | IT_TimeLogs, IT_DailyReports, IT_KPIRecords | EmployeeID |
| IT_Tasks | IT_TimeLogs | TaskCode |
| IT_Projects | IT_Tasks, IT_Issues, IT_DocumentRegister | ProjectCode |
| IT_Tasks | IT_DocumentRegister | TaskCode |

## List 1: IT_Employees

| Column | Type | Req | Notes |
|---|---|---|---|
| Title | Single line text | Yes | Display name |
| EmployeeID | Single line text | Yes | Unique |
| Email | Single line text | Yes | Must match the signed-in account |
| EntraObjectID | Single line text | Yes | Unique |
| JobTitle | Single line text | No | Programmer / IT Staff / Team Lead |
| Department | Choice | Yes | IT / Development |
| AppRole | Choice | Yes | Management / TeamLead / Employee / Admin |
| IsActive | Yes/No | Yes | Default Yes |
| JoinDate | Date only | No | |
| ManagerEmployeeID | Single line text | No | |
| CreatedAtUTC | Date and time | No | App-maintained |

Rules: EmployeeID and EntraObjectID are unique (turn on "Enforce unique values"; this needs the index). Turn on version history for this list: it is the audit trail. Inactive employees cannot start jobs. Never delete historical records.

## List 2: IT_Tasks

| Column | Type | Req | Notes |
|---|---|---|---|
| Title | Single line text | Yes | |
| TaskCode | Single line text | Yes | Unique |
| Description | Multiple lines | Yes | |
| TaskType | Choice | Yes | Development / Bug Fix / Support / Installation / Maintenance / Research / Internal IT |
| AssignedEmployeeID | Single line text | Yes | |
| CreatedByEmployeeID | Single line text | Yes | |
| ProjectCode | Single line text | No | |
| Priority | Choice | Yes | Low / Normal / High / Critical |
| Status | Choice | Yes | New / Accepted / In Progress / On Hold / Pending Review / Completed / Cancelled |
| EstimatedHours | Number | Yes | Initial estimate |
| RevisedEstimatedHours | Number | No | |
| PlannedStart | Date and time | No | |
| ExpectedCompletion | Date and time | Yes | |
| ActualStart | Date and time | No | First actual start |
| ActualCompletion | Date and time | No | |
| Progress | Number | Yes | 0-100 |
| BlockerRemarks | Multiple lines | No | |
| CompletionRemarks | Multiple lines | No | |
| DocumentationRequired | Yes/No | Yes | Default Yes where applicable |
| DocumentationStatus | Choice | Yes | Not Required / Pending / Submitted / Reviewed / Rejected |
| ReviewedByEmployeeID | Single line text | No | |
| LastProgressUpdateUTC | Date and time | No | |
| EstimateRevisionReason | Single line text | No | Added 2026-11-03. Why the estimate was revised. |
| EstimateApprovedBy | Single line text | No | Added 2026-11-03. EmployeeID of the approving Team Lead. |
| EstimateApprovedAtUTC | Date and time | No | Added 2026-11-03. |

Still optional (add only if needed, and document it): `TaskClosedBy`, `TaskClosedAtUTC`.

How the app uses `BlockerRemarks`: it holds the reason when a task is put On Hold, Cancelled, or returned from review. The status and SharePoint version history show which one it was.
A revised estimate waits for approval while `RevisedEstimatedHours` is set and `EstimateApprovedBy` is empty.

Rules:

- TaskCode is unique.
- A revised estimate never overwrites the initial estimate. It needs a reason and Team Lead approval.
- Completed tasks need completion remarks.
- Tasks needing documentation cannot be fully approved until it is submitted or formally waived.
- Cancelled tasks keep their history.

## List 3: IT_TimeLogs

| Column | Type | Req | Notes |
|---|---|---|---|
| Title | Single line text | Yes | |
| TimeLogCode | Single line text | Yes | Unique |
| EmployeeID | Single line text | Yes | |
| TaskCode | Single line text | Yes | |
| StartTimeUTC | Date and time | Yes | |
| EndTimeUTC | Date and time | No | |
| DurationMinutes | Number | No | Calculated |
| TimerStatus | Choice | Yes | Active / Completed / Corrected |
| ActiveTimerKey | Single line text | No | Unique while active |
| ActivityDescription | Multiple lines | No | |
| WorkResult | Multiple lines | No | |
| CorrectionReason | Multiple lines | No | Required for manual correction |
| CorrectedByEmployeeID | Single line text | No | |
| CorrectionApprovedBy | Single line text | No | |
| IsDeleted | Yes/No | Yes | Default No. Logical deletion only. |

Rules:

- TimeLogCode is unique.
- `ActiveTimerKey` must have the unique-values setting enabled. This is the main guard against two active timers.
- Active: set `ACTIVE|<EmployeeID>`. Completed: clear it.
- Never silently overwrite history. Corrections need a reason and audit data.
- Updates use ETag / If-Match.

## List 4: IT_DailyReports

| Column | Type | Req | Notes |
|---|---|---|---|
| Title | Single line text | Yes | |
| ReportCode | Single line text | Yes | Unique |
| EmployeeID | Single line text | Yes | |
| ReportDate | Date only | Yes | |
| PlannedActivities | Multiple lines | No | |
| CompletedActivities | Multiple lines | Yes | |
| PendingActivities | Multiple lines | No | |
| ProblemsEncountered | Multiple lines | No | |
| TomorrowPlan | Multiple lines | No | |
| TotalHours | Number | Yes | Calculated from time logs |
| SubmissionStatus | Choice | Yes | Draft / Submitted / Reviewed / Returned |
| ReviewedByEmployeeID | Single line text | No | |
| ReviewRemarks | Multiple lines | No | |
| SubmittedAtUTC | Date and time | No | |
| ReviewedAtUTC | Date and time | No | |

Rules: one report per employee per date. ReportCode is unique. Employees edit only their own drafts. Submitted reports are read-only unless returned.

## List 5: IT_Issues

| Column | Type | Req | Notes |
|---|---|---|---|
| Title | Single line text | Yes | |
| IssueCode | Single line text | Yes | Unique |
| Description | Multiple lines | Yes | |
| IssueType | Choice | Yes | Bug / Support / Infrastructure / Hardware / Software / Security / Blocker |
| Priority | Choice | Yes | Low / Normal / High / Critical |
| Status | Choice | Yes | Open / Assigned / Investigating / Waiting / Resolved / Closed |
| ReportedByEmployeeID | Single line text | Yes | |
| AssignedEmployeeID | Single line text | No | |
| RelatedTaskCode | Single line text | No | |
| ProjectCode | Single line text | No | |
| ResolutionRemarks | Multiple lines | No | |
| ReportedAtUTC | Date and time | Yes | |
| ResolvedAtUTC | Date and time | No | |

## List 6: IT_Projects

| Column | Type | Req | Notes |
|---|---|---|---|
| Title | Single line text | Yes | |
| ProjectCode | Single line text | Yes | Unique |
| Description | Multiple lines | No | |
| ProjectManagerEmployeeID | Single line text | Yes | |
| Status | Choice | Yes | Planning / Active / On Hold / Completed / Cancelled |
| Priority | Choice | Yes | Low / Normal / High / Critical |
| StartDate | Date only | No | |
| ExpectedCompletion | Date only | No | |
| ActualCompletion | Date only | No | |
| Progress | Number | Yes | 0-100 |
| ProjectRemarks | Multiple lines | No | |

## List 7: IT_DocumentRegister

| Column | Type | Req | Notes |
|---|---|---|---|
| Title | Single line text | Yes | |
| DocumentCode | Single line text | Yes | Unique |
| DocumentType | Choice | Yes | System / Technical / User Manual / Installation / API / Troubleshooting / Handover |
| RelatedProjectCode | Single line text | No | |
| RelatedTaskCode | Single line text | No | |
| OwnerEmployeeID | Single line text | Yes | |
| DocumentStatus | Choice | Yes | Draft / Submitted / Reviewed / Rejected / Archived |
| DocumentLocation | Hyperlink | Yes | SharePoint URL |
| VersionNumber | Single line text | No | |
| ReviewedByEmployeeID | Single line text | No | |
| ReviewDateUTC | Date and time | No | |
| ReviewRemarks | Multiple lines | No | |

## List 8: IT_KPIRecords

| Column | Type | Req | Notes |
|---|---|---|---|
| Title | Single line text | Yes | |
| KPIRecordCode | Single line text | Yes | Unique |
| EmployeeID | Single line text | Yes | |
| ReviewPeriodStart | Date only | Yes | |
| ReviewPeriodEnd | Date only | Yes | |
| TasksCompleted | Number | Yes | |
| TasksOverdue | Number | Yes | |
| EstimatedHours | Number | Yes | |
| ActualHours | Number | Yes | |
| DocumentationScore | Number | No | Management assessment |
| QualityScore | Number | No | Management assessment |
| OverallScore | Number | No | Management assessment |
| ManagementRemarks | Multiple lines | No | Private |
| ReviewedByEmployeeID | Single line text | Yes | |
| ApprovedAtUTC | Date and time | No | |

**Restrict this list to Management only.** Do not expose it to the Employees group.

## Document libraries

1. `IT_Project_Documents`
2. `IT_System_Documents`
3. `IT_Handover_Documents`

Metadata: DocumentCode, DocumentType, ProjectCode, TaskCode, OwnerEmployeeID, ReviewStatus, VersionNumber, LastReviewedDate.
Turn on version history and suitable retention.

Folders in `IT_System_Documents`: SQL Accounting Customisation, POS System, SQL Payroll, Time Management, Network and Infrastructure, Internal IT Procedures, Software Installation, Troubleshooting.

Folders in `IT_Handover_Documents`: Active Handover, Completed Handover, System Credentials Transfer Register, Deployment Procedures, Source Code References.

Never store passwords, API secrets, private keys or admin credentials in documents. Use the company password manager.

## Indexed columns

| List | Index these columns |
|---|---|
| IT_Employees | EmployeeID, EntraObjectID, Email, IsActive |
| IT_Tasks | TaskCode, AssignedEmployeeID, Status, ExpectedCompletion, ProjectCode |
| IT_TimeLogs | TimeLogCode, EmployeeID, TaskCode, StartTimeUTC, TimerStatus, ActiveTimerKey |
| IT_DailyReports | ReportCode, EmployeeID, ReportDate, SubmissionStatus |
| IT_Issues | IssueCode, Status, AssignedEmployeeID, Priority |
| IT_Projects | ProjectCode, Status, ProjectManagerEmployeeID |
| IT_DocumentRegister | DocumentCode, DocumentStatus, OwnerEmployeeID |
| IT_KPIRecords | KPIRecordCode, EmployeeID, ReviewPeriodStart |

The list view threshold is about 5,000 items for some operations. Use filtered queries on indexed columns and paging from day one. Never load all tasks or time logs at startup.

## Access matrix (intended)

| Resource | Management | Team Lead | Employee |
|---|---|---|---|
| IT_Employees | Manage | Read | Read limited profile data |
| IT_Tasks | Full | Manage team tasks | Read team tasks; update own assigned tasks |
| IT_TimeLogs | Full | Read team logs | Read team logs; create/update own active logs |
| IT_DailyReports | Full | Read/review team reports | Create/update own reports |
| IT_Issues | Full | Manage team issues | Read team issues; report issues |
| IT_Projects | Full | Manage assigned projects | Read relevant projects |
| IT_DocumentRegister | Full | Manage/review | Read and submit authorised documents |
| IT_KPIRecords | Full | No access by default | No access |
| IT_Project_Documents | Full | Read/write as authorised | Read/write as authorised |
| IT_System_Documents | Full | Read/write as authorised | Read as authorised |
| IT_Handover_Documents | Full | Read/write as authorised | Read/write as authorised |

SharePoint permissions are the security boundary. The Flutter role menus are only for usability.
Group-level access is enough for most rows. "Own records only" rules (for example time logs) are not proven yet. Test them with real accounts in Phase 1 step 9. If SharePoint cannot enforce them, a small secured API is needed later.

## Change log

Record every schema change here with a date and a migration note.

| Date | Change | Migration note |
|---|---|---|
| | | |
