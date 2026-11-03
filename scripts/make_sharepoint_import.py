"""Builds docs/import/ITDMP_SharePoint_Lists_Import.xlsx.

The workbook has one Excel table per SharePoint list, so each list can be
created with: SharePoint > New > List > From Excel.
The schema below must match docs/SharePointSchema.md. Change both together,
then run:  python scripts/make_sharepoint_import.py
"""
from datetime import date, datetime, timedelta
from pathlib import Path

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.utils import get_column_letter
from openpyxl.worksheet.table import Table, TableStyleInfo

OUT = Path(__file__).resolve().parent.parent / "docs/import/ITDMP_SharePoint_Lists_Import.xlsx"
FONT = "Arial"

# type: text | multiline | number | datetime | date | bool | choice | hyperlink
# A column is (name, type, required, extra) where extra is a dict with any of:
#   unique, index, default, choices, note
def col(name, type_, req=False, **extra):
    return {"name": name, "type": type_, "req": req, **extra}

PRIORITY = ["Low", "Normal", "High", "Critical"]

LISTS = {
    "IT_Tasks": [
        col("Title", "text", True),
        col("TaskCode", "text", True, unique=True, index=True),
        col("Description", "multiline", True),
        col("TaskType", "choice", True, choices=["Development", "Bug Fix", "Support", "Installation", "Maintenance", "Research", "Internal IT"]),
        col("AssignedEmployeeID", "text", True, index=True),
        col("CreatedByEmployeeID", "text", True),
        col("ProjectCode", "text", False, index=True),
        col("Priority", "choice", True, choices=PRIORITY, default="Normal"),
        col("Status", "choice", True, choices=["New", "Accepted", "In Progress", "On Hold", "Pending Review", "Completed", "Cancelled"], default="New", index=True),
        col("EstimatedHours", "number", True, note="Initial estimate. Minimum 0."),
        col("RevisedEstimatedHours", "number", False, note="Minimum 0."),
        col("PlannedStart", "datetime", False),
        col("ExpectedCompletion", "datetime", True, index=True),
        col("ActualStart", "datetime", False),
        col("ActualCompletion", "datetime", False),
        col("Progress", "number", True, default="0", note="Minimum 0, maximum 100."),
        col("BlockerRemarks", "multiline", False),
        col("CompletionRemarks", "multiline", False),
        col("DocumentationRequired", "bool", True, default="Yes"),
        col("DocumentationStatus", "choice", True, choices=["Not Required", "Pending", "Submitted", "Reviewed", "Rejected"], default="Pending"),
        col("ReviewedByEmployeeID", "text", False),
        col("LastProgressUpdateUTC", "datetime", False),
        col("EstimateRevisionReason", "text", False, note="Added 2026-11-03."),
        col("EstimateApprovedBy", "text", False, note="Added 2026-11-03. EmployeeID of the approving Team Lead."),
        col("EstimateApprovedAtUTC", "datetime", False, note="Added 2026-11-03."),
    ],
    "IT_TimeLogs": [
        col("Title", "text", True),
        col("TimeLogCode", "text", True, unique=True, index=True),
        col("EmployeeID", "text", True, index=True),
        col("TaskCode", "text", True, index=True),
        col("StartTimeUTC", "datetime", True, index=True),
        col("EndTimeUTC", "datetime", False),
        col("DurationMinutes", "number", False, note="Calculated by the app."),
        col("TimerStatus", "choice", True, choices=["Active", "Completed", "Corrected"], index=True),
        col("ActiveTimerKey", "text", False, unique=True, index=True, note="MAIN GUARD against two active timers. Holds ACTIVE|<EmployeeID> while active, empty when the segment ends."),
        col("ActivityDescription", "multiline", False),
        col("WorkResult", "multiline", False),
        col("CorrectionReason", "multiline", False, note="Required for manual correction (enforced by the app)."),
        col("CorrectedByEmployeeID", "text", False),
        col("CorrectionApprovedBy", "text", False),
        col("IsDeleted", "bool", True, default="No", note="Logical deletion only."),
    ],
    "IT_DailyReports": [
        col("Title", "text", True),
        col("ReportCode", "text", True, unique=True, index=True),
        col("EmployeeID", "text", True, index=True),
        col("ReportDate", "date", True, index=True, note="Date only. One report per employee per date (enforced by the app)."),
        col("PlannedActivities", "multiline", False),
        col("CompletedActivities", "multiline", True),
        col("PendingActivities", "multiline", False),
        col("ProblemsEncountered", "multiline", False),
        col("TomorrowPlan", "multiline", False),
        col("TotalHours", "number", True, note="Calculated from time logs."),
        col("SubmissionStatus", "choice", True, choices=["Draft", "Submitted", "Reviewed", "Returned"], default="Draft", index=True),
        col("ReviewedByEmployeeID", "text", False),
        col("ReviewRemarks", "multiline", False),
        col("SubmittedAtUTC", "datetime", False),
        col("ReviewedAtUTC", "datetime", False),
    ],
    "IT_Issues": [
        col("Title", "text", True),
        col("IssueCode", "text", True, unique=True, index=True),
        col("Description", "multiline", True),
        col("IssueType", "choice", True, choices=["Bug", "Support", "Infrastructure", "Hardware", "Software", "Security", "Blocker"]),
        col("Priority", "choice", True, choices=PRIORITY, default="Normal", index=True),
        col("Status", "choice", True, choices=["Open", "Assigned", "Investigating", "Waiting", "Resolved", "Closed"], default="Open", index=True),
        col("ReportedByEmployeeID", "text", True),
        col("AssignedEmployeeID", "text", False, index=True),
        col("RelatedTaskCode", "text", False),
        col("ProjectCode", "text", False),
        col("ResolutionRemarks", "multiline", False),
        col("ReportedAtUTC", "datetime", True),
        col("ResolvedAtUTC", "datetime", False),
    ],
    "IT_Projects": [
        col("Title", "text", True),
        col("ProjectCode", "text", True, unique=True, index=True),
        col("Description", "multiline", False),
        col("ProjectManagerEmployeeID", "text", True, index=True),
        col("Status", "choice", True, choices=["Planning", "Active", "On Hold", "Completed", "Cancelled"], default="Planning", index=True),
        col("Priority", "choice", True, choices=PRIORITY, default="Normal"),
        col("StartDate", "date", False, note="Date only."),
        col("ExpectedCompletion", "date", False, note="Date only."),
        col("ActualCompletion", "date", False, note="Date only."),
        col("Progress", "number", True, default="0", note="Minimum 0, maximum 100."),
        col("ProjectRemarks", "multiline", False),
    ],
    "IT_DocumentRegister": [
        col("Title", "text", True),
        col("DocumentCode", "text", True, unique=True, index=True),
        col("DocumentType", "choice", True, choices=["System", "Technical", "User Manual", "Installation", "API", "Troubleshooting", "Handover"]),
        col("RelatedProjectCode", "text", False),
        col("RelatedTaskCode", "text", False),
        col("OwnerEmployeeID", "text", True, index=True),
        col("DocumentStatus", "choice", True, choices=["Draft", "Submitted", "Reviewed", "Rejected", "Archived"], default="Draft", index=True),
        col("DocumentLocation", "hyperlink", True, note="NOT in the import. Add by hand after import: Add column > More > Hyperlink, name DocumentLocation, required."),
        col("VersionNumber", "text", False),
        col("ReviewedByEmployeeID", "text", False),
        col("ReviewDateUTC", "datetime", False),
        col("ReviewRemarks", "multiline", False),
    ],
    "IT_KPIRecords": [
        col("Title", "text", True),
        col("KPIRecordCode", "text", True, unique=True, index=True),
        col("EmployeeID", "text", True, index=True),
        col("ReviewPeriodStart", "date", True, index=True, note="Date only."),
        col("ReviewPeriodEnd", "date", True, note="Date only."),
        col("TasksCompleted", "number", True),
        col("TasksOverdue", "number", True),
        col("EstimatedHours", "number", True),
        col("ActualHours", "number", True),
        col("DocumentationScore", "number", False, note="Management assessment."),
        col("QualityScore", "number", False, note="Management assessment."),
        col("OverallScore", "number", False, note="Management assessment."),
        col("ManagementRemarks", "multiline", False, note="Private."),
        col("ReviewedByEmployeeID", "text", True),
        col("ApprovedAtUTC", "datetime", False),
    ],
}

