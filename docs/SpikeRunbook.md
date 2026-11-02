# Spike Runbook: Windows sign-in and SharePoint test (Phase 1)

Run this on a **Windows 10/11 PC**. The code was written without being compiled, so expect to fix small errors on the first build. Send the error text and it will be fixed.

## 1. Install the tools (once)

- Flutter SDK (stable). Add it to PATH.
- Visual Studio 2022 with the workload **Desktop development with C++**. In the details panel, also tick **C++ ATL for latest build tools** (needed by flutter_secure_storage).
- Git.

**Install Flutter and the pub cache in folders without spaces**, for example `C:\dev\flutter` and `C:\dev\pub_cache` (set the user environment variable `PUB_CACHE=C:\dev\pub_cache`). A space in the path, such as a Windows user name like `SQL Mysoftware`, breaks native-asset builds.

Check with `flutter doctor`. The Windows and Visual Studio lines must be green.

## 2. Get the code

```powershell
git clone https://github.com/posinsideragent-dot/it-management-portal
cd it-management-portal
git checkout feature/auth-spike
```

## 3. Create the Windows project files

The repo has the Dart code but not the Windows runner folder. Generate it:

```powershell
flutter create --platforms=windows --project-name it_management_portal .
del test\widget_test.dart
git status
```

- `flutter create` does not overwrite existing files. `git status` should show new `windows/`, `pubspec.yaml` and similar files only.
- If `lib/main.dart` shows as modified, restore it: `git checkout -- lib/main.dart`.
- `test\widget_test.dart` is deleted because it refers to a screen that does not exist.

## 4. Add the packages

```powershell
flutter pub add http crypto url_launcher flutter_secure_storage
flutter analyze
flutter test
```

- `flutter test` runs the PKCE checks. They must pass.
- Fix any `flutter analyze` errors before continuing. Send me the text if you are stuck.
- Commit `pubspec.yaml` and `pubspec.lock` so the versions are pinned.

## 5. Run it

```powershell
flutter run -d windows
```

A window with buttons opens. If Windows Firewall asks about the app, allow it for private networks. The sign-in uses a local address on this PC only.

## 6. Test as Account 1 (authorised)

Use a **company work account** in the `sqlacc` tenant, for example `name@sqlacc.onmicrosoft.com`, that is in `ITDMP Members` and has a row in `IT_Employees`.

| # | Click | Expected |
|---|---|---|
| 1 | Sign in | Browser opens. Sign in as Account 1. The log says "Signed in." |
| 2 | Who am I | "ALLOWED" with the name, role and a matching Object ID |
| 3 | Read employees | The rows of `IT_Employees` |
| 4 | Create test item | "Created item" with an ETag |
| 5 | Update with ETag | "Updated item" with a new ETag |
| 6 | Update with old ETag | "PASS" (HTTP 412) |

Then check in SharePoint that the `IT_PoC_Test` item shows `TestStatus = Updated`.

## 7. Test as Account 2 (unauthorised)

Click **Sign out**, then **Sign in** and choose Account 2. It must be a work account in the tenant that is in **no** ITDMP group.

| # | Click | Expected |
|---|---|---|
| 1 | Who am I | "FAILED ... HTTP 403" (no permission), or "DENIED" if reading works but the row is missing |
| 2 | Read employees | "FAILED ... HTTP 403" with the message about permission |

## 8. Send back the log

Click **Copy log** and paste it to me. Check that it holds no passwords. The app never writes tokens to it.

The log shows the time each call took in milliseconds. This is the speed test for the SharePoint slowness question. Call each button 2 or 3 times.

## Gate checklist (spec 19.1)

- [ ] Windows Microsoft login works (6.1)
- [ ] Delegated SharePoint access works (6.3)
- [ ] Create and read a list item (6.3, 6.4)
- [ ] Update a list item, with ETag (6.5, 6.6)
- [ ] Correct user identity retrieved (6.2)
- [ ] Unauthorised user is denied (7)

## If something fails

| Message | Likely cause and fix |
|---|---|
| `AADSTS50011` (reply URL does not match) | The Entra redirect URI must be under **Mobile and desktop applications** with the value `http://localhost` (no port, no slash). |
| `AADSTS7000218` (client secret or assertion needed) | In Entra, Authentication, set **Allow public client flows** to **Yes**. |
| `AADSTS65001` (consent needed) | Grant admin consent for `User.Read` and `Sites.Selected` on the app. |
| `AADSTS50020` or `AADSTS50034` | The account is not in the `sqlacc` tenant. Use a work account made in the tenant, not a personal Gmail. |
| HTTP 403 for Account 1 on Read employees | The app grant or the account's site permission is missing. Check Part B and Part E of `AdminSetup-DEV.md`. |
| HTTP 400 on Who am I mentioning the filter or index | `EntraObjectID` is not indexed. Index it in List settings. |
| HTTP 412 never appears in test 6 | SharePoint ignored If-Match. Report it. This changes the concurrency design. |
| Browser opens but the app never continues | A firewall or security tool blocked the local address. Report it. |
| `'C:\Users\SQL' is not recognized` and `Building native assets for package:objective_c failed` | The Flutter SDK or pub cache is in a path with a space. Move Flutter to `C:\dev\flutter`, set `PUB_CACHE=C:\dev\pub_cache`, update PATH, then run `flutter clean` and `flutter pub get`. |
| Build error mentioning ATL | Install the "C++ ATL" component in Visual Studio. |

## 9. Run the app shell (branch feature/app-shell)

```powershell
git fetch
git checkout feature/app-shell
flutter pub add fluent_ui flutter_riverpod go_router
flutter pub get
flutter analyze
flutter test
flutter run -d windows
```

- The spike test page is still available: `flutter run -d windows -t lib/spike_main.dart`.
- Expected: a sign-in card. After Microsoft sign-in the sidebar shell opens with Dashboard, Time Tracker and Settings. The top bar shows your name.
- A work account that is not in `IT_Employees`, or is inactive, must see an "Access denied" message.
- After the first successful build, commit `pubspec.yaml`, `pubspec.lock`, `windows/` and `analysis_options.yaml` so the project can be built from the repo.

## Rules while testing

- Never paste passwords into chat, files or commits.
- Do not commit `build/` or local files. `.gitignore` already covers them.
- Test only on `ITDMP-DEV`.
