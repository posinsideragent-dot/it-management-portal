# Admin setup: ITDMP-PROD

For the Microsoft 365 admin. Do this once, before go-live. The admin account is
for setup only; the app never uses it.

**Do not copy the DEV site or its lists.** DEV holds test data and test-account
permissions, and each list gets new IDs anyway. A copied list can also lose its
unique and indexed settings. Recreate the structure with the script, then load
only the real data.

## Part A. Create the site and groups

1. Create a SharePoint team or communication site named **ITDMP-PROD**
   (private, not a Microsoft 365 group site if you want the groups below to control access).
2. Create the same 3 security groups as DEV (see `AdminSetup-DEV.md`, Part B) and
   add the real people. Use the same role names.
3. Do not add test accounts to PROD.

## Part B. Get the PROD site ID

Open Graph Explorer as the admin and run:

`GET https://graph.microsoft.com/v1.0/sites/sqlacc.sharepoint.com:/sites/ITDMP-PROD`

Copy the `id` value (three parts separated by commas).

## Part C. Create the lists

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\scripts\Create-ItdmpLists.ps1 -SiteId "<PROD site id>" -WhatIf   # check first
.\scripts\Create-ItdmpLists.ps1 -SiteId "<PROD site id>" -UseDeviceCode
```

Send back the List ID table. Then add `DocumentLocation` (Hyperlink) to
`IT_DocumentRegister` by hand (Graph rejects it).

## Part D. Permissions on the PROD site

1. Break inheritance and set:
   - `IT_Employees`: Members **Read** only; Management and Admin Contribute.
   - `IT_KPIRecords`: Management only. No other group.
   - Other lists: Members Contribute.
2. Turn on **version history** on every list (List settings, Versioning settings).
   This is the audit trail.
3. Create the document libraries `IT_Project_Documents`, `IT_System_Documents`,
   `IT_Handover_Documents` with version history on.

## Part E. Let the same Entra app reach PROD

The app registration is shared with DEV, so the client ID and redirect URI do
not change. Grant it the PROD site (Sites.Selected, read and write) with the
same method used for DEV (`AdminSetup-DEV.md`, Part D). Do this for the PROD
site ID only.

## Part F. Load the real employees

Add each real employee to `IT_Employees` with their `EntraObjectID`, role and
Active status. The first Management/Admin person can be added by hand in
SharePoint; the rest can be added in the app.

## Part G. Test before go-live

- Sign in with a real employee: the dashboard opens.
- Sign in with an account that is in no ITDMP group: the app shows a clear 403 message.
- A Member cannot edit `IT_Employees` directly in SharePoint.
- A Member cannot open `IT_KPIRecords`.

## Part H. Put the IDs in the app

Developer: fill `AppConfig.prod` in `lib/core/configuration/app_config.dart`
(site ID and list IDs), commit on a feature branch, open a pull request.
IDs are not secrets. Never put tokens or passwords there.
