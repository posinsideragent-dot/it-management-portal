# ITDMP Phase 1 Plan: Proof of Concept

**Goal:** Pass the six checks in spec section 19.1 before building any module.
**Why:** Sign-in and SharePoint permissions are the biggest risks. If they fail, the design must change.
**Time:** About 1 to 2 weeks (Weeks 1-2 of the schedule).

## Decisions (agreed)

1. **Who signs in.** Each employee signs in with their own company Microsoft account on their own Windows PC. The app uses that person's delegated access. The Microsoft admin account is used only for setup (app registration, permission grants, site and list creation). The admin account is never stored in or used by the app at runtime.
   - Reason: the spec bans shared admin accounts, and SharePoint can only enforce "own records only" if it knows who the user is.
2. **Keep it in Flutter/Dart.** Use Dart or Flutter packages only. A C# helper is the last resort, used only if the Dart options fail the spike.

## Before coding (needs the company admin)

- [ ] Real tenant URL
- [ ] A Microsoft Entra admin who can approve app permissions
- [ ] Two company GitHub admins
- [ ] Two test accounts: one authorised, one in no ITDMP group
- [ ] Flutter SDK, Visual Studio (Desktop development with C++) and Git on the dev PC

## Steps

| # | Step | Output |
|---|---|---|
| 1 | Create the company GitHub repo `it-management-portal`. Protect `main`. Add `CLAUDE.md` and the docs skeleton. | Company-owned repo |
| 2 | Create the ITDMP-DEV site and set up 3 groups (built-in Owners, ITDMP Management, ITDMP Members). | DEV site ready |
| 3 | Create only `IT_Employees` and a throwaway `IT_PoC_Test` list. The other 7 lists wait until the gate passes. | 2 lists |
| 4 | Register the Entra app: public client, single tenant, no secret. Request `User.Read` and `Sites.Selected`. The admin grants the app access to ITDMP-DEV only. | Client ID, tenant ID |
| 5 | **Authentication spike (timebox 2 days).** Try the options in the order below. | Decision in `Authentication.md` |
| 6 | Create the Flutter Windows project: Fluent shell, Riverpod, go_router, DEV/PROD config. | Empty app that runs |
| 7 | Sign in, read the user identity, look up `EntraObjectID` in `IT_Employees`. Block unknown or inactive users. | Login works |
| 8 | Build the Graph client. Read `IT_Employees`. Create one test item. Update it using an ETag. | Read, create, update work |
| 9 | Sign in as the unauthorised user. Confirm a clear 403 message. | Permission denial proven |
| 10 | Write the full setup guide so another person can repeat it. | Docs in repo |

Do step 5 first. It is the highest risk, so a bad result should stop the work early.

## Step 5 detail: authentication options

Try in this order. Stop at the first one that passes.

1. **A maintained Flutter MSAL package with Windows support.** Check the package page, last update date and the Windows platform badge. Test a real sign-in on Windows. Do not trust the Android/iOS demo.
2. **Pure Dart: authorization code flow with PKCE.** Open the system browser. Receive the code on a loopback address (`http://localhost`). Exchange it for tokens in Dart. Store the refresh token in Windows Credential Manager (for example with `flutter_secure_storage`).
   - This is still the PKCE flow the spec asks for. It is not the MSAL library, so the token cache is our own code.
   - Rules: no client secret, no embedded login form, never log tokens, clear everything on sign-out.
   - The spec (sections 6.2 and 20) names Windows-native MSAL. Record this change in `Authentication.md` and get management approval.
3. **C# helper through a platform channel.** Use this only if 1 and 2 both fail.

Device code flow is allowed for the proof of concept only, and only if the admin approves.

## Gate checklist (section 19.1)

- [x] Windows Microsoft login works
- [x] Delegated SharePoint access works
- [x] Create and read a list item
- [x] Update a list item
- [x] Correct user identity retrieved
- [ ] Unauthorised user is denied

Do not start full module work until every box is ticked.

## Risks

- **No Windows MSAL package.** The pure Dart PKCE route covers this, but we own more security code.
- **`Sites.Selected` may not fit.** In the delegated case it needs a site grant for the app and the user's own SharePoint permissions. Test with real accounts in step 9.
- **Waiting on the admin.** Steps 2 and 4 depend on them. Ask first.
- **Per-user enforcement.** The spec says SharePoint must stop one employee editing another's time logs (section 7.2). Test this early in step 9. If it cannot be done, a small secured API is needed later.

## Open items

- Name of the Entra admin and whether they have been asked
- Tenant URL
- Management approval if we replace MSAL with Dart PKCE
