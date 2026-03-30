#!/usr/bin/env bash
# Apply all patches from ./patches/ to the current branch,
# or create a new branch from upstream/develop first with -b <name>.
set -euo pipefail

PATCHES_DIR="$(dirname "$0")/patches"

if [ "${1:-}" = "-b" ]; then
    BRANCH_NAME="${2:?-b requires a branch name}"
    echo "Fetching upstream..."
    git fetch upstream
    echo "Creating branch '$BRANCH_NAME' from upstream/develop..."
    git checkout -b "$BRANCH_NAME" upstream/develop
fi

echo "Applying patches..."
while IFS= read -r patch; do
    echo "  $(basename "$patch")"
    if git am "$patch" 2>/dev/null; then
        continue
    fi
    # Check if the patch is already applied (reverse applies cleanly)
    if git apply --check --reverse "$patch" 2>/dev/null; then
        echo "    Already applied, skipping."
        git am --skip
        continue
    fi
    # Real conflict — abort and surface the error
    git am --abort
    echo "Error: patch failed to apply: $(basename "$patch")" >&2
    exit 1
done < <(find "$PATCHES_DIR" -name "*.patch" | sort -V)

echo "Done."
