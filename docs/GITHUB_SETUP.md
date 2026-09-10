# First GitHub build and release

## Routine publishing

After committing your changes on `main`, run:

```sh
bash scripts/publish.sh --dry-run
bash scripts/publish.sh
```

The script reads the app version from `Info.plist`. If that version is newer than
published version tags, it creates an annotated `v<version>` tag and pushes the
branch and tag together to `origin`. If that tag already exists, it pushes only
`main`, keeping the existing release unchanged. With no published versions, it
tags the current version as the first release. It never increments the version
or commits files for you. Dirty checkouts, branches other than `main`, older
versions and conflicting tags stop publication.

The dry run reads remote tags but makes no changes. A failed actual push retains
the local tag for inspection and retry; no tags or branches are force-pushed.
The existing tagged-release workflow then builds/signs the assets and creates a
GitHub prerelease. Check Actions for success before sharing the release. Set up
the signing secrets below before your first tagged push.


The workflow is `.github/workflows/macos.yml`. It uses GitHub's hosted Apple Silicon
`xcode-27` runner (currently a preview image), matching the locally tested compiler
generation. The first hosted run must pass before treating CI as validated.

## What runs automatically

- Pushes to `main`, pull requests and the manual Actions button build the app and
  run checks that do not require game WADs. The Actions run offers a development
  app ZIP, matching source ZIP and checksums. These builds are ad-hoc signed.
- Pushing a tag exactly matching `Info.plist`, such as `v0.5.0`, imports your
  Developer ID, signs and packages the app, and publishes a GitHub prerelease.
- No run submits anything to Apple for notarization. Tagged releases clearly say
  they are signed but unnotarized. Game WADs are never required or uploaded.
- Only tag builds receive the signing secrets. Pull requests do not receive them.
  The publish job alone has permission to write GitHub releases.

## 1. Export your signing identity on your Mac

1. Open **Keychain Access** (use Spotlight).
2. Select the **login** keychain and **My Certificates**.
3. Find **Developer ID Application: William Holt (WG3UVY5459)**. Expand it and
   confirm that a private key appears underneath.
4. Select the certificate identity and choose **File → Export Items…**.
5. Select **Personal Information Exchange (.p12)**. Save it outside the repository,
   for example as `~/Desktop/MetalDooM-signing.p12`.
6. Choose a strong export password and keep it in your password manager. If macOS
   asks to permit exporting the key, authenticate with your Mac login credentials.

If .p12 is unavailable, you have probably selected only a certificate without its
private key. A downloaded .cer file alone cannot sign builds. Do not export your
whole keychain or upload the .p12 as a repository file or release asset.

## 2. Add three repository secrets

Open https://github.com/sithtoast/MetalDooM/settings/secrets/actions and use
**New repository secret** for each entry:

| Name | Value |
| --- | --- |
| `BUILD_CERTIFICATE_BASE64` | Base64 contents of the exported .p12, copied as described below |
| `P12_PASSWORD` | The export password you chose, not your Apple Account or Mac login password |
| `SIGNING_IDENTITY` | `Developer ID Application: William Holt (WG3UVY5459)` |

To copy the certificate value without printing it in Terminal:

```bash
base64 -i "$HOME/Desktop/MetalDooM-signing.p12" | pbcopy
```

Paste into BUILD_CERTIFICATE_BASE64 on GitHub and save. Base64 is an encoding, not
encryption; keep this value private. Do not paste it or its password into chat.
The workflow generates its own temporary keychain password and deletes the
keychain after signing. No provisioning profile, Apple password, notarization
credential or personal GitHub token is required for this app's workflow.

## 3. Push the workflow and check the first build

From Terminal, using the actual repository:

```bash
cd /Users/wmh/Dev/MetalDooM
git push origin main
```

Open the repository's **Actions** tab and select **macOS build and release**.
Wait for the run to finish. A green check means the build and its automated checks
passed. Download the artifact at the bottom of the run page to inspect the app.
A successful runner build does not replace testing on another physical Mac.

If Actions is disabled, open repository **Settings → Actions → General** and allow
GitHub Actions, including the official actions/checkout, upload-artifact and
download-artifact actions. The workflow requests the permissions it needs; you do
not need to change the repository's default workflow permission to read/write.

## 4. Publish the first prerelease

After the main build is green and the three secrets are configured:

```bash
cd /Users/wmh/Dev/MetalDooM
git tag -a v0.5.0 -m "MetalDooM 0.5.0 preview"
git push origin v0.5.0
```

The tag marks the source revision being released. Its version must exactly match
CFBundleShortVersionString in Info.plist or the workflow stops before signing.
Once the tag run finishes, open **Releases** to find the prerelease with the signed
app ZIP, corresponding source ZIP, SHA256SUMS.txt and SOURCE-COMMIT.txt.

Do not also create a manual release for the same tag while the workflow runs. If
an existing release causes publication to fail, inspect it before retrying; the
workflow intentionally does not overwrite existing releases/assets. A failed
signing run can be retried using **Re-run failed jobs** after fixing the secrets.
For later code changes, bump the app version, update the changelog and push a new
version tag. Do not move an already published tag to different code.

## Build numbers

Local builds continue incrementing BUILD_NUMBER. CI uses `10000 + github.run_number`
in the app bundle and filenames, without editing or committing BUILD_NUMBER.
This reserves a separate practical range for CI; revisit the scheme before local
builds approach 10000. A rerun retains the same build number. Workflow run and
attempt IDs in GitHub identify retries. The matching source archive retains the
committed local counter; CI supplies its override through METALDOOM_CI_BUILD_NUMBER.
The app version (for example 0.5.0) is separate from both counters.

## If a run fails

- **Tag mismatch:** update the version before creating the next version tag.
- **Missing secret / import failure:** check all three secret names, the .p12 export
  and its export password. Re-export with the private key if necessary.
- **No matching signing identity:** copy the exact Developer ID Application name
  reported by `security find-identity -v -p codesigning` on your Mac.
- **Runner/compiler error:** the xcode-27 image is preview; inspect the toolchain
  printed at the start of the run. Hosted compilation remains unverified until green.
- **Release already exists:** inspect that release; do not blindly replace its assets.

GitHub's certificate guidance:
https://docs.github.com/en/actions/how-tos/deploy/deploy-to-third-party-platforms/sign-xcode-applications
