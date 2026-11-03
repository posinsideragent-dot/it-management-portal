# Authentication

Status: **Option 1 checked on 2026-11-02: failed (no Windows support). Option 2 (Dart PKCE) passed on a real Windows PC on 2026-11-03 (5 of 6 gate checks; unauthorised-user check pending).**

## Decisions

- Each employee signs in with their own company Microsoft 365 account on their own Windows PC.
- The app uses delegated access for that person. SharePoint sees the real user and applies that user's permissions.
- The Microsoft admin account is for setup only: app registration, permission grants, site and list creation. It is never stored in or used by the app.
- Do not use shared admin accounts, embedded login forms, client secrets, or hardcoded tokens.

## Entra app registration

| Setting | Value |
|---|---|
| Type | Public client / native desktop |
| Tenant | Single tenant (company only) |
| Client secret | None |
| Redirect URI | Native desktop. `http://localhost` if using the loopback flow. |
| Graph permissions | `User.Read`, `Sites.Selected` (delegated) |
| Not allowed without security review | `Sites.ReadWrite.All` or any tenant-wide access |

The admin must approve the permissions and grant the app access to ITDMP-DEV only (and later ITDMP-PROD).
With `Sites.Selected` in the delegated case, access needs two things: the site grant for the app, and the user's own SharePoint permission. Test this with real accounts.

| Item | Value |
|---|---|
| Tenant ID | de1751f9-e541-4dca-9fff-9366ccd7a998 (read from the grant result; confirm on the Entra Overview page) |
| Client ID (DEV) | ed45bfb6-e005-40ba-8522-a53359e2a8dc |
| SharePoint site ID (DEV) | sqlacc.sharepoint.com,626945d6-16e9-4fdd-8ad3-993720800677,f601c7c7-e0ff-4907-b2b3-05941f3acecf |
| Site grant for ITDMP-DEV app | Done 2026-11-02. Role: write. Site ITDMP-DEV only. |
| List ID: IT_Employees (DEV) | 1b0bf4f3-5ef8-4907-9b99-66231cd23e4b |
| List ID: IT_PoC_Test (DEV) | 93137a60-b271-41d6-b84c-8666faae6be4 |
| List ID: IT_Tasks (DEV) | 7d068025-e4b7-4641-a171-537ff03a440f |
| Client ID (PROD) | _to fill_ |
| App owner (company admin) | _to fill_ |

## Sign-in options (try in order, stop at the first pass)

1. **Maintained Flutter MSAL package with Windows support.**
   Check the last update date and the Windows badge. Test a real Windows sign-in, not the Android demo.
2. **Pure Dart: authorization code flow with PKCE.**
   - Open the system browser.
   - Receive the code on a loopback address.
   - Exchange it for tokens in Dart.
   - Store the refresh token in Windows Credential Manager (for example `flutter_secure_storage`).
   - Our own code owns the token cache, so review it with extra care.
   - This differs from the spec's "Windows-native MSAL" wording. It needs management approval.
3. **C# helper through a platform channel.** Last resort, only if 1 and 2 fail.

Device code flow is for the proof of concept only, and only if the admin approves.

## Sign-in sequence

1. App starts and checks for a valid cached session.
2. If none, open the Microsoft sign-in in the system browser.
3. User signs in. Entra issues tokens for the delegated scopes.
4. App reads the user identity.
5. App looks up `EntraObjectID` in `IT_Employees`.
6. App checks `IsActive`.
7. App loads the role and opens the right workspace.

Unknown or inactive users are denied, with a message that names the administrator contact.

## Token rules

- No plain-text access tokens on disk.
- Use Windows protected storage for any stored sensitive state.
- Refresh tokens through the chosen auth method.
- Handle expired sessions (401) by signing in again.
- Provide sign-out. Clear all session state on sign-out.
- Never log tokens or auth responses.

## Spike results (fill in)

| Option | Tried on | Result | Notes |
|---|---|---|---|
| 1. Flutter MSAL package | 2026-11-02 (pub.dev check) | **Fail** | msal_auth 3.5.3: Android, iOS, macOS only. msal_auth_plugin 1.0.2: Android, iOS only. msal_flutter_auth 3.1.0: Android, iOS only. aad_oauth 1.0.1: mobile and web, last update Feb 2024. None lists Windows. desktopoauth2 1.0.4 (PKCE, localhost redirect) has an unverified publisher, 5 likes, about 2 years old: reference only, not a dependency. |
| 2. Dart PKCE | 2026-11-03 (Windows PC) | **Pass (5 of 6 gate checks)** | Sign-in, silent restore from saved session, identity match, read, create, update with ETag and 412 on old ETag all passed. Calls took 100-630 ms. Unauthorised-user denial still to test. Flutter SDK and pub cache must be in paths without spaces. | Own code: loopback listener (dart:io), url_launcher, crypto (SHA-256), flutter_secure_storage (Windows: encryption key in Credential Manager, values in encrypted files) |
| 3. C# helper | | | Only if needed |

**Chosen option:** _to fill_
**Reason:** _to fill_
**Management approval (if not MSAL):** _name and date_

## Unauthorised-user test (2026-11-03)

| Run | Account | Result |
|---|---|---|
| 1 | Test account in no ITDMP group, but found in the `ITDMP-DEV Owners` group | **Fail for the right reason.** SharePoint gave Full Control, so read, create and update all worked. The app check alone said DENIED. Found with Site permissions, Check Permissions. |
| 2 | Same account, removed from Owners | **Pass.** Graph returned HTTP 403 (accessDenied) for Who am I, Read employees and Create item, with the message "You do not have permission for this SharePoint data." Calls took 81-339 ms. |

Lesson: after adding any test or staff account, run Check Permissions on the site. The in-app check is a usability check only. SharePoint is the real boundary.
Per-user "own time logs only" enforcement (spec 7.2) is a separate test, still to do before the Time Tracker module.

## DEV list IDs (created by scripts/Create-ItdmpLists.ps1, 2026-11-03)

| List | ID |
|---|---|
| IT_Employees | 1b0bf4f3-5ef8-4907-9b99-66231cd23e4b |
| IT_Tasks | 7d068025-e4b7-4641-a171-537ff03a440f |
| IT_TimeLogs | 88173a38-5dfe-4e22-be71-1cc97234f4c0 |
| IT_DailyReports | ab3c6386-b43f-47d8-8c74-561e7025006e |
| IT_Issues | a36dc426-9285-4fed-9cdf-14323917da19 |
| IT_Projects | cf974b02-9106-4091-8e08-9036c79b488c |
| IT_DocumentRegister | 1c950db0-ed66-42b9-a652-3d6eec8e4e1a |
| IT_KPIRecords | a8290c21-eeee-45a5-870c-2d13923b1d4b |
