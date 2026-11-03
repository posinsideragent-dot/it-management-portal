# Admin Setup: ITDMP-DEV (Phase 1, steps 2 to 4)

Who does this: a Microsoft 365 / Entra admin of the `sqlacc` tenant.
Tenant: `https://sqlacc.sharepoint.com`
Time needed: about 1 to 2 hours.

**Never share an admin password with anyone, including Claude.** Do the steps yourself and send back only the values in the last section.

## Part A. Create the DEV site (step 2)

1. Open the SharePoint admin center: `https://sqlacc-admin.sharepoint.com`.
2. Go to Sites, then Active sites, then Create, then Team site.
3. Name: `ITDMP-DEV`. URL: `https://sqlacc.sharepoint.com/sites/ITDMP-DEV`. Privacy: Private.
4. Owners: add both company admins (at least two).

## Part B. Set up 3 groups (step 2)

Keep it small. Use the site's built-in Owners group and create only 2 new groups.
Roles such as Team Lead live in `IT_Employees.AppRole`, not in SharePoint groups.

On the site: Settings (gear), Site permissions, Advanced permissions settings.

| Group | Permission level | Members |
|---|---|---|
| ITDMP-DEV Owners (built-in) | Full Control | The two company admins |
| ITDMP Management (create) | Edit | Management users |
| ITDMP Members (create) | Contribute | All programmers, IT staff and team leads. For Phase 1: the authorised test account. |

Notes:
- After the Phase 1 gate, restrict `IT_KPIRecords` to Owners and Management only (stop inheriting permissions on that list).
- The **unauthorised test account must not be in any of these groups**, and must not be a member or visitor of the site.
- Trade-off: with one Members group, SharePoint cannot stop one member editing another member's time log. Step 9 of the plan tests this. If it fails, the fix is a small secured API (spec section 7.2), not more groups.

## Part C. Create the two lists (step 3)

Create these on `ITDMP-DEV` only. Do not create the other 7 lists yet.

### IT_Employees

| Column | Type | Required | Notes |
|---|---|---|---|
| Title | Single line text | Yes | Display name (default column) |
| EmployeeID | Single line text | Yes | Index it. Turn on "Enforce unique values". |
| Email | Single line text | Yes | |
| EntraObjectID | Single line text | Yes | Index it. Turn on "Enforce unique values". |
| JobTitle | Single line text | No | |
| Department | Choice | Yes | IT, Development |
| AppRole | Choice | Yes | Management, TeamLead, Employee, Admin |
| IsActive | Yes/No | Yes | Default Yes |
| JoinDate | Date only | No | |
| ManagerEmployeeID | Single line text | No | |
| CreatedAtUTC | Date and time | No | |

Tip: SharePoint only allows "Enforce unique values" on an indexed column. Index the column first (List settings, Indexed columns), then edit the column.

### IT_PoC_Test (throwaway)

| Column | Type | Notes |
|---|---|---|
| Title | Single line text | Default column |
| TestNote | Multiple lines of text | |
| TestStatus | Choice | New, Updated |

Exact field names are in `docs/SharePointSchema.md`. Use the internal names exactly as written (no spaces).

### Add the test employee rows

Add one row to `IT_Employees` for each test account:
- Authorised account: `IsActive` = Yes, `AppRole` = Employee.
- Unauthorised account: do **not** add a row for it. The app must reject it.

`EntraObjectID` comes from Entra admin center, Users, the user, Object ID.

## Part D. Register the Entra app (step 4)

1. Open `https://entra.microsoft.com`, then App registrations, then New registration.
2. Name: `ITDMP-DEV`. Supported account types: **Accounts in this organizational directory only** (single tenant).
3. Redirect URI: platform **Mobile and desktop applications**, value `http://localhost`.
4. After creating it, go to Authentication and set "Allow public client flows" to **Yes**. (Needed for the proof of concept sign-in options.)
5. Do **not** create a client secret.
6. Go to API permissions, then Add a permission, then Microsoft Graph, then **Delegated permissions**. Add:
   - `User.Read`
   - `Sites.Selected`
7. Click "Grant admin consent for sqlacc".
8. Under Owners, add both company admins.
9. Do not add `Sites.ReadWrite.All` or any tenant-wide permission.

## Part E. Give the app access to ITDMP-DEV only (step 4)

`Sites.Selected` gives no access until an admin grants the app a role on the site. Pick one method.

**Option 1: PnP PowerShell** (needs a PnP app registration for the admin to connect):

```powershell
Connect-PnPOnline -Url "https://sqlacc-admin.sharepoint.com" -Interactive -ClientId <PnP-app-id>
Grant-PnPAzureADAppSitePermission -AppId <ITDMP-DEV client id> `
  -DisplayName "ITDMP-DEV" `
  -Site "https://sqlacc.sharepoint.com/sites/ITDMP-DEV" `
  -Permissions Write
```

**Option 2: Microsoft Graph** (caller needs `Sites.FullControl.All`, for example in Graph Explorer as an admin):

```http
POST https://graph.microsoft.com/v1.0/sites/{site-id}/permissions
{
  "roles": ["write"],
  "grantedToIdentities": [
    { "application": { "id": "<ITDMP-DEV client id>", "displayName": "ITDMP-DEV" } }
  ]
}
```

Find the site ID with: `GET https://graph.microsoft.com/v1.0/sites/sqlacc.sharepoint.com:/sites/ITDMP-DEV`

How access works for a signed-in user (delegated): the user gets only what both allow, the app's site grant **and** the user's own SharePoint permission. So an unauthorised user is blocked even though the app has a grant.

## Part F. Test accounts

- **Account 1 (authorised):** member of `ITDMP Members`, and a row in `IT_Employees`.
- **Account 2 (unauthorised):** in none of the ITDMP groups and not on the site.

Use real company accounts made for testing. Do not use the admin accounts for the tests.

## Send back these values (no passwords)

| Item | Value |
|---|---|
| Tenant ID (directory ID) | |
| Client ID of `ITDMP-DEV` | |
| Site ID of ITDMP-DEV | |
| List ID of IT_Employees | |
| List ID of IT_PoC_Test | |
| Object ID of Account 1 | |
| Object ID of Account 2 | |
| Names of the two company admins | |

## Done checklist

- [ ] Site `ITDMP-DEV` exists, 2+ owners
- [ ] Owners confirmed, 2 groups created (Management, Members)
- [ ] `IT_Employees` and `IT_PoC_Test` created, unique columns set
- [ ] Test rows added
- [ ] Entra app registered, single tenant, no secret, public client flows on
- [ ] `User.Read` and `Sites.Selected` consented
- [ ] App granted Write on ITDMP-DEV only
- [ ] Two test accounts ready
