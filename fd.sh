#!/bin/bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Update our PATH if fd isn't already in the PATH (idempotent add)
[ "$PATH" == "${PATH/fd/}" ] && export PATH="$PATH:$SCRIPT_DIR"

# Use 'title' function to change the name of your Terminal window.
# Make them easier to find in the window list.
function title {
  title="$1"
  if [ -z "$title" ]
  then
    title="$(basename "$(pwd)")"
  fi
  _title "$title"

  termwindow="$HOME/.termwindow/$(tty)"
  mkdir -p "$termwindow"
  echo $title > "$termwindow/title"
  cwd="$(pwd)"
  echo $cwd > "$termwindow/cwd"
  last="n/a"
  if [ -f "$termwindow/stack" ]
  then
    last="$(tail -n 1 $termwindow/stack)"
  fi
  if [ "$cwd" != "$last" ]
  then
    echo $cwd >> $termwindow/stack
  fi
}

function _title {
  printf "\033];$1\007"
}

# Go back to the directory where the 'title' was last run
function restoredir {
  termwindow="$HOME/.termwindow/$(tty)"
  if [ -f "$termwindow/cwd" ]
  then
    cwd="$(cat $termwindow/cwd)"
    title="$(cat $termwindow/title)"
    _title "$title"
    cd "$cwd"
  fi
}

# When this function first loads, restore the
# title and cwd previously saved with this tty.
if [[ -z "$FDRESTORED" ]] ; then
  restoredir
  export FDRESTORED=1
fi

# Pop off the current 'title' directory and then go
# back to the last 'title' directory we were at before.
# If the cwd has moved away from the current directory,
# then this function will just return us to there.
function pd {
  termwindow="$HOME/.termwindow/$(tty)"
  if [ -f "$termwindow/stack" ]
  then
    cur="$(tail -n 1 $termwindow/stack)"
    last="$(tail -n 2 $termwindow/stack | head -n 1)"
  fi
  if [ "$(pwd)" != "$cur" ]
  then
    cd "$cur"
    _title "$(basename $cur)"
  else
    if [ -n "$last" ]
    then
      cd "$last"
      _title "$(basename $last)"
      echo "$cur" > $termwindow/newstack
      cat $termwindow/stack | sed '$d' >> $termwindow/newstack
      mv -f $termwindow/newstack $termwindow/stack
    fi
  fi
}

# Like pd, but goes in the reverse direction
function rd {
  termwindow="$HOME/.termwindow/$(tty)"
  if [ -f "$termwindow/stack" ]
  then
    dir="$(head -n 1 $termwindow/stack)"
  fi
  if [ -n "$dir" ]
  then
    cd "$dir"
    sed $INPLACE -e '1d' $termwindow/stack
    title
  fi
}

