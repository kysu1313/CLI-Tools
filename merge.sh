#!/bin/bash

# Arguments:
# $1 = source branch (branch to merge from)
# $2 = target branch (branch to merge into)
# $3 = optional folder pattern in quotes (default apexportal.upp.*)

SRC_BRANCH="${1:?Source branch required}"
TGT_BRANCH="${2:?Target branch required}"
PATTERN="${3:-apexportal.upp.*}"

TMPDIR=$(mktemp -d)
CONFLICTS_FILE="$TMPDIR/conflicts.txt"

echo "Source branch (to merge from): $SRC_BRANCH"
echo "Target branch (to merge into): $TGT_BRANCH"
echo "Folder pattern: \"$PATTERN\""
echo

update_and_merge() {
  local dir="$1"

  echo "Processing $dir"

  cd "$dir" || { echo "Failed to cd into $dir"; return; }

  # Fetch latest branches quietly
  git fetch origin "$SRC_BRANCH" "$TGT_BRANCH" --quiet

  # Checkout target branch quietly
  if ! git checkout "$TGT_BRANCH" --quiet; then
    echo "❌ Cannot checkout target branch $TGT_BRANCH in $dir"
    cd ..; return
  fi

  # Reset to remote target branch to have clean state
  git reset --hard "origin/$TGT_BRANCH" --quiet

  # Try to merge source branch, redirect stdout and stderr to temp file
  TMP_MERGE_LOG=$(mktemp)
  if git merge --no-commit --no-ff "origin/$SRC_BRANCH" >"$TMP_MERGE_LOG" 2>&1; then
    git commit -m "Auto-merge $SRC_BRANCH into $TGT_BRANCH" --quiet
    git push origin "$TGT_BRANCH" --quiet
    echo "✅ Merged $SRC_BRANCH into $TGT_BRANCH and pushed."
  else
    git merge --abort
    echo "⚠️ Conflicts detected in $dir, manual resolution required."
    echo "$dir" >> "$CONFLICTS_FILE"
  fi
  rm -f "$TMP_MERGE_LOG"

  cd .. || exit
}

# Loop through repos and run merges
for dir in $PATTERN/; do
  [ -d "$dir/.git" ] || { echo "Skipping non-git directory: $dir"; continue; }
  update_and_merge "$dir"
done

echo
if [ -f "$CONFLICTS_FILE" ] && [ -s "$CONFLICTS_FILE" ]; then
  echo "The following repositories have conflicts and require manual resolution:"
  cat "$CONFLICTS_FILE"
else
  echo "All repositories merged cleanly without conflicts."
fi

rm -rf "$TMPDIR"
