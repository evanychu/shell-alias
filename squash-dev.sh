#!/usr/bin/bash
set -e

# Help/Usage message
show_usage() {
  echo "Usage: $0 [options]"
  echo "Squashes consecutive 'dev' commits at the tip of the current branch."
  echo "Stops squashing at the first commit that does not have the title 'dev'."
  echo ""
  echo "Options:"
  echo "  -h, --help     Show this help message"
  echo "  -n, --dry-run  Show what would be squashed without making changes"
}

# Parse options
dry_run=false
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    -h|--help)
      show_usage
      exit 0
      ;;
    -n|--dry-run)
      dry_run=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      show_usage >&2
      exit 1
      ;;
  esac
done

# Ensure we are inside a git repository
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Error: Not a git repository." >&2
  exit 1
fi

# Ensure there is at least one commit
if ! git rev-parse HEAD >/dev/null 2>&1; then
  echo "Error: Current branch has no commits." >&2
  exit 1
fi

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
  echo "Error: You have uncommitted changes. Please commit, stash, or discard them first." >&2
  exit 1
fi

# Get the list of commit subjects starting from HEAD
commits_subjects=()
commits_hashes=()

# We read the hash and subject of commits
while read -r hash subject; do
  commits_hashes+=("$hash")
  commits_subjects+=("$subject")
done < <(git log --format="%H %s")

# Count consecutive "dev" commits from HEAD
dev_count=0
for subject in "${commits_subjects[@]}"; do
  if [ "$subject" = "dev" ]; then
    dev_count=$((dev_count + 1))
  else
    break
  fi
done

total_commits=${#commits_subjects[@]}

if [ "$dev_count" -eq 0 ]; then
  echo "The tip commit of the branch is not 'dev'. Nothing to squash."
  exit 0
fi

if [ "$dev_count" -eq "$total_commits" ]; then
  echo "Error: All commits on this branch are 'dev' commits. There is no non-'dev' commit to squash into." >&2
  exit 1
fi

target_commit_hash="${commits_hashes[dev_count]}"
target_commit_subject="${commits_subjects[dev_count]}"

echo "Found $dev_count consecutive 'dev' commits to squash into the first non-'dev' commit:"
for ((i=0; i<dev_count; i++)); do
  echo "  ${commits_hashes[i]:0:7} - ${commits_subjects[i]}"
done
echo "Target commit to squash into:"
echo "  ${target_commit_hash:0:7} - ${target_commit_subject}"

if [ "$dry_run" = true ]; then
  echo "Dry run: Would squash the $dev_count 'dev' commits into: '${target_commit_subject}'"
  exit 0
fi

# Perform squash
echo "Squashing..."
git reset --soft HEAD~"$dev_count"
git commit --amend --no-edit

echo "Successfully squashed $dev_count 'dev' commits into the non-'dev' commit!"
echo "New commit log:"
git log --oneline -n 5
