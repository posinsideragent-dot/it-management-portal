# Authentication

Status: **Option 1 checked on 2026-11-02: failed (no Windows support). Option 2 (Dart PKCE) is next and must be tested on a real Windows PC.**

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
| 2. Dart PKCE | | _pending Windows test_ | Own code: loopback listener (dart:io), url_launcher, crypto (SHA-256), flutter_secure_storage (Windows: encryption key in Credential Manager, values in encrypted files) |
| 3. C# helper | | | Only if needed |

**Chosen option:** _to fill_
**Reason:** _to fill_
**Management approval (if not MSAL):** _name and date_
