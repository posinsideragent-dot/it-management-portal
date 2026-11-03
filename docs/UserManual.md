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

## Tasks

Open **Tasks** in the sidebar. All times are Malaysia time.

| Role | What you can do |
|---|---|
| Team Lead, Management, Admin | Create and edit tasks, cancel, approve or return work that is in review |
| Employee | Read all tasks. On your own tasks: accept, start, put on hold, resume, update progress, submit for review |

- **Status path:** New, Accepted, In Progress, Pending Review, Completed. A task can also be On Hold or Cancelled. Completed and Cancelled tasks are final.
- Putting a task on hold, cancelling it, returning it, or submitting it for review asks for a reason or remarks.
- The **estimated hours** are the original estimate. They can change only while the task is New.
- **Approving** needs completion remarks. If documentation is required, it must be submitted or waived first (the documentation step comes in the next release, so tasks that need documentation cannot be approved yet).
- **My tasks** shows only tasks assigned to you. The status filter and My tasks run in SharePoint. Search looks at the loaded rows only.
- A red due date means the task is overdue.
