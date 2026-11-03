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

## Look and layout

- The app opens in dark mode. Use the sun or moon button in the top bar, or Settings, to switch.
- The menu button at the top left collapses the sidebar to icons or expands it. Narrow windows always show icons only.
- On narrow windows the Tasks table becomes stacked cards. Widen the window to see the full table.

## Estimate revisions and documentation (Tasks, Details button)

- The original estimate is fixed once a task is accepted. To change it, the assigned person or a Team Lead chooses **Request revision** with the new hours and a reason.
- A Team Lead (or Management, Admin) then chooses **Approve revision** or **Refuse revision** (a reason is needed to refuse). The table shows the hours in force. A star means a revision is waiting.
- If a task needs documentation, the assigned person chooses **Submit documentation** and says where it is. A Team Lead chooses **Accept documentation** or **Send back** (with a reason). A Team Lead can also **Waive** it with a reason.
- A task cannot be approved as Completed until documentation is accepted, submitted or waived.
- A dot on the Details button means you have a step to do on that task.

## Time Tracker

- Open **Time Tracker** in the sidebar. It lists your tasks that are In Progress. Accept a task and choose **Start work** on the Tasks page first.
- **Start** begins a timer on a task. You can have only one timer at a time, on any PC.
- **Pause** stops the timer for now. **Resume** starts a new segment on the same task. **End job** stops the timer and asks what you did.
- While a timer runs, the top bar shows the task and the elapsed time. Click it to open the Time Tracker.
- If the app closes or the PC restarts, the timer keeps running. The app reads it from SharePoint when you sign in again.
- Ending a timer does not change the task status. Use **Submit for review** on the Tasks page when the work is finished.
- After a restart the app no longer remembers which task you paused. Press **Start** on the task again.
- Times come from your PC clock. Keep the clock correct.
