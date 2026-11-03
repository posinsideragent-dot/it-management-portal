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
