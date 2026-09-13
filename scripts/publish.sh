#!/bin/bash
# Push main and, for a new version, publish its release tag atomically.
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"
DRY_RUN=false
case "${1:-}" in
  --dry-run) DRY_RUN=true ;;
  --help|-h)
    echo 'Usage: bash scripts/publish.sh [--dry-run]'
    echo 'Push committed main to origin; add v<Info.plist version> if it is newer than published versions.'
    echo 'An existing version tag is never moved. --dry-run reads GitHub but changes nothing.'
    exit 0 ;;
  '') ;;
  *) echo "Unknown argument: $1" >&2; exit 1 ;;
esac
[[ $# -le 1 ]] || { echo 'Too many arguments.' >&2; exit 1; }
fail() { echo "Publish stopped: $*" >&2; exit 1; }
[[ "$(git symbolic-ref --short -q HEAD)" == main ]] || fail 'Check out main before publishing.'
[[ -z "$(git status --porcelain)" ]] || fail 'Commit or stash all changes first, including untracked files.'
PUSH_URL=$(git remote get-url --push --all origin) || fail 'Configure the origin remote first.'
[[ -n "$PUSH_URL" && "$PUSH_URL" != *$'\n'* ]] || fail 'origin must have exactly one push destination.'
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist)
[[ "$VERSION" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail 'Info.plist must contain a major.minor.patch version without leading zeros.'
CHANNEL=$(/usr/libexec/PlistBuddy -c 'Print :MetalDooMReleaseChannel' Info.plist 2>/dev/null || true)
[[ -z "$CHANNEL" ]] || fail 'Use the manual notarized beta procedure for prerelease channels; main publishing is disabled.'
TAG="v$VERSION"
HEAD_COMMIT=$(git rev-parse HEAD)
# Read the actual remote rather than relying on possibly stale local tags.
REMOTE_REFS=$(git ls-remote "$PUSH_URL" 'refs/tags/v*') || fail 'Could not read origin tags. Check your connection and GitHub authentication.'
REMOTE_TAG=$(printf '%s\n' "$REMOTE_REFS" | awk -v ref="refs/tags/$TAG" '$2==ref {print $1}')
LATEST=$(printf '%s\n' "$REMOTE_REFS" | awk '$2 ~ /^refs\/tags\/v[0-9]+\.[0-9]+\.[0-9]+$/ {sub(/^refs\/tags\/v/, "", $2); print $2}' | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
if [[ -n "$LATEST" && "$LATEST" != "$VERSION" ]]; then
  HIGHEST=$(printf '%s\n%s\n' "$LATEST" "$VERSION" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)
  [[ "$HIGHEST" == "$VERSION" ]] || fail "Version $VERSION is older than published version $LATEST. Update Info.plist first."
fi
LOCAL_TAG=$(git rev-parse --verify "refs/tags/$TAG" 2>/dev/null || true)
if [[ -n "$REMOTE_TAG" ]]; then
  [[ -z "$LOCAL_TAG" || "$LOCAL_TAG" == "$REMOTE_TAG" ]] || fail "Local $TAG differs from origin. Resolve the conflicting tag without overwriting the published release."
  echo "Version $VERSION is already tagged. Push main only; keep $TAG unchanged."
  REFS=('HEAD:refs/heads/main')
else
  if [[ -n "$LOCAL_TAG" ]]; then
    [[ "$(git rev-parse "$TAG^{commit}")" == "$HEAD_COMMIT" ]] || fail "Local $TAG points to another commit. Inspect it before publishing."
  fi
  echo "New release: $TAG at $HEAD_COMMIT. Push main and $TAG together."
  REFS=('HEAD:refs/heads/main' "refs/tags/$TAG:refs/tags/$TAG")
fi
if $DRY_RUN; then
  echo 'Dry run: no local tag created and nothing pushed.'
  printf 'Would run: git push --atomic origin'; printf ' %s' "${REFS[@]}"; printf '\n'
  echo 'The actual push will enforce remote permissions and fast-forward rules.'
  exit 0
fi
if [[ -z "$REMOTE_TAG" && -z "$LOCAL_TAG" ]]; then
  git tag -a "$TAG" -m "MetalDooM $VERSION preview" "$HEAD_COMMIT"
fi
# Never force: a concurrent release or non-fast-forward main rejects the whole push.
if ! git push --atomic origin "${REFS[@]}"; then
  echo 'Nothing was force-pushed. Inspect the error and retry after resolving it.' >&2
  echo "Any local $TAG tag was retained for inspection/retry." >&2
  exit 1
fi
if [[ -z "$REMOTE_TAG" ]]; then
  echo "Published $TAG. GitHub Actions will build, sign and create the prerelease assets."
  echo 'Check the Actions run for completion; a successful push does not mean the release build passed.'
else
  echo 'Pushed main. GitHub Actions will produce a development build when main changed.'
fi
