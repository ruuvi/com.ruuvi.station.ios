# iOS CI Release Automation

This repository uses GitHub Actions to start CI and fastlane to handle iOS release work.

## Workflows

- `Deploy to Firebase [Ruuvi Station]`
  - Builds the `station` scheme with `Alpha` configuration.
  - Installs signing assets through `fastlane match`.
  - Uploads the IPA to Firebase App Distribution.
  - Supports manual release notes and manual Firebase tester groups.

- `Upload to Testflight`
  - Builds the `station` scheme with `Release` configuration.
  - Installs AdHoc profiles for archive signing and App Store profiles for export.
  - Uploads the IPA to TestFlight using App Store Connect API key auth.
  - Supports manual release notes, optional TestFlight groups, and optional external tester notification.

- `Sync App Store Metadata`
  - Uploads App Store metadata and screenshots with `deliver`.
  - Does not build or upload an app binary.
  - Can create or edit a specific App Store version when `app_version` is provided.
  - Reads metadata from `fastlane/metadata`.
  - Reads screenshots from `fastlane/screenshots`.

- `Precheck App Store Metadata`
  - Runs fastlane `precheck` against App Store metadata.
  - Does not build, upload, or submit anything.
  - Uses App Store Connect API key auth.

- `Submit App Store Review`
  - Submits an already uploaded App Store Connect build for review.
  - Requires the build number and exact confirmation value `SUBMIT`.
  - Runs precheck before submission.
  - Does not upload a binary, metadata, or screenshots.

## Private Release Setup

Release workflows require maintainer-only GitHub secrets, signing assets, App Store Connect access,
Firebase access, and private app configuration. Those details are intentionally documented in the
private keystore repository, not in this open-source repository.

Forks and pull requests without the release secrets can inspect these workflows, but cannot run the
signing, upload, metadata sync, or App Store submission steps successfully.

## Manual Workflow Runs

Ruuvi maintainers can run the workflows manually from GitHub Actions. Select the target branch for
the release or metadata change.

Firebase:

1. Open `Deploy to Firebase [Ruuvi Station]`.
2. Click `Run workflow`.
3. Select the branch.
4. Optionally set release notes and Firebase tester groups.

TestFlight:

1. Open `Upload to Testflight`.
2. Click `Run workflow`.
3. Select the branch.
4. Optionally set release notes.
5. Leave TestFlight groups empty to use the configured default groups, or enter comma-separated
   group names for this run.
6. Enable external distribution only when the build should go to external TestFlight testers.
7. Enable external tester notification only when testers should get Apple's email.

App Store metadata:

1. Edit the live localized metadata files under `fastlane/metadata`.
2. Add or replace localized screenshots under `fastlane/screenshots` when needed.
3. Review the changed files before syncing them to App Store Connect.
4. Open `Sync App Store Metadata`.
5. Choose `metadata`, `screenshots`, or `all`.
6. Optionally enter `app_version`, for example `1.2.3`.
7. Use `overwrite_screenshots` only when local screenshots should replace existing App Store screenshots.

Example:

```text
fastlane/metadata/en-US/release_notes.txt
fastlane/metadata/en-US/description.txt
fastlane/metadata/fi/release_notes.txt
fastlane/metadata/sv/release_notes.txt

fastlane/screenshots/en-US/01_home.png
fastlane/screenshots/en-US/02_history.png
fastlane/screenshots/fi/01_home.png
fastlane/screenshots/sv/01_home.png
```

Supported App Store Connect locale folders:

```text
en-US
fi
sv
de-DE
fr-FR
```

Common metadata files:

```text
name.txt
subtitle.txt
promotional_text.txt
description.txt
keywords.txt
release_notes.txt
support_url.txt
marketing_url.txt
privacy_url.txt
```

The files under `fastlane/metadata` are the editable source for App Store metadata sync.

If `app_version` is empty, metadata sync leaves the App Store version untouched. If `app_version` is set, fastlane asks App Store Connect to create or edit that version before uploading metadata/screenshots.

App Store precheck:

1. Open `Precheck App Store Metadata`.
2. Click `Run workflow`.
3. Review failures in the workflow log before uploading metadata or submitting a release.

App Store review submission:

1. Upload and process a TestFlight/App Store Connect build first.
2. Sync metadata/screenshots if needed.
3. Use the same `app_version` in metadata sync and review submission when targeting a new App Store version.
4. Run `Precheck App Store Metadata`.
5. Open `Submit App Store Review`.
6. Enter the processed build number.
7. Enter `SUBMIT` in the confirmation input.
8. Choose automatic release or phased release only if that is intended for this version.
