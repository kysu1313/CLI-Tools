#!/bin/bash

BRANCH="${1:-dev/merged-repo}"

shift  # Remove branch from argument list

# If no folder patterns given, use default
if [ "$#" -eq 0 ]; then
  PATTERNS=(apexportal.upp.*)
else
  PATTERNS=("$@")
fi

GENERAL_ERROR="Usage:
    $0 [branch] [folder_pattern ...]
    branch: The branch to pull (default: dev/merged-repo)
    folder_pattern: One or more folder patterns (default: apexportal.upp.*)
Example:
    $0 dev/merged-repo apexportal.upp.* Console*"

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "❌ git is not installed. Please install git to use this script."
    echo "$GENERAL_ERROR"
    exit 1
fi

echo "Branch to pull: $BRANCH"
echo "Folder patterns: ${PATTERNS[*]}"

UPDATED_REPOS=()

for pattern in "${PATTERNS[@]}"; do
  # Expand pattern to directories ending with slash
  dirs=( $pattern/ )
  # Check if any matched
  if [ ! -d "${dirs[0]}" ]; then
    echo "❌ No directories found for pattern: $pattern"
    continue
  fi

  for dir in "${dirs[@]}"; do
    # skip if not a directory
    [ -d "$dir" ] || continue

    # Check if the folder contains a .git directory
    if [ -d "$dir/.git" ]; then
      echo "Updating repository: $dir (branch: $BRANCH)"
      cd "$dir" || continue

      git fetch origin "$BRANCH" 2>/dev/null

      git checkout "$BRANCH" 2>/dev/null || {
        echo "❌ Branch '$BRANCH' not found in $dir"
        cd ..
        continue
      }

      if git ls-remote --exit-code --heads origin "$BRANCH" &>/dev/null; then
        git pull origin "$BRANCH"
        UPDATED_REPOS+=("$dir")
      else
        echo "❌ Branch '$BRANCH' does not exist on the remote for $dir"
      fi

      cd .. || exit
    else
      echo "Skipping (not a git repo): $dir"
    fi
  done
done

if [ ${#UPDATED_REPOS[@]} -gt 0 ]; then
  echo "✅ The following repositories were updated:"
  for repo in "${UPDATED_REPOS[@]}"; do
    echo "  - $repo"
  done
else
  echo "❌ No repositories were updated."
fi

echo "✅ All matching repositories processed."
