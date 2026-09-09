# Project workflow

- At the end of each user-requested change, validate the changes and create a local Git commit before replying.
- Use a concise commit message describing the completed change. Report its short hash in the final reply.
- For discussion-only messages with no project changes, do not create empty commits.
- Do not push commits unless the user requests it.
- Update CHANGELOG.md with each user-requested change, recording the final successful build number and concise user-visible behavior. Keep prior entries; do not create entries for discussion-only turns.
- Keep WAD game data, generated app bundles, and build artifacts out of commits.
- Preserve the incrementing build-number workflow; identify the running build when validating app changes.
