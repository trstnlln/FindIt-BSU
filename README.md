# FindIt BSU

A Flutter lost-and-found app for the Batangas State University Alangilan campus.
The refreshed design uses burgundy, ivory, gold, and teal, with a shared search-pin
logo and Android, iOS, and web icons.

## Development

Use Flutter **3.47.9** (Dart **3.13.7**) or a compatible newer stable release.
The cloud setup installed this SDK at `/workspace/.tools/flutter`.

```sh
export PATH="/workspace/.tools/flutter/bin:$PATH"
# These writable cache paths are useful in the managed cloud environment.
export PUB_CACHE=/workspace/.cache/pub
export XDG_CONFIG_HOME=/workspace/.config
flutter pub get --enforce-lockfile
flutter analyze
flutter test
flutter build web
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Use the existing checkout in cloud tasks; do not create a Git worktree unless
explicitly requested. Servers must be restarted in each new task.

The Firebase configuration is in `lib/firebase_options.dart`. Email/password
sign-in must be enabled for the configured project. Only university emails at
`g.batstate-u.edu.ph` are accepted. Shared demo credentials, automatic demo account
creation, anonymous fallback, and the account-changing role switcher have been
removed. Register or use an existing university account.

Photos use the existing Cloudinary unsigned upload preset in
`lib/services/item_service.dart`. Check the Cloudinary account's preset and file
restrictions before a production release. No real accounts or uploads are created
by the automated tests.

For cloud web runs, the network policy must permit `storage.googleapis.com`,
`www.gstatic.com`, and `fonts.gstatic.com` as well as the package-manager preset.
Live authentication, database, and upload operations also need their Firebase and
Cloudinary endpoints; those operations were not verified against production.

## Firestore regression tests

Node 22+ and Java 21 are required. The suite runs against an isolated demo
Firestore emulator, never the production project.

```sh
cd tooling/firebase
npm ci
npm test
```

The tests cover atomic report/private-detail creation, answer privacy, campus
identity, scoped claim reads, ownership immutability, claimant approval denial,
closed reports, and preventing two approvals for the same item. Permission-denied
logs for negative tests are expected.

## Firebase release step

**The local Firestore rules must be deployed along with this app update.** Older
rules deny the verification subcollections; the updated reporting flow creates the
report and private details atomically. Test in staging before production.

An authorized project maintainer can deploy the reviewed rules with:

```sh
firebase deploy --only firestore:rules --project finditbsu
```

No production rules were deployed during this change. Android/iOS launcher icons,
Android Internet permission, and iOS photo/camera usage descriptions are included;
native release builds and real-device camera, upload, and account flows still
need platform testing.

## Brand assets

The logo master is `assets/branding/findit-logo.png`; `BrandLogo` renders it in the
app, and launcher sizes are included in the native projects and web manifest.
The app palette and common component styles live in `lib/theme/app_theme.dart`.