SP_TYPE = {
    "text": "Single line of text",
    "multiline": "Multiple lines of text",
    "number": "Number",
    "datetime": "Date and time",
    "date": "Date and time, then set Date only",
    "bool": "Yes/No",
    "choice": "Choice",
    "hyperlink": "Hyperlink (add by hand)",
}

LIST_NOTES = {
    "IT_Tasks": "Tasks. Used by the Tasks module.",
    "IT_TimeLogs": "Time logs. ActiveTimerKey must be unique (set Index first, then Enforce unique values).",
    "IT_DailyReports": "Daily reports. Employees edit only their own drafts (app rule).",
    "IT_Issues": "Technical issues.",
    "IT_Projects": "Projects.",
    "IT_DocumentRegister": "Document register. Add the DocumentLocation hyperlink column by hand.",
    "IT_KPIRecords": "MANAGEMENT ONLY. Remove access for ITDMP Members before adding any data.",
}

HEADER_FILL = PatternFill("solid", fgColor="1F4E78")
HEADER_FONT = Font(name=FONT, bold=True, color="FFFFFF")
BODY = Font(name=FONT, size=10)
BOLD = Font(name=FONT, size=10, bold=True)
NOTE_FILL = PatternFill("solid", fgColor="FFF2CC")


def sample_value(c, i, n):
    """A realistic value so SharePoint detects the type and all choices."""
    t, name = c["type"], c["name"]
    base = datetime(2026, 11, 3, 9, 0) + timedelta(days=i)
    if t == "choice":
        return c["choices"][i % len(c["choices"])]
    if t == "number":
        return float(10 * (i + 1)) if "Progress" in name else float(i + 1)
    if t == "datetime":
        return base
    if t == "date":
        return base.date()
    if t == "bool":
        return False
    if name == "Title":
        return f"DELETE ME {i + 1}"
    if name.endswith("Code") or name == "ActiveTimerKey":
        return f"DELETE-ME-{i + 1}"
    if name.endswith("EmployeeID") or name.endswith("EmployeeId") or name in ("ApprovedBy", "EstimateApprovedBy", "CorrectionApprovedBy"):
        return "EMP-0001"
    if t == "multiline":
        return "Sample text. Delete this row."
    return "sample"


