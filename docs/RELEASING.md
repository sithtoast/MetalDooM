# Signed macOS releases

For the normal GitHub Actions release path, commit the version and changes on
`main`, preview with `bash scripts/publish.sh --dry-run`, then run
`bash scripts/publish.sh`. See [GitHub setup](GITHUB_SETUP.md#routine-publishing).
A new version tag triggers the hosted release workflow; an existing version
pushes only the branch. The commands below cover local/manual packaging.


For automatic builds and tagged releases, follow [GITHUB_SETUP.md](GITHUB_SETUP.md).

Release apps target Apple Silicon and macOS 14 or later. Local builds remain
ad-hoc signed. Distribution copies use Developer ID, Hardened Runtime, a secure
timestamp; notarization is an optional separate step. Credentials and private keys
stay in Keychain.

## One-time setup

Install a Developer ID Application certificate with its private key. Confirm it
appears in `security find-identity -v -p codesigning`. Store notarization credentials
interactively (enter an app-specific password at the prompt):

```bash
xcrun notarytool store-credentials "MetalDooM-notary" \
  --apple-id "YOUR_APPLE_ACCOUNT_EMAIL" --team-id "YOUR_TEAM_ID"
```

## Build and package

From the repository root:

```bash
bash scripts/build.sh
export METALDOOM_SIGN_IDENTITY="Developer ID Application: YOUR_NAME (YOUR_TEAM_ID)"
bash scripts/release.sh prepare
# Package the signed preview without uploading to Apple:
bash scripts/release.sh package-unnotarized
# Or, when authorized, upload to Apple and produce a notarized app ZIP:
# bash scripts/release.sh notarize
```

Set `METALDOOM_NOTARY_PROFILE` if using a different Keychain profile. The prepare step
copies the latest build into `build/releases/MetalDooM-VERSION-buildNUMBER/`, signs
it and creates the submission ZIP without uploading. The notarize step uploads
that ZIP to Apple, waits for Apple's decision, staples the ticket, checks Gatekeeper, then creates
a final ZIP and SHA-256 file. Existing release directories are never overwritten.
The submission receipt is retained as `notarization.json`. For a rejected or pending
submission, inspect it with `xcrun notarytool info ID --keychain-profile PROFILE` and
`xcrun notarytool log ID --keychain-profile PROFILE`; do not describe an unaccepted or unstapled artifact as notarized.
For a deliberately unnotarized preview, use package-unnotarized instead. A failed run preserves its files for diagnosis.

The unnotarized package includes the app, installation/player guides and a short bug-report guide and
license notices. Its filename and SIGNING-STATUS.txt explicitly identify it as
unnotarized. Gatekeeper may block first launch; INSTALL.md explains the per-app
exception. Do not require users to disable Gatekeeper globally.

Before publication, launch the signed app and exercise WAD loading, music and the
Metal HUD. Verify the final ZIP after extraction with `codesign --verify --deep --strict`.
For notarized builds also run `xcrun stapler validate` and
`spctl --assess --type execute` on the app.
A separate Mac download test is still valuable for the full Gatekeeper experience.

Update CHANGELOG.md and commit the final successful BUILD_NUMBER. Publish the final
`MetalDooM-*-macOS-arm64.zip` and its `.sha256` file alongside the corresponding
source revision/archive and license notices. Do not publish `notary-upload.zip`,
credentials, WADs or local game data. Packaging does not push or publish anything.

Create a matching source archive from the final clean local commit:

```bash
git archive --format=zip --prefix=MetalDooM-source/ \
  -o build/releases/MetalDooM-source.zip HEAD
```

Attach that source archive with the binary ZIP and checksums so recipients have
the corresponding source, including the vendored engine and build scripts.
Never create source archives from the entire working directory (which can contain
WADs, saves or credentials). Draft the GitHub release from docs/RELEASE_NOTES.md, link
the exact source commit, and label this early preview as a prerelease.

Contributor documentation lives in docs/ and remains in the source archive.
The app ZIP contains only the app, INSTALL.md, PLAYER_GUIDE.md, BUG_REPORT.md,
license/attribution notices and SIGNING-STATUS.txt.

## Branch beta releases

For **0.10.0 β1/build165**, retain `CFBundleShortVersionString=0.10.0` and set
`MetalDooMReleaseChannel=beta.1`. The app displays β1; the Git tag and package use
`v0.10.0-beta.1` and `0.10.0-beta.1`. Keep Apple's version field numeric.

Build with `METALDOOM_EXTENDED_PREVIEW=1` and an isolated `METALDOOM_BUILD_DIR`.
Set `METALDOOM_RELEASE_APP` to that completed app before invoking `release.sh`.
Preparation signs the helper dylib, worker and enclosing app in that order, all
with Developer ID, Hardened Runtime and secure timestamps. The notarized ZIP
includes the app, guides, licenses and signing status.

The main-only publisher rejects a beta channel. The hosted workflow excludes
`v*-beta.*` tags to avoid creating duplicate or unnotarized beta assets. Publish
only the reviewed branch and a new annotated beta tag, never main/master. Create
a GitHub draft prerelease with the final binary/source ZIPs, SHA256SUMS.txt and
SOURCE-COMMIT.txt, verify the uploaded assets, then publish the draft. Retain the
last stable tag and do not mark the beta as the latest stable release.

See VALIDATION.md for this beta's Apple submission and artifact verification.
Prior0.9.0/build124 release files remain in the primary checkout unchanged.
