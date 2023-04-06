#!/bin/bash

FDRC="$HOME/.fdrc"

# Do not overwrite existing installations
if [ -f "$FDRC" ] ; then
  echo "fd is already installed"
  return
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

source "$SCRIPT_DIR/fd.sh"

cat << __EOF__ > $FDRC
# Source the fd script
source "$SCRIPT_DIR/fd.sh"

# List directory search location
__EOF__

fd-suggest >> $FDRC