def sheet_for_list(wb, list_name, columns):
    cols = [c for c in columns if c["type"] != "hyperlink"]
    n = max([len(c.get("choices", [])) for c in cols] + [1])
    ws = wb.create_sheet(list_name)
    ws.append([c["name"] for c in cols])
    for i in range(n):
        ws.append([sample_value(c, i, n) for c in cols])
    for j, c in enumerate(cols, start=1):
        width = max(len(c["name"]) + 4, 18)
        ws.column_dimensions[get_column_letter(j)].width = min(width, 32)
        cell = ws.cell(row=1, column=j)
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL
        for r in range(2, n + 2):
            body = ws.cell(row=r, column=j)
            body.font = BODY
            if c["type"] == "datetime":
                body.number_format = "yyyy-mm-dd hh:mm"
            elif c["type"] == "date":
                body.number_format = "yyyy-mm-dd"
    ref = f"A1:{get_column_letter(len(cols))}{n + 1}"
    table = Table(displayName=list_name, ref=ref)
    table.tableStyleInfo = TableStyleInfo(name="TableStyleMedium2", showRowStripes=True)
    ws.add_table(table)
    ws.freeze_panes = "B2"
    return n


def add_rows(ws, rows, widths, header=True):
    for r in rows:
        ws.append(r)
    for idx, w in enumerate(widths, start=1):
        ws.column_dimensions[get_column_letter(idx)].width = w
    for row in ws.iter_rows():
        for cell in row:
            cell.font = BODY
            cell.alignment = Alignment(wrap_text=True, vertical="top")
    if header:
        for cell in ws[1]:
            cell.font = HEADER_FONT
            cell.fill = HEADER_FILL
    ws.freeze_panes = "A2"


