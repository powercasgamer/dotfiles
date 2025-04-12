# Git Switch Fetch Pull
function gsfp() {
  if [ -z "$1" ]; then
    echo "Usage: gsfp <branch>"
    echo "Error: branch name is required."
    return 1
  fi

  local current_branch=$(git symbolic-ref --short HEAD 2>/dev/null)
  local target_branch="$1"

  # Check if we're already on the target branch
  if [[ "$current_branch" != "$target_branch" ]]; then
    echo "Switching to branch '$target_branch'..."
    if ! git switch "$target_branch" 2>/dev/null; then
      # If switch fails, try checkout with tracking
      echo "Branch not found locally, attempting to create tracking branch..."
      if ! git switch -c "$target_branch" --track "origin/$target_branch"; then
        echo "Error: Failed to switch to branch '$target_branch'"
        return 2
      fi
    fi
  else
    echo "Already on branch '$target_branch'"
  fi

  # Fetch and pull with verbose output
  echo "Fetching latest changes..."
  git fetch --prune &&
    echo "Pulling changes..." &&
    git pull --ff-only &&
    echo "Branch '$target_branch' is up to date with origin" || {
    echo "Error: Failed to update branch '$target_branch'"
    return 3
  }
}
