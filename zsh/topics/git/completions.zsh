# Git branch completions for gsfp function
_gsfp() {
  local -a git_branches
  local current_branch

  # Get local and remote branches (excluding HEAD)
  git_branches=(
    ${${(f)"$(git branch --no-color 2>/dev/null | sed -E 's/^\*? +//')"}
    ${${(f)"$(git branch --no-color -r 2>/dev/null | grep -v HEAD | sed -E 's/^ +//')"}
  )

  # Highlight current branch with *
  current_branch=$(git branch --show-current 2>/dev/null)
  if [[ -n "$current_branch" ]]; then
    git_branches=("${git_branches[@]/#$current_branch/*$current_branch}")
  fi

  _describe -t branches 'branch' git_branches
}

compdef _gsfp gsfp