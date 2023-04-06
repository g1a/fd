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

# Find a directory with a specified name in one of
# our search locations
function fd {
  s="$1"
  for d in $(echo $FDPATH | tr ':' ' ')
  do
    if [ "${d:0:1}" != "/" ]
    then
      d="$HOME/$d"
    fi
    if [ -d "$d/$s" ]
    then
      cd "$d/$s"
      title
      break
    fi
  done
}

# Rebuild the fd cache, used only in autocomplete
function fd-cache-rebuild {
  export FD_PROJECTS="$((cd && find $(echo $FDPATH | tr ':' ' ') -maxdepth 1 -type d 2>/dev/null) | sed -e 's#.*/##' | sort | uniq)"
}

alias fdcr=fd-cache-rebuild

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

function fd-suggest {
  FDPATH=$(cd $HOME; find . -maxdepth 5 -type d \( -path './Library' -o -path '*/vendor' -o -path './Downloads' -o -path './.*' -o -path '*/tmp' \) -prune -o -name ".git" -print | sed -e 's#^./##' | grep '/[^/]*/' | sed -e 's#/[^/]*/.git$##' | sort | uniq | sed -e 's/^/"/' -e 's/$/:"\\/g')
  echo "export FDPATH=\\"
  echo "$FDPATH"
  echo '"."'
}

if [[ -n "$(type cdd 2>&1)" ]] ; then
  alias ..=cdd
  complete -o dirnames -o nospace -F _cdd ..
else
  alias ..='cd ..'
fi
