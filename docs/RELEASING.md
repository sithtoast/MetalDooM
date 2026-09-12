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

## Existing notarized release

The user completed notarization of **0.9.0 build 124** in the preceding task:
Apple accepted submission `121f1db9-34a4-4f5f-aeb3-599a59de0727`; stapler,
codesign and Gatekeeper checks passed in the host context. Its distribution ZIP
is preserved in the primary checkout's `build/releases/MetalDooM-0.9.0-build124/`.
That is prior-task evidence, not a new submission or repeat Gatekeeper check.
The current **0.10.0 build 126** is an ad-hoc-signed development app; no packaging,
Apple submission or publishing was performed. GitHub automation still produces
unnotarized assets. Never overwrite the build-124 release while testing here.
