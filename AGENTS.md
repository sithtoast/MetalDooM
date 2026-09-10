# Project workflow

- At the end of each user-requested change, validate the changes and create a local Git commit before replying.
- Use a concise commit message describing the completed change. Report its short hash in the final reply.
- For discussion-only messages with no project changes, do not create empty commits.
- Do not push commits unless the user requests it.
- Update CHANGELOG.md with each user-requested change, recording the final successful build number and concise user-visible behavior. Keep prior entries; do not create entries for discussion-only turns.
- Keep WAD game data, generated app bundles, and build artifacts out of commits.
- Preserve the incrementing build-number workflow; identify the running build when validating app changes.
- Assess and update the semantic version for each delivered user-visible change: new features require a minor bump; fixes require a patch bump. A build-number increment alone is not a version bump.
- Keep intermediate builds and refinements of the same feature release on its chosen semantic version. Documentation-only changes do not require a bump.
- Use `Info.plist` as the semantic-version source of truth; synchronize current release/install docs and the handoff, preserve historical changelog entries, and verify the version and final build in the running app.