def build():
    wb = Workbook()
    readme = wb.active
    readme.title = "READ ME FIRST"

    rows_per_list = {}
    for name, cols in LISTS.items():
        rows_per_list[name] = sheet_for_list(wb, name, cols)

    # --- Settings sheet
    st = wb.create_sheet("Settings after import")
    st.append(["List", "Column", "Type in SharePoint", "Required", "Enforce unique values", "Index it", "Default value", "Choice values", "Notes"])
    for name, cols in LISTS.items():
        for c in cols:
            st.append([
                name, c["name"], SP_TYPE[c["type"]],
                "Yes" if c["req"] else "No",
                "Yes" if c.get("unique") else "",
                "Yes" if c.get("index") else "",
                c.get("default", ""),
                ", ".join(c.get("choices", [])),
                c.get("note", ""),
            ])
    add_rows(st, [], [22, 26, 28, 10, 14, 10, 14, 60, 60])
    st.auto_filter.ref = f"A1:I{st.max_row}"

    # --- Libraries sheet
    lib = wb.create_sheet("Libraries (by hand)")
    add_rows(lib, [
        ["Library", "Create as", "Metadata columns to add", "Folders to create", "Settings"],
        ["IT_Project_Documents", "Document library", "DocumentCode, DocumentType, ProjectCode, TaskCode, OwnerEmployeeID, ReviewStatus, VersionNumber, LastReviewedDate", "(none listed in the schema)", "Version history on. Inherit site permissions."],
        ["IT_System_Documents", "Document library", "Same as above", "SQL Accounting Customisation; POS System; SQL Payroll; Time Management; Network and Infrastructure; Internal IT Procedures; Software Installation; Troubleshooting", "Version history on. Inherit site permissions."],
        ["IT_Handover_Documents", "Document library", "Same as above", "Active Handover; Completed Handover; System Credentials Transfer Register; Deployment Procedures; Source Code References", "Version history on. Inherit site permissions. Never store passwords or secrets here."],
        ["", "", "", "", ""],
        ["Note", "Libraries cannot be imported from Excel. Create them by hand when the Documents module starts. The schema does not yet define the choice values of DocumentType and ReviewStatus for libraries: agree them before creating those columns.", "", "", ""],
    ], [26, 20, 60, 70, 46], header=False)
    for cell in lib[1]:
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL

    # --- README
    lines = [
        ["ITDMP: import the remaining SharePoint lists (site ITDMP-DEV)"],
        [""],
        ["What this file does"],
        ["Each sheet named IT_... holds one Excel table. SharePoint turns that table into a list with the same columns and the same Choice values."],
        ["Lists in this file: " + ", ".join(LISTS)],
        ["Already done by you, so not here: IT_Employees and IT_PoC_Test."],
        [""],
        ["Steps for EACH list (about 3 minutes)"],
        ["1. Open the ITDMP-DEV site. Site contents > New > List > From Excel."],
        ["2. Upload this file. Choose the table with the list name (for example IT_Tasks)."],
        ["3. Name the list EXACTLY as the table name, for example IT_Tasks (capital IT, underscore, no spaces)."],
        ["4. In the preview, check each column's type against the sheet 'Settings after import' (column 'Type in SharePoint'). Change the type if SharePoint guessed wrong. Multiple lines of text and Yes/No are the usual ones to check."],
        ["5. For Choice columns, check that every choice value is listed. They come from the sample rows."],
        ["6. Click Create."],
        ["7. DELETE the sample rows. They are named DELETE ME 1, DELETE ME 2 and so on. Do this before turning on unique values."],
        ["8. Apply the rest of the sheet 'Settings after import': required, indexes, unique values, defaults. The import cannot set these."],
        ["9. List settings > Versioning settings: create a version each time an item is edited (this is the audit trail)."],
        [""],
        ["Do these in order for unique columns"],
        ["First Index the column. Then open the column and set Enforce unique values to Yes. SharePoint refuses unique values on a column that is not indexed."],
        [""],
        ["Security: do this for IT_KPIRecords BEFORE adding data"],
        ["List settings > Permissions for this list > Stop inheriting permissions. Remove ITDMP Members. Keep ITDMP-DEV Owners and ITDMP Management only. Then run Site permissions > Check Permissions for a non-management test account: it must show no access."],
        [""],
        ["After the import"],
        ["IT_DocumentRegister: add the hyperlink column DocumentLocation by hand (see the Settings sheet)."],
        ["IT_Tasks: send the List ID to the developer. Graph Explorer: GET /sites/{site-id}/lists?$filter=displayName eq 'IT_Tasks'  or copy it from the list settings address (List={...})."],
        ["Three document libraries are in the sheet 'Libraries (by hand)'. They cannot be imported."],
        [""],
        ["Limits of the import (so nothing surprises you)"],
        ["The import creates columns and Choice values. It does NOT set: required, unique, indexed, default values, number minimum and maximum, or Date only. These are listed per column in 'Settings after import'."],
        ["Choice column order and the default value follow SharePoint's rules, not this file."],
        ["Source of truth: docs/SharePointSchema.md. This file is generated by scripts/make_sharepoint_import.py."],
    ]
    for r in lines:
        readme.append(r)
    readme.column_dimensions["A"].width = 150
    for row in readme.iter_rows():
        for cell in row:
            cell.font = BODY
            cell.alignment = Alignment(wrap_text=True, vertical="top")
    for idx in (1, 3, 8, 19, 22, 25, 30):
        readme.cell(row=idx, column=1).font = Font(name=FONT, size=12 if idx > 1 else 14, bold=True)
    readme.cell(row=1, column=1).fill = NOTE_FILL

    OUT.parent.mkdir(parents=True, exist_ok=True)
    wb.save(OUT)
    return rows_per_list


if __name__ == "__main__":
    counts = build()
    print(f"Wrote {OUT}")
    for name, n in counts.items():
        print(f"  {name}: {n} sample rows")
