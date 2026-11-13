# Spartan red and white release

For the current free-plan workflow, safe archiving, approved staff accounts, coordinated app/rules deployment and real-phone checks, see [Spark and staff setup](spark-and-staff-setup.md).

This update implements the recovery workflow in priority order:

| Priority | Capability | Activation |
| --- | --- | --- |
| 1 | Verified university accounts, Google account name import, email verification/resend, password reset | Enable authentication providers and configure platform OAuth clients |
| 1 | Red/white theme, logo, launcher icons, readable forms and cards | Included in the app build |
| 1 | Claim review → approval → pickup readiness → returned, with a protected handover transaction | Deploy the updated Firestore rules |
| 1 | Editable reports, closing recovered reports, public-field drafts, photo format/size checks and upload progress | App code; configure the Cloudinary preset limits below |
| 2 | Private claimant/reporter messaging and suspicious-report handling | Deploy rules; assign authorized campus moderators |
| 2 | Live claim/message updates and private read states | Updated app and Firestore rules; works on Spark |
| 2 | Optional server match/search alerts and reminders | Functions and a billing-enabled plan; opt into the cloud-enabled build |
| 2 | Campus pickup office hours and instructions | Authorized moderators publish confirmed details in Profile → Campus pickup offices |
| 3 | Opt-in device notifications, token refresh and sign-out cleanup | FCM/APNs/VAPID platform configuration |
| 3 | Native release crash reporting and automated app/security checks | Enable Crashlytics; GitHub Actions runs on pushes and pull requests |

No live Firebase services were deployed by the code push. Do the project setup
below before distributing this release. Account verification is now required for
browsing, reporting, claiming, messaging and alerts. Existing email/password users
may need to verify their inbox and sign in again to refresh their token.

## 1. Authentication

Follow [university Google sign-in setup](university-google-sign-in.md).
Confirm Email/Password and Google are enabled under Firebase Authentication. Verify the email
templates and authorized website domains. The new verification screen can resend
emails and refresh the verification status. Google account names are imported;
email text and student numbers are never treated as a directory lookup.

## 2. Rules, indexes, and backend functions

An authorized project maintainer can run:

```sh
firebase login
firebase deploy --only firestore:rules,firestore:indexes --project finditbsu
cd functions
npm ci
cd ..
firebase deploy --only functions:community --project finditbsu
```

The Functions codebase uses Node 22. Cloud Functions v2, Eventarc, Cloud Run and
the scheduled reminder require the appropriate project APIs, permissions and a
billing-enabled Firebase plan. Review costs and deploy to a staging project first.
No billing settings are changed automatically.

The default Functions region is `asia-southeast1`; choose a region close to the
Firestore database by setting `FUNCTION_REGION` in the Functions deployment
configuration before deploying. Reminders run at 09:00 Asia/Manila for reports
open at least 14 days, at most once per report per week. Alerts use deterministic
IDs to tolerate event retries. Match alerts exclude closed reports and reports
owned by the same person. They are suggestions, never ownership decisions.

Optional server notifications are stored privately under `users/{uid}/notifications`. The default app inbox derives live activity from participant-authorized claims and conversations, with private read states under `users/{uid}/activityReads`. Push messages deliberately contain
only a generic update; private proof, message text and cash details are omitted
from lock-screen notifications. At-least-once event delivery can still produce
an occasional repeated push. Functions clean up private subcollections and claim
conversations when a public report is deleted.

## 3. Campus moderators and pickup offices

A Student/Teacher/Staff role selected in registration **does not grant moderator
permissions**. A project administrator with approved Google Application Default
Credentials may run:

```sh
node tooling/firebase/grant-moderator.cjs USER_UID finditbsu grant
```

The script preserves other custom claims and requires a verified university
account. Use `revoke` instead of `grant` to remove access. Do not commit credential
files. The moderator must sign out and sign in again to receive the new claim.

Moderators can review concerns and remove inappropriate reports in Profile →
Campus moderation. They can publish confirmed office hours, locations, and pickup
instructions under Campus pickup offices. No office schedule is guessed. When
hours are absent, students are asked to confirm them directly before travelling.

## 4. Notifications and crash reporting

Android: enable Firebase Cloud Messaging for the project and confirm that the
refreshed `google-services.json` matches the application. Android 13+ notification
permission is requested only when the student taps **Enable device alerts**.

iOS: configure Push Notifications and the appropriate signing entitlements in
Xcode, upload the APNs authentication key securely in Firebase, and complete the
Google sign-in URL scheme/client setup. This Linux cloud host cannot build an iOS app.

