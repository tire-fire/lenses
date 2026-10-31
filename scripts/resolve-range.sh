#!/usr/bin/env bash
set -euo pipefail

ARG="${1:-}"
if [[ "$ARG" == "--followup" || "$ARG" == "followup" ]]; then
  ARG="${2:-}"
fi

if [[ "$ARG" == *".."* ]]; then
  BASE="${ARG%%..*}"
  HEAD_REF="${ARG#*..}"
  BASE_REF="$BASE"
else
  HEAD_REF="HEAD"
  if [[ -n "$ARG" ]]; then
    BASE_REF="$ARG"
  else
    REMOTE="origin"
    if git remote | grep -qx "upstream"; then
      REMOTE="upstream"
    fi
    PR_BASE="$(gh pr view --json baseRefName -q .baseRefName 2>/dev/null || true)"
    if [[ -n "$PR_BASE" ]]; then
      BASE_REF="$REMOTE/$PR_BASE"
    else
      DEF_BRANCH="$(git remote show "$REMOTE" 2>/dev/null | sed -n 's/.*HEAD branch: //p' | head -n1)"
      BASE_REF="$REMOTE/${DEF_BRANCH:-main}"
    fi
  fi
  BASE="$(git merge-base "$BASE_REF" "$HEAD_REF")"
fi

RANGE="${BASE}..${HEAD_REF}"
AHEAD_ON_BASE="$(git rev-list --count "${BASE}..${BASE_REF}" 2>/dev/null || echo 0)"
COMMIT_COUNT="$(git rev-list --count "$RANGE")"

DIFF_FILES="$(git diff --name-only "$RANGE" | sort -u)"
LOG_FILES="$(git log --format= --name-only "$RANGE" | sed '/^$/d' | sort -u)"
EXTRA_IN_LOG="$(comm -13 <(printf '%s\n' "$DIFF_FILES") <(printf '%s\n' "$LOG_FILES") || true)"

echo "BASE_REF=$BASE_REF"
echo "BASE=$BASE"
echo "RANGE=$RANGE"
echo "COMMITS_IN_RANGE=$COMMIT_COUNT"
echo "BASE_COMMITS_AHEAD_OF_MERGE_BASE=$AHEAD_ON_BASE"

while IFS= read -r sha; do
  [[ -z "$sha" ]] && continue
  cfiles="$(git diff --name-only "${sha}^" "$sha" | tr '\n' ' ')"
  echo "COMMIT $(git log -1 --format='%h %s' "$sha") | files: $cfiles"
done < <(git rev-list --reverse "$RANGE")

if [[ -n "$EXTRA_IN_LOG" ]]; then
  echo "WARN_TOUCHED_THEN_REVERTED_FILES:"
  printf '%s\n' "$EXTRA_IN_LOG"
fi
