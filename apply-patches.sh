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
    if git apply --check --reverse --ignore-whitespace "$patch" 2>/dev/null; then
        echo "    Already applied, skipping."
        git am --skip
        continue
    fi
    # Retry with 3-way merge (handles context drift using blob OIDs from the patch)
    git am --abort 2>/dev/null || true
    if git am --3way "$patch" 2>/dev/null; then
        continue
    fi
    # Real conflict — abort and surface the error
    git am --abort 2>/dev/null || true
    echo "Error: patch failed to apply: $(basename "$patch")" >&2
    exit 1
done < <(find "$PATCHES_DIR" -name "*.patch" | sort -V)

echo "Done."
