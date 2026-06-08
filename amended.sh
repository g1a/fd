#!/usr/bin/env bash

# Stand‑alone script that mirrors the behaviour of the fd utilities
# for users who have not installed the fd script.
# It first builds FDPATH (list of project directories) the same way
# as fd‑suggest.sh, then defines its own fd‑all, is‑amended and amended
# functions and finally runs amended on all projects.

# -----------------------------------------------------------------
# Build FDPATH – identical to fd‑suggest.sh
# -----------------------------------------------------------------
fd-suggest() {
  # Find directories that contain a .git folder, up to depth 5 under $HOME,
  # excluding common unwanted paths.
  FDPATH=$(cd "$HOME" && find . -maxdepth 5 -type d \( -path './Library' -o -path '*/vendor' -o -path './Downloads' -o -path '*/tmp' -o -path './.Trash' \) -prune -o -name ".git" -print |
    sed -e 's#^./##' |
    grep '/[^/]*/' |
    sed -e 's#/[^/]*/.git$##' |
    sort | uniq |
    tr '\n' ':' |
    sed 's/:$//') 2>/dev/null
  export FDPATH
  export FDPATH
}

# -----------------------------------------------------------------
# fd‑all – list all project directories (short names when -s is given)
# -----------------------------------------------------------------
fd-all() {
  local short=0
  if [ "$1" = "-s" ]; then
    short=1
    shift
  fi
  IFS=':' read -ra dirs <<< "$FDPATH"
  for d in "${dirs[@]}"; do
    # Expand leading ~ if present (should not be, but keep parity)
    [[ "$d" == ~* ]] && d="$HOME/${d#~}"
    if [ -d "$d" ]; then
      for repo in "$d"/*/.git; do
        [ -d "$repo" ] || continue
        parent=$(dirname "$repo")
        if [ $short -eq 1 ]; then
          echo "$(basename "$parent")"
        else
          echo "${parent/#$HOME/~}"
        fi
      done
    fi
  done
}

# -----------------------------------------------------------------
# is‑amended – check a single repository for amendment status
# -----------------------------------------------------------------
is-amended() {
  local default_remote="${1:-origin}"
  # Determine which remote to use: prefer the requested one if it exists, otherwise pick the first remote.
  local remote
  if git remote | grep -qx "$default_remote"; then
    remote=$default_remote
  else
    remote=$(git remote | head -n1)
  fi
  # If there is no remote configured, skip this repository.
  if [ -z "$remote" ]; then
    return 0
  fi

  # Determine current branch
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null) || { echo "Not a git repository." >&2; return 1; }

  # Helper to print a header once per repository
  local printed_header=0
  print_header() {
    if [ $printed_header -eq 0 ]; then
      echo
      echo "=== $(pwd | sed -e \"s#$HOME#~#\") ==="
      printed_header=1
    fi
  }

  # Verify the branch exists on the remote
  if ! git ls-remote --heads "$remote" "$branch" | grep -q "$branch"; then
    print_header
    echo "Warning: branch '$branch' does not exist on remote '$remote'."
    return 0
  fi

  local local_sha remote_sha
  local_sha=$(git rev-parse HEAD)
  remote_sha=$(git rev-parse "$remote/$branch")

  # If the local HEAD exists anywhere in the remote, stay silent
  if git branch -r --contains "$local_sha" >/dev/null 2>&1; then
    return 0
  fi

  # If the remote HEAD exists anywhere in the local history, stay silent
  if git merge-base --is-ancestor "$remote_sha" HEAD; then
    return 0
  fi

  # If both SHAs are identical, nothing to report
  if [ "$local_sha" = "$remote_sha" ]; then
    return 0
  fi

  # Compare author and subject of the two HEAD commits
  local local_info remote_info
  local_info=$(git log -1 --pretty=format:%an:%s "$local_sha")
  remote_info=$(git log -1 --pretty=format:%an:%s "$remote_sha")

  if [ "$local_info" = "$remote_info" ]; then
    print_header
    echo "Warning: branch '$branch' appears amended (author and message match remote)."
    return 0
  fi

  # Show how many commits differ
  local ahead behind
  ahead=$(git rev-list --count "$remote/$branch"..HEAD)
  behind=$(git rev-list --count HEAD.."$remote/$branch")
  print_header
  echo "Branch '$branch' is $ahead commits ahead and $behind commits behind '$remote/$branch'."
}


# -----------------------------------------------------------------
# amended – run is‑amended for every project discovered by fd‑all
# -----------------------------------------------------------------
amended() {
  local remote="${1:-origin}"
  fd-all | while IFS= read -r repo; do
    # Expand ~ to $HOME for navigation
    local dir="${repo/#\~/$HOME}"
    if [ -d "$dir" ]; then
      (cd "$dir" && is-amended "$remote")
    else
      echo "Warning: directory $dir does not exist" >&2
    fi
  done
}

# -----------------------------------------------------------------
# Execute
# -----------------------------------------------------------------

cd "$HOME"

# Initialise FDPATH for this script
echo '### Finding project directories'
fd-suggest

echo
echo "Searching for projects in the following locations:"
echo $FDPATH

echo
echo '### Found the following projects:'
fd-all
echo
echo '### Searching for projects with amended branches'

amended "$@"
