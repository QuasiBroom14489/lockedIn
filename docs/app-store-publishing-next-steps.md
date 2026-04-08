# lockedIn App Store Publishing Next Steps

Last updated: April 7, 2026

This document outlines the next steps to get `lockedIn` published on the App Store, based on the current repository state.

## Current project snapshot

- App target bundle ID: `com.zanejohnson.lockedIn`
- Team ID in project: `9KL4YUCX2A`
- Marketing version: `1.0`
- Build number: `1`
- Current iPhone deployment target in the project file: `26.2`

## Priority 1: Fix submission blockers

These are the items most likely to block App Store submission or cause immediate review issues.

### 1. Confirm the deployment target is intentional

The Xcode project currently sets `IPHONEOS_DEPLOYMENT_TARGET = 26.2`.

Next steps:

- Verify this is a valid and intended minimum iOS version for the release.
- If this was bumped accidentally, lower it to the real supported OS target before archiving.
- Re-test onboarding, auth, focus sessions, profile flows, and notifications on the actual minimum supported iOS version.

### 2. Finalize Screen Time / Family Controls strategy

The app imports `FamilyControls`, `DeviceActivity`, and `ManagedSettings`, but the implementation is still partial:

- `ScreenTimeService.fetchScreenTimeMetrics()` currently returns cached or empty values.
- Historical docs in the repo already note that DeviceActivity validation is still pending on physical hardware.
- The entitlements file does not yet show the Family Controls entitlement required for the full Screen Time workflow.

Next steps:

- Decide whether Screen Time features are in the v1 App Store build.
- If yes:
  - Add the correct entitlement/capability in Apple Developer.
  - Validate authorization, monitoring, and user-facing flows on a physical device.
  - Make sure the feature degrades cleanly if authorization is denied.
  - Prepare App Review notes explaining why the entitlement is needed.
- If no:
  - Remove or hide unfinished Screen Time UI and code paths from the release build.
  - Update profile/reward copy so the shipped app does not imply unsupported tracking.

### 3. Clean up push notification entitlements for release

`lockedIn.entitlements` currently declares APS environment as `development`.

Next steps:

- Switch signing/capabilities to the production push environment for release builds.
- Confirm the Apple Developer App ID has Push Notifications enabled.
- Verify Firebase/APNs configuration for the release bundle ID.
- Test notification permission prompts and delivery on a signed release-style build.

### 4. Fill in App Icon assets

The app icon catalog currently contains `Contents.json` entries but no actual icon image files in `lockedIn/lockedIn/Assets.xcassets/AppIcon.appiconset`.

Next steps:

- Create the final 1024x1024 App Store icon and any required generated variants.
- Add the image assets to the app icon set in Xcode.
- Verify the archive does not warn about missing app icons.

## Priority 2: Finish release-readiness work inside the app

### 5. Audit privacy-sensitive flows and Info.plist messaging

The app currently uses or references:

- Google Sign-In
- Spotify deep linking / app-to-app auth
- Photos picker for profile images
- Notifications
- Screen Time frameworks

Next steps:

- Review `Info.plist` and add any missing usage descriptions required by shipped features.
- Double-check that only features included in the release are enabled in code and in capabilities.
- Confirm login failure states, onboarding exits, and revoked-permission flows are user-friendly.

### 6. Verify third-party integration production settings

The repo shows active Firebase, Google Sign-In, and Spotify integration points.

Next steps:

- Confirm production Firebase project settings for:
  - Auth providers
  - Firestore rules
  - Storage rules
  - Analytics configuration
- Confirm the release app’s Google Sign-In configuration matches the App Store bundle ID.
- Confirm Spotify redirect URL and app credentials are the final production values.
- Re-test sign-in and callback handling on device.

### 7. Run a real release QA pass

Before submission, do a release candidate pass on physical devices.

Recommended checklist:

- New user sign-up
- Returning user login
- Onboarding completion
- Focus session start, background end, and completion
- Notification prompt and local notification delivery
- Profile editing with photo selection
- Social feed posting, voting, favorites, and profile views
- Spotify connect / failure handling
- Screen Time flows, if included in v1

### 8. Increase release metadata discipline

The project is still on version `1.0 (1)`.

Next steps:

- Pick the release version/build strategy.
- Bump the build number for each TestFlight/App Store upload.
- Tag the release candidate in git once the submission build is chosen.

## Priority 3: Prepare App Store Connect

### 9. Create the App Store record

In App Store Connect:

- Create the app record for `lockedIn`.
- Confirm bundle ID and team match the Xcode target.
- Set app name, subtitle, category, age rating, and pricing.

### 10. Prepare store listing assets

You will need:

- App name
- Subtitle
- Promotional text
- Keywords
- Description
- Support URL
- Marketing URL, if available
- Privacy Policy URL
- App Review contact details
- App screenshots for required device sizes
- Optional preview video

Recommended output from this repo effort:

- A shared folder for screenshots from the final release build
- A draft markdown file for App Store copy and review notes

### 11. Complete App Privacy answers

Because the app uses authentication, analytics, profile data, social content, and likely uploaded profile photos, the App Privacy section matters.

Next steps:

- Inventory what user data is collected, stored, and linked to identity.
- Separate what is required for app functionality vs analytics.
- Complete the App Store Connect privacy questionnaire based on the real shipped behavior.
- Make sure the privacy policy matches the live app.

### 12. Prepare review notes

This app likely benefits from extra reviewer context because of auth providers, Spotify, and possible Screen Time capabilities.

Include:

- Test account credentials or a reviewer-access path
- Steps to reach the core focus-session experience
- Explanation of any permission prompts
- Explanation of any entitlement-based functionality

## Priority 4: Submit through TestFlight first

### 13. Archive and upload a release candidate

Next steps:

- Build with Release configuration.
- Archive in Xcode.
- Validate the archive for signing and missing asset issues.
- Upload to App Store Connect.

### 14. Use TestFlight as the final gate

Before App Review:

- Install from TestFlight on at least one clean device.
- Verify production auth, deep links, and notifications.
- Check for missing entitlements, signing differences, and runtime warnings that do not appear in Debug.
- Collect feedback from a small external or internal tester group.

## Suggested order of operations

1. Resolve the deployment target and decide whether Screen Time ships in v1.
2. Fix entitlements/capabilities and add the final app icon.
3. Validate release behavior on physical devices.
4. Prepare App Store Connect metadata, privacy answers, and review notes.
5. Upload to TestFlight, run final QA, then submit for review.

## Recommended owner checklist

- Engineering: release build stability, entitlements, auth, notifications, icons, QA
- Product/Founder: store copy, screenshots, privacy policy, support contact, review notes
- Both: final decision on Screen Time feature scope for v1

## Notes based on this repo review

- There are existing in-progress product changes in the working tree, so App Store release prep should be done carefully on top of those edits.
- Screen Time support appears partially implemented and is the biggest current release-risk area.
- Push notification entitlements and app icon assets should be checked early because they often block archive validation late in the process.
