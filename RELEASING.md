# Signed macOS releases

Release apps target Apple Silicon and macOS 14 or later. Local builds remain
ad-hoc signed. Distribution copies use Developer ID, Hardened Runtime, a secure
timestamp and Apple notarization; credentials and private keys stay in Keychain.

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
# Upload the signed app to Apple, then staple and package it:
bash scripts/release.sh notarize
```

Set `METALDOOM_NOTARY_PROFILE` if using a different Keychain profile. The prepare step
copies the latest build into `build/releases/MetalDooM-VERSION-buildNUMBER/`, signs
it and creates the submission ZIP without uploading. The notarize step uploads
that ZIP to Apple, waits for Apple's decision, staples the ticket, checks Gatekeeper, then creates
a final ZIP and SHA-256 file. Existing release directories are never overwritten.
The submission receipt is retained as `notarization.json`. For a rejected or pending
submission, inspect it with `xcrun notarytool info ID --keychain-profile PROFILE` and
`xcrun notarytool log ID --keychain-profile PROFILE`; do not distribute an unaccepted
or unstapled artifact. A failed run preserves its files for diagnosis.

Before publication, launch the signed app and exercise WAD loading, music and the
Metal HUD. Verify the final ZIP after extraction with `codesign --verify --deep
--strict`, `xcrun stapler validate` and `spctl --assess --type execute` on the app.
A separate Mac download test is still valuable for the full Gatekeeper experience.

Update CHANGELOG.md and commit the final successful BUILD_NUMBER. Publish the final
`MetalDooM-*-macOS-arm64.zip` and its `.sha256` file alongside the corresponding
source revision/archive and license notices. Do not publish `notary-upload.zip`,
credentials, WADs or local game data. Packaging does not push or publish anything.
