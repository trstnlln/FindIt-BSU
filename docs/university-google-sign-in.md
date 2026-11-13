# Automatic university account names

The login and registration screens offer **Continue with Google**. After Google authentication, Firebase verifies the sign-in token. The
app accepts a verified `g.batstate-u.edu.ph` email or an administrator-approved staff identity, imports the Google
provider's display name and optional profile photo, and writes the profile under
the Firebase UID. It never tries to derive a name from a student number or email
address, and never asks for the user's Google password inside the app.

This assumes the university uses Google Workspace. It imports the Google account
name, which is not necessarily a legal name or an authoritative student registry
record. An official registrar name would require an authorized university
directory integration. If Google provides no name, the app explains that the
student can use email/password registration and enter it manually.

New campus Google registrations receive the `student` role. Approved staff receive the `staff` role. Returning users keep their
existing role and account creation date; signing in cannot promote an account.
Existing profile metadata is preserved with a transaction and merged write.
Email/password registration remains available and continues to ask for a name.
A typed university email alone cannot look up its owner's name.

## Firebase project setup

These settings belong to the Firebase project and are not enabled by pushing code:

1. Open **Firebase Console → finditbsu → Authentication → Sign-in method**.
2. Confirm **Google** is enabled, choose the project's support email, and save.
3. For browser testing, add the actual website hostname to Authentication's
   **Settings → Authorized domains**. Add `localhost` explicitly when testing
   locally if it is not already present.
4. If the OAuth consent screen is in testing mode, add the university test
   accounts or configure the appropriate audience. University administrator
   approval may be required by the school's Google Workspace policy.

Staff may use any email provider after administrator approval, as described in [Spark and staff setup](spark-and-staff-setup.md). Google selection is not limited to the student domain. The app independently checks
the email domain and verification status returned by Firebase before saving the
profile or allowing entry through the Google flow.

## Android

1. In Firebase Project settings, select the Android application with package name
   `com.example.finditbsu_app` (the current application ID).
2. Register the SHA-1/SHA-256 fingerprints of the debug and release signing
   certificates actually used for testing or distribution. `./gradlew signingReport`
   from `android/` displays the fingerprints for configured variants.
3. Download the refreshed `google-services.json` and replace the file at
   `android/app/google-services.json`.
4. Ensure it contains a web OAuth client (`client_type: 3`). This supplies the
   server client ID through the existing Google Services Gradle plugin. The
   current file already has a web client entry, but signing fingerprints and the
   enabled provider have not been verified against the live project.
5. Run `flutter pub get`, completely stop the app, then run `flutter run`.

If the project intentionally supplies the web OAuth client ID outside that JSON,
use `--dart-define=GOOGLE_SERVER_CLIENT_ID=YOUR_WEB_OAUTH_CLIENT_ID`. OAuth client
IDs are public configuration; never place a client secret in a mobile app.

## iOS and macOS

The existing Firebase options do not include an iOS OAuth client ID, and the
checkout has no Google sign-in URL scheme configured. An Apple application
maintainer must finish this platform setup before Google sign-in can work there:

1. Enable Google in Firebase, then download the Apple app's refreshed
   `GoogleService-Info.plist` to obtain `CLIENT_ID` and `REVERSED_CLIENT_ID`.
2. Add `CFBundleURLTypes` to `ios/Runner/Info.plist` with a URL scheme whose exact
   value is that `REVERSED_CLIENT_ID`. Do not substitute the web OAuth client ID.
3. Supply the iOS OAuth client ID through regenerated Firebase options
   (`iosClientId`) or run with
   `--dart-define=GOOGLE_IOS_CLIENT_ID=YOUR_IOS_OAUTH_CLIENT_ID`.
4. Follow the same steps in `macos/Runner/Info.plist` for macOS and add the Google
   SDK keychain-sharing entitlement documented by the plugin.
5. Follow the installed `google_sign_in_ios` package's integration instructions
   for the remaining Xcode configuration and native dependency installation.

No placeholder or guessed Apple client IDs or URL schemes are committed. Until
configured, the Google action returns an unavailable message; email/password
registration continues to work.

## Validation

Run `flutter analyze`, `flutter test`, and `flutter build web`. Automated tests
exercise imported names, malformed/personal/unverified identities, missing names,
profile role/history preservation, pending authentication state, logout races,
cancellation, and both screens without filling manual registration fields.

A real university Google login is not automated: it requires an authorized
account, the enabled Firebase provider, and configured native OAuth clients.
After setup, test on a real Android/iOS device and verify:

- A university student-number email imports its Google display name.
- A personal Gmail account is rejected before a profile is saved.
- Canceling sign-in leaves the user on the same screen.
- Signing in again preserves the account's existing role and creation date.
- Email/password accounts continue working.

The profile uses the existing Firestore `users` collection schema. This feature
does not require additional Firestore rule changes.

## Profile picture

The Profile screen displays the saved Google account picture. Sign in using **Continue with Google** to import or refresh it; entering a university email/password alone does not look up a Google photo. Older profiles with no saved picture can use the same signed-in Firebase identity’s photo. Missing or unreachable pictures show the user’s initial instead. Web rendering supports Google photos even when the host does not permit canvas CORS access.
