# Deployment

## Environments

| Name | Site | Build |
|---|---|---|
| DEV | ITDMP-DEV | `flutter run -d windows` (default) |
| PROD | ITDMP-PROD | add `--dart-define=ITDMP_ENV=PROD` |

If a PROD build starts with empty IDs, the app shows "The PROD settings are
incomplete" and lists what is missing.

## Build the PROD release

```powershell
git checkout main
git pull
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build windows --release --dart-define=ITDMP_ENV=PROD
```

Output: `build\windows\x64\runner\Release\`. Zip the whole folder (the .exe needs
the DLLs and `data` folder beside it). Name it `ITDMP-PROD-<version>-<date>.zip`.

## Install on a PC

1. Unzip to a fixed folder, for example `C:\ITDMP`.
2. Create a shortcut to the `.exe` in that folder.
3. First start: sign in with the company Microsoft account.

## Update

Close the app, unzip the new version over the old folder, start again. Tokens
are in Windows Credential Manager and stay valid.

## Roll back

Keep the previous zip. Close the app, unzip the previous version over the folder.
SharePoint data is not changed by the app version. If a new version added
columns, the old version ignores them.

## Go-live checklist

- [ ] `AdminSetup-PROD.md` Parts A-G done
- [ ] `AppConfig.prod` filled in and merged through a pull request
- [ ] `flutter analyze` and `flutter test` pass
- [ ] Management approval for Dart PKCE recorded in `Authentication.md`
- [ ] Real employees loaded with EntraObjectID
- [ ] 403 test with a non-group account passed
- [ ] Version history on in every list
- [ ] Graph Command Line Tools consent (Sites.Manage.All) removed after the script
- [ ] Two GitHub admins, 2FA on, `main` protected
- [ ] Release zip stored in a company location
