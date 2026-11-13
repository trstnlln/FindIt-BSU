# Free-plan release and staff access

Deploy the updated app and Firestore rules together. This release does not need a Blaze upgrade for live in-app activity or report archiving.

```sh
git pull origin main
flutter pub get
firebase deploy --only "firestore:rules,firestore:indexes" --project finditbsu
flutter run
```

The rules add participant-scoped conversation queries, private activity receipts, atomic message metadata, approved staff identities and archive permissions. Old app versions cannot send messages under the new atomic-message rules: distribute the updated app with this deployment. No live Firebase changes are made by pushing code to GitHub.

## What works without Cloud Functions

Claims, claim-stage updates and incoming private messages generate live activity in the running app from authorized Firestore listeners. Read receipts are private to each account and follow the latest message/claim version. This is a current activity view, not an immutable event log: older message notifications are replaced by the newest message in that conversation. Previous chat history remains available. Old conversations without message metadata start producing live alerts when a new message is sent with this version.

My Activity prioritizes incoming proof reviews, unread replies and active pickups. Archived reports remain in the reporter's history. Explore and matching exclude them. New claims on archived reports are denied by rules, including requests from old clients. Existing claims, private proof and conversations retain their parent references. Archiving does **not** erase personal data or delete the uploaded image; a retention/purge policy still needs a trusted administrator. Reports deleted before this release are not automatically recovered. Moderator archives cannot be restored by the report owner.

Background push, scheduled reminders and automatic server match/search notifications require a configured trusted backend. These optional controls stay hidden by default. After deploying/testing the Functions and platform notification setup, a maintainer can build with `--dart-define=ENABLE_CLOUD_ALERTS=true` to expose the server inbox and device registration. In-app claim/message updates continue to work independently. Saved searches remain available through Profile.

## Staff using any email provider

Students self-register with `@g.batstate-u.edu.ph`. Staff may use any valid email provider **after an authorized administrator approves their identity**. A profile role selected by the user grants no external-email access or moderation permission.

An administrator who has verified the employee's identity and has Google Application Default Credentials can run:

```sh
npm ci --prefix functions
node tooling/firebase/grant-staff.cjs employee@example.org finditbsu grant
```

This sets the trusted `staff` custom claim, preserves other claims, and provisions an Auth account if needed. It does not mark an email verified or send messages on the administrator's behalf. Do not put credentials in the Flutter app or commit credential files.

The employee can use Google if the approved email is a Google account. The OAuth audience must permit that account; an internal-only university OAuth app will not accept external Google accounts. For another mail provider, use **Forgot password** on the sign-in screen to set an app password, sign in with email, and complete email verification. Existing staff accounts must sign out and back in after approval to refresh their token.

```sh
node tooling/firebase/grant-staff.cjs employee@example.org finditbsu revoke
```

Revocation clears the staff claim and revokes refresh tokens. An already-issued ID token can remain valid until expiry; do not promise instant revocation. Staff approval alone does not grant moderator powers. Use the separate moderator administration workflow for designated campus moderators.

## Test on actual phones before sharing

Use two test accounts and synthetic reports. Connect an Android phone with USB debugging, run `flutter devices`, then `flutter run -d DEVICE_ID`. Keep the phone online for live Firebase testing. Android Google sign-in needs the fingerprints of this computer's signing key in Firebase; iOS requires its own Xcode/OAuth configuration.

1. Test campus Google sign-in, approved staff email/password, email verification and password reset. Verify that an unapproved external email is rejected even with a self-selected Staff role.
2. Test camera/gallery uploads, canceling a photo picker and rejecting oversized/unsupported photos. Check camera/photo permissions after denying them once.
3. Create reports with long titles on small phones and large text. Search/filter, verify counts, clear all filters and open a saved search.
4. Account B claims A's report. While both apps are open, verify A's live alert and Review claims action. Exchange messages and check read badges on both accounts.
5. Complete review, approval, pickup readiness and return. Only confirm return after the real handover. Check that a second claimant cannot approve or retrieve another person's private proof.
6. Archive a report. Verify it leaves Explore, retains claims/messages in history, rejects new claims and can be restored by its owner. A moderator-hidden report must remain hidden from its owner’s restore action.
7. Switch accounts and confirm the old account's updates disappear. Try airplane mode and reconnect: forms should preserve work, and failed activity loads should recover with Refresh. Background push is not expected on the default free-plan build.

Cloud/browser tests cannot establish physical camera behavior, Google account consent on a phone, or actual push delivery. Record the phone model, Android/iOS version and any failing step when reporting a problem.
