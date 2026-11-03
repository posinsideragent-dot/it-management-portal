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
| Estimate or documentation action fails with "field name is not recognized" | `ProposedEstimatedHours` or `DocumentationRemarks` is missing in IT_Tasks. Run the script for IT_Tasks (AdminSetup-DEV.md Part J). |
| Start fails with a duplicate or "already have a timer" | A timer is already running, possibly on another PC. Open Time Tracker, then Pause or End it. If none is shown, check `ActiveTimerKey` in IT_TimeLogs (the old row must have an empty key). |
| Time Tracker fails with HTTP 400 mentioning an index | `EmployeeID`, `TaskCode`, `StartTimeUTC`, `TimerStatus` or `ActiveTimerKey` is not indexed in IT_TimeLogs. Re-run the list script. |
| Timer cannot be ended: "clock is earlier than the start time" | This PC's date or time is wrong. Fix it and try again. |
| Details shows "Hours used: Not available" | The task has no start or submit date saved. Tasks made before these dates were added show this. New tasks save them when accepted, started and submitted. Also check the 4 new IT_Tasks columns exist (AdminSetup-DEV.md Part J). |
| New report fails with "You already have a report" | A report for that day exists (maybe a Draft). Find it in the list and choose Edit. |
| Daily Reports fails to load with HTTP 400 | `EmployeeID`, `ReportDate`, `SubmissionStatus` or `ReportCode` is not indexed in IT_DailyReports. Re-run the list script. If only the sort fails, tell IT: the list is sorted by ReportDate in SharePoint. |
| Daily Reports: "field name is not recognized" | A column in IT_DailyReports has a wrong internal name (made from Excel). Delete and recreate the list with the script. |
