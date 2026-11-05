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

- The app opens in light mode. Use the sun or moon button in the top bar, or Settings, to switch to dark mode. The choice lasts until the app closes.
- A task can carry the customer's company name, Attn and contact number (all optional; leave them empty for internal tasks). Planned start and expected completion are dates only, read as Malaysia dates. A task is overdue only after its due day has ended.
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

## Dates, hours used and variance (Tasks, Details button)

- The Timeline shows when the task was accepted, started, submitted for review (the job ends here) and approved. Times are Malaysia time.
- **Hours used** counts only office hours: Monday to Friday, 09:00 to 18:00. Nights, weekends, time On Hold and time waiting in review are not counted. Public holidays and lunch are not removed.
- **Variance** is hours used minus the original estimate. Red means over. Green means under or on.
- While the task is In Progress the hours are "so far". After submit for review they stop.
- Tasks made before 3 Nov 2026 may show "Not available" because the dates were not saved.

## Daily Reports

- Open **Daily Reports** in the sidebar and choose **New report**. Pick the date, type the total hours worked (0 to 24) and what you completed. The other boxes are optional.
- **Save draft** keeps it private to you. **Save and submit** sends it for review. You can have only one report per day.
- A Draft or Returned report can be edited. A Submitted or Reviewed report is read-only. The report date cannot be changed. Create the report for the right day.
- A Team Lead, Management or Admin opens **Review**, then chooses **Accept report** or **Send back** (a reason is needed). If it is sent back, the reason shows when you edit it. Fix it and submit again.
- Team Leads can turn off "My reports only" to see everyone's reports. Use the status filter to find Submitted reports.

## Issues

- Open **Issues** and choose **Report issue**. Anyone can report. Give a title, description, type and priority. A related task code and a project code are optional.
- A Team Lead, Management or Admin opens the issue (**Open** button) and chooses **Assign**. The issue becomes Assigned.
- The assigned person chooses **Start investigating**, then **Set to waiting** (say what you wait for) or **Mark resolved** (say what fixed it).
- The reporter or a Team Lead then chooses **Confirm and close**, or **Reopen** with a reason if it is not fixed.
- A Team Lead can **Close without fixing** with a reason (for example, a duplicate). Closed issues cannot change.
- The reporter can edit an Open issue. A Team Lead can edit any issue that is not Closed.
- Use "Assigned to me" to see your issues. The latest note shows in the issue's details.

## Dashboard

The dashboard opens first. Click **Refresh** to load the latest data.

Four cards count the tasks. Click a card to see its list.

| Card | What it counts |
|---|---|
| Pending accept | Tasks with status New. The assignee has not accepted yet. |
| Start work | Tasks with status Accepted. Accepted but not started. |
| Almost due | Open tasks due in 1 to 3 days (Malaysia dates). |
| Due | Open tasks due today or already late. Late ones are in red. |

Tasks waiting for review (Pending Review) are not counted as due, because the work is finished.

**Who sees what**
- Team Lead, Management and Admin see all tasks.
- Everyone else sees only the tasks assigned to them.

**Notifications** list what needs your action. Click one to open the right page.
- *To review* (Team Lead, Management, Admin): tasks waiting for review, estimate revisions to approve, documentation to review, new issues to assign, resolved issues to confirm, and submitted daily reports.
- *Your actions* (everyone): tasks to accept or start, documentation sent back, issues assigned to you, your resolved issues to confirm, a returned daily report. On weekdays from 16:00 (Malaysia) it also reminds you if today's daily report is missing or still a draft.

Notifications show only what is in the app. They do not send email or Teams messages yet; that comes with Power Automate.
