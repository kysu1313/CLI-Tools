#!/bin/bash

# First argument = branch name
BRANCH="${1:-dev/merged-repo}"

# Second argument = folder pattern
PATTERN="${2:-apexportal.upp.*}"

GENERAL_ERROR="Usage:
    $0 [branch] [folder_pattern]
    branch: The branch to pull (default: dev/merged-repo)
    folder_pattern: The pattern to match folders (default: apexportal.upp.*)
Example:
    $0 dev/merged-repo apexportal.upp.*"

# Check if git is installed
if ! command -v git &> /dev/null; then
        echo "❌ git is not installed. Please install git to use this script."
        echo "$GENERAL_ERROR"
        exit 1
fi

echo "Branch to pull: $BRANCH"
echo "Folder pattern: $PATTERN"
echo "Searching for directories matching pattern: $PATTERN"

TMPDIR=$(mktemp -d)

update_repo() {
  local dir="$1"
  local branch="$2"
  local tmpfile="$3"

  echo "Updating repository: $dir (branch: $branch)"
  cd "$dir" || return

  git fetch origin "$branch" 2>/dev/null

  git checkout "$branch" 2>/dev/null || {
    echo "❌ Branch '$branch' not found in $dir"
    cd ..
    return
  }

  if git ls-remote --exit-code --heads origin "$branch" &> /dev/null; then
    before=$(git rev-parse HEAD)
    git pull origin "$branch" --quiet
    after=$(git rev-parse HEAD)

    if [ "$before" != "$after" ]; then
      echo "$dir" >> "$tmpfile"
      echo "Updated $dir: $before -> $after"
    else
      echo "No updates for $dir"
    fi
  else
    echo "❌ Branch '$branch' does not exist on the remote for $dir"
  fi

  cd .. || exit
}

# Array to store updated repositories
UPDATED_REPOS=()

# Loop through matching folders
for pattern in $PATTERN/; do
  dirs=( $pattern/ )
  if [ ! -d "${dirs[0]}" ]; then
    echo "❌ No directories found for pattern: $pattern"
    continue
  fi

  for dir in "${dirs[@]}"; do
    [ -d "$dir" ] || continue

    echo "Checking if $dir is a git repo..."
    if [ -d "$dir/.git" ]; then
      tmpfile="$TMPDIR/updated_$(basename "$dir").txt"
      echo "Processing directory: $dir"
      update_repo "$dir" "$BRANCH" "$tmpfile" &
    else
      echo "Skipping (not a git repo): $dir"
    fi
  done
done

wait

# Combine all updated repositories into a single array
UPDATED_REPOS=()
for f in "$TMPDIR"/*.txt; do
  [ -f "$f" ] || continue
  while IFS= read -r line; do
    UPDATED_REPOS+=("$line")
  done < "$f"
done

rm -rf "$TMPDIR"

# Print summary
if [ ${#UPDATED_REPOS[@]} -gt 0 ]; then
  echo "✅ The following repositories were updated:"
  for repo in "${UPDATED_REPOS[@]}"; do
    echo "  - $repo"
  done
else
  echo "❌ No repositories were updated."
fi

echo "✅ All matching repositories processed."
