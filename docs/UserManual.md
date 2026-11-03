# UserManual

Status: in progress. Sections are added as modules are built.

## Employees

Open **Employees** in the sidebar.

| Role | What you see |
|---|---|
| Management, Admin | All details. Add, edit, deactivate and reactivate employees. |
| Team Lead | All details. Read only. |
| Employee | Name, job title and department only. |

- **Search** looks only at the rows already loaded. Click **Load more** to load further rows.
- **Status** filter (Active, Inactive, All) is applied by SharePoint. The role filter works on loaded rows.
- **Add employee:** you need the person's Microsoft **Object ID** (Entra admin center, Users). The Employee ID (EMP-0001, EMP-0002 ...) is created for you.
- **Edit:** the Employee ID and Object ID cannot be changed.
- **Deactivate:** the person can no longer use ITDMP. The row and its history are kept. You cannot deactivate yourself or change your own role.
- If you see "Someone else changed this employee", reload the list and try again.
- The history of every change is in SharePoint (list version history).