# 'bd' from https://github.com/vigneshwaranr/bd - thanks!
# (simplified to just do -s behavior if full match not found)
function bd() {
  if [ $# -eq 0 ]
  then
    echo "Usage: bd <name of some parent folder>" >&2
  else
    OLDPWD=`pwd`

    NEWPWD=`echo $OLDPWD | sed 's|\(.*/'$1'/\).*|\1|'`
    index=`echo $NEWPWD | awk '{ print index($1,"/'$1'/"); }'`
    if [ $index -eq 0 ]
    then
      NEWPWD=`echo $OLDPWD | sed 's|\(.*/'$1'[^/]*/\).*|\1|'`
      index=`echo $NEWPWD | awk '{ print index($1,"/'$1'"); }'`
    fi

    if [ $index -eq 0 ]
    then
      echo "No such occurrence."
    fi

    echo $NEWPWD
    cd "$NEWPWD"
  fi
}

# Utility function: find a directory in the FDPATH
function _find_dir {
	s="$1"
	for d in $(echo $FDPATH | tr ':' ' ')
	do
		if [ "${d:0:1}" != "/" ]
		then
			d="$HOME/$d"
		fi
		if [ -d "$d/$s" ]
		then
			echo "$d/$s"
			break
		fi
	done
}

# Find a directory with a specified name in one of
# our search locations
function fd {
  d="$(_find_dir $1)"
  if [[ -z "$d" ]] ; then
    echo "$1: not found" >&2
    return 1
  fi
  cd "$d"
  title
}

# Print all of the projects in the $FD_PATH
function fd-all {
  local short=0
  if [ "$1" = "-s" ]; then
    short=1
    shift
  fi
  for d in $(echo $FDPATH | tr ':' ' '); do
    if [ "${d:0:1}" != "/" ]; then
      d="$HOME/$d"
    fi
    for repo in "$d"/*/.git; do
      [ -d "$repo" ] || continue
      parent="$(dirname "$repo")"
      if [ $short -eq 1 ]; then
        echo "$(basename "$parent")"
      else
        echo "${parent/#$HOME/~}"
      fi
    done
  done
}

# Rebuild the fd cache, used only in autocomplete
function fd-cache-rebuild {
  source "$HOME/.config/fd/fd-path"
  mkdir -p "$HOME/.config/fd/cache"
  # Use fd-all to list project names (short names) and write to cache file
  fd-all -s > "$HOME/.config/fd/cache/projects"
}

alias fdcr=fd-cache-rebuild

# Add the current git project's parent directory to the fd search path
function fd-add {
  local toplevel
  toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [ -z "$toplevel" ]; then
    echo "Not in a git repository." >&2
    return 1
  fi

  local parent="${toplevel%/*}"
  local relative="${parent#$HOME/}"
  local entry="\"${relative}:\"\\"

  if grep -qF "\"${relative}:\"" "$HOME/.config/fd/fd-path"; then
    echo "$(basename "$toplevel") is already in the fd search path"
    return 0
  fi

  # Insert before the last line (which should always be ".")
  local fdpath="$HOME/.config/fd/fd-path"
  local lastline
  lastline="$(tail -n 1 "$fdpath")"
  sed -i '' -e '$ d' "$fdpath"
  echo "${entry}" >> "$fdpath"
  echo "${lastline}" >> "$fdpath"

  echo "Added ${relative} to the fd search path"
  fd-cache-rebuild
}

# Rebuild the cache every time we're reloaded
fd-cache-rebuild

# Find repositories in the fd path that have uncommitted changes
function uncommitted {
  local filter="$1"
  fd-all | while IFS= read -r repo; do
    if [ -n "$filter" ] && [[ "$repo" != *"/$filter/"* ]]; then
      continue
    fi
    (
      cd "${repo/#\~/$HOME}"
      diverged=$(git status | grep -E '(Your branch and.*have diverged|Your branch is ahead of)')
      if ! git diff-index --quiet HEAD -- || [ -n "$diverged" ]; then
        echo
        echo "$(tput bold)$(tput setaf 1)=== $(pwd | sed -e "s#$HOME#~#") ===$(tput sgr0)"
        git status
      fi
    )
  done
}

alias uc=uncommitted

# New simplified show-local-working-copies using fd-all
function reclone-script {
  local filter="$1"
  fd-all | while IFS= read -r loc; do
    repo="${loc/#\~/$HOME}"
    if [ -n "$filter" ] && [[ "$repo" != *"/$filter/"* ]]; then
      continue
    fi
    (
      remote_url=$(git -C "$repo" config --get remote.origin.url)
      baseloc=$(basename "$loc")
      baseurl=$(basename "$remote_url" .git)
      if [ "$baseloc" = "$baseurl" ]; then
        echo
        echo "# $baseloc"
        echo "mkdir -p $(dirname "$loc")"
        echo "cd $(dirname "$loc") && [ -d $baseloc ] || git clone $remote_url"
      fi
    )
  done
}

# Old name of reclone-script for backwards compatibility
function show-local-working-copies {
  reclone-script "$*"
}

# Check if current branch appears amended compared to remote
is-ammended() {
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

  # Show commit difference counts
  local ahead behind
  ahead=$(git rev-list --count "$remote/$branch"..HEAD)
  behind=$(git rev-list --count HEAD.."$remote/$branch")
  print_header
  echo "Branch '$branch' is $ahead commits ahead and $behind commits behind '$remote/$branch'."
}


# Function to run is-ammended for every project in FDPATH
ammended() {
  local remote="${1:-origin}"
  fd-all | while IFS= read -r repo; do
    # Expand ~ to $HOME for cd
    local dir="${repo/#\~/$HOME}"
    if [ -d "$dir" ]; then
      (cd "$dir" && is-ammended "$remote")
    else
      echo "Warning: directory $dir does not exist" >&2
    fi
  done
}

# typeahed / complete function for the 'fd' command
_fd_complete ()   #  By convention, the function name
{                 #+ starts with an underscore.
  local cur
  # Pointer to current completion word.
  # By convention, it's named "cur" but this isn't strictly necessary.

  COMPREPLY=()
  cur=${COMP_WORDS[COMP_CWORD]}

  # Load projects list from cache if available
  local projects_file="$HOME/.config/fd/cache/projects"
  local project_list=""
  if [ -f "$projects_file" ]; then
    project_list=$(tr '\n' ' ' < "$projects_file")
  fi

  COMPREPLY=( $(compgen -W "$project_list" -- "$cur") )

  return 0
}

complete -F _fd_complete fd
complete -F _fd_complete pfd

function @ {
	d="$(_find_dir $1)"
	if [[ -z "$d" ]] ; then
		echo "$1: not found" >&2
		return 1
	fi
	shift
	(
		TEXT_RESET='\033[0m'
		TEXT_GREEN='\033[0;32m'

		relative="$(echo $d | sed -e "s#$HOME#~#")"

		# Favor commands local to the directory over commands with the same name in the $PATH
		PATH="bin:vendor/bin:$PATH"

		printf "${TEXT_GREEN}> cd ${relative}; $@${TEXT_RESET}\n"
		cd "$d"; "$@"
	)
}

# TODO: This works for the first parameter, but we need to figure out how to call through to the default autocomplete.
complete -F _fd_complete @


if type cdd >/dev/null 2>&1 ; then
  alias ..=cdd
  complete -o dirnames -o nospace -F _cdd ..
else
  alias ..='cd ..'
fi

