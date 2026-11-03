# Troubleshooting

Status: in progress. See also the table at the end of `SpikeRunbook.md`.

## Employees

| Message | Likely cause and fix |
|---|---|
| Load fails with HTTP 400 mentioning an index | `EmployeeID` or `IsActive` is not indexed. See Part G of `AdminSetup-DEV.md`. |
| Load fails with HTTP 400 on the status filter | SharePoint did not accept `IsActive eq 1`. Report the full message. The filter may need `eq true`. |
| Adding an employee shows HTTP 400 about a choice | `Department` or `AppRole` choices do not match the app. See Part G. |
| Adding the same person twice is not refused | Unique values are not enforced. See Part G. |
| A duplicate shows an unexpected error instead of "already registered" | Graph reported the duplicate in a form the app does not recognise. Report the status and message. |
| Join date is one day off | SharePoint returned the date-only value shifted by the time zone. Report it. |

## Tasks

| Message | Likely cause and fix |
|---|---|
| Load fails with HTTP 404 or "list not found" | `tasksListId` in `app_config.dart` is empty or wrong. Create the list (Part H of `AdminSetup-DEV.md`) and send the List ID. |
| HTTP 400 mentioning an index | `TaskCode`, `AssignedEmployeeID` or `Status` is not indexed. See Part H. |
| HTTP 400 on a choice value | The Choice values in SharePoint do not match the app. See Part H. |
| "unexpected format or year" when creating | A TaskCode in the list is not `TASK-YYYY-NNNNN`, or this PC's clock is behind the newest code. |
| A task shows 1 Jan 1970 as due date | `ExpectedCompletion` is empty on that row. Fill it in SharePoint. |
| "A provided field name is not recognized" when saving | The list was created with "From Excel", so its columns are named `field_N`. Check with `/_api/web/lists/getbytitle('IT_Tasks')/fields?$select=InternalName,Title&$filter=Hidden eq false`. Delete the list and recreate it with `scripts/Create-ItdmpLists.ps1` (AdminSetup-DEV.md Part I). |
