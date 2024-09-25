#!/bin/bash


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

# Rebuild the fd cache, used only in autocomplete
function fd-cache-rebuild {
  export FD_PROJECTS="$((cd && find $(echo $FDPATH | tr ':' ' ') -maxdepth 1 -type d 2>/dev/null) | sed -e 's#.*/##' | sort | uniq)"
}

alias fdcr=fd-cache-rebuild

# Rebuild the cache every time we're reloaded
fd-cache-rebuild

# Find repositories in the fd path that have uncommitted changes
function uncommitted {
  s="$1"
  for d in $(echo $FDPATH | tr ':' ' ')
  do
    if [ "${d:0:1}" != "/" ]
    then
      d="$HOME/$d"
    fi
    if [ -d "$d/$s" ]
    then
      (
        for p in $(ls -d $d/$s/*/.git 2>/dev/null)
        do
          cd $(dirname $p)
          diverged="$(git status | grep '\(Your branch and.*have diverged\|Your branch is ahead of\)')"
          git diff-index --quiet HEAD --
          if [ $? != 0 ] || [ -n "$diverged" ]
          then
            echo
            echo "$(tput bold)$(tput setaf 1)=== $(pwd | sed -e "s#$HOME#~#") ===$(tput sgr0)"
            git status
          fi
        done
      )
    fi
  done
}

alias uc=uncommitted

function show-local-working-copies {
  for d in $(echo $FDPATH | tr ':' ' ')
  do
    if [ "${d:0:1}" != "/" ]
    then
      d="$HOME/$d"
    fi
    if [ -d "$d/$s" ]
    then
      (
        for p in $(ls -d $d/$s/*/.git 2>/dev/null)
        do
          loc="$(echo $(dirname $p) | sed -e 's#//#/#g' -e "s#$HOME#~#")"
          remote_url="$(cd $(dirname $p) && git config --get remote.origin.url)"

          baseloc="$(basename $loc)"
          baseurl="$(basename $remote_url .git)"

          if [[ "$baseloc" == "$baseurl" ]]; then
            # echo "$loc ($baseloc): $remote_url ($baseurl)"
            echo
            echo "# $baseloc"
            echo "mkdir -p $(dirname $loc)"
            echo "cd $(dirname $loc) && [ -d $baseloc ] || git clone $remote_url"
          fi
        done
      )
    fi
  done
}

# typeahed / complete function for the 'fd' command
_fd_complete ()   #  By convention, the function name
{                 #+ starts with an underscore.
  local cur
  # Pointer to current completion word.
  # By convention, it's named "cur" but this isn't strictly necessary.

  COMPREPLY=()   # Array variable storing the possible completions.
  cur=${COMP_WORDS[COMP_CWORD]}

  COMPREPLY=( $( compgen -W "$FD_PROJECTS" -- $cur ) )

  return 0
}

complete -F _fd_complete fd

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