Web: create the public Web Push certificate key in Firebase Cloud Messaging and
build with `--dart-define=FCM_WEB_VAPID_KEY=YOUR_PUBLIC_VAPID_KEY`. Serve
`firebase-messaging-sw.js` from the site's root over HTTPS (localhost is allowed
for development). The worker uses the project's public Firebase app identifiers;
it contains no administrative secret. If the Firebase project is changed,
regenerate the worker's public configuration as well as FlutterFire options.

Native release builds collect unhandled/fatal errors through Crashlytics. Debug
and web builds do not enable crash collection. Enable Crashlytics in Firebase,
verify a staging release receives a test crash, and configure Apple symbol uploads
as described by FlutterFire before an iOS release. Crash delivery and real device
push cannot be established by the browser or unit tests alone.

## 5. Photo uploads and drafts

The existing Cloudinary unsigned preset must enforce **JPEG/PNG/WebP only** and a
**5 MB maximum** on the server. The app checks byte signatures and size before
preview/upload, sends a matching MIME type, tracks sent bytes, and uses timeouts.
Client checks do not replace the server preset restrictions. Review preset abuse
protection in the Cloudinary dashboard; never put an API secret in Flutter.

The app now archives reports and retains linked private details and conversations; it does not delete the parent. Administrator purges need a trusted retention process. Removing the corresponding Cloudinary asset requires a separate trusted
media-retention integration with Cloudinary administrative credentials; unsigned
uploads do not grant the app delete permission.

Drafts are stored per account on the device and contain only public report fields.
Photos, cash amounts and private verification questions/answers are not persisted.
Failed submissions preserve the form/draft. Firestore report creation uses a
transaction so offline writes are not silently queued and accidentally submitted
a second time. Completing a report clears its saved draft.

## 6. Checks and local development

```sh
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build web --no-wasm-dry-run
flutter build apk --debug
npm ci --prefix functions
npm test --prefix functions
npm ci --prefix tooling/firebase
npm test --prefix tooling/firebase
npm run test:alerts --prefix tooling/firebase
```

The alert integration test runs real Firestore/Functions/Eventarc emulators in
`demo-finditbsu`; it verifies match/search/claim/message alerts, retry-safe scheduled
reminders, and deletion cleanup. It sends no real device notifications. A small
CLI wrapper routes loopback locally to work around Firebase CLI 15.35 ignoring
NO_PROXY, while retaining proxies and TLS verification for external destinations.

For a full local app session, start the demo emulators and use a separate terminal:

```sh
# From tooling/firebase:
node firebase-cli.cjs emulators:start --project demo-finditbsu --only auth,firestore,functions,eventarc --config ../../firebase.json
# From the repository root:
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true
```

The app displays LOCAL TEST and uses the isolated demo project. For an Android
emulator, also supply `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`. Production
builds omit these flags. Cloudinary upload and device push remain real external
services, so do not exercise those with fake test data against production.

GitHub Actions runs app analysis/tests, builds web and an Android debug APK, and
runs the rule/backend suites. Builds are downloadable from the workflow artifacts.
A debug APK is for testing; production signing and store distribution remain a
separate release step.

Before release, test verified registration, personal-account rejection, photo and
camera permissions, poor connectivity/draft restoration, report editing, all claim
stages, private messaging, suspicious-report moderation, saved-search alerts,
pickup information, sign-out/token cleanup, and push delivery on real devices.

The portable two-user browser regression is also included as `test:ui`. Install
Chromium with `npx playwright install chromium` from `tooling/firebase`, build
`build/emulator-web` with the emulator flag, and serve that directory on port 8081.
Then run `npm run test:ui --prefix tooling/firebase` from the repository root.
It starts isolated Firebase emulators, creates synthetic verified test accounts,
and drives sign-in, claims, messaging, review, pickup and return through the real
Flutter UI. Screenshots are written to ignored `tooling/firebase/test-results/`.
Set `PLAYWRIGHT_CHROMIUM_EXECUTABLE` to use an existing Chromium installation and
`TEST_APP_URL` if serving the emulator build on a different port. The test refuses
to run without the demo emulator environment.

Local validation produced an Android debug APK and a web build, clean Flutter
analysis, passing app/rule/backend suites, and an end-to-end recovery-flow test.
This does not establish live Google sign-in, FCM/APNs delivery, Cloudinary preset
configuration, Crashlytics ingestion, production deployment, or real-device
camera behavior; perform those project/device checks before distribution.
