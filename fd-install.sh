#!/bin/bash

#
# fd install script
#
# To install:
#
# $ source fd-install.sh
#

FDRC="$HOME/.fdrc"

# Do not overwrite existing installations
if [ -f "$FDRC" ] ; then
  echo "fd is already installed (~/.fdrc file exists)"
  return
fi

# Get the path to the directory this script was ran from
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Source the fd.sh file so that `fd-suggest` is available
source "$SCRIPT_DIR/fd.sh"

# Write our .fdrc file
cat << __EOF__ > $FDRC
#
# Configuration file for fd script
# See: https://github.com/g1a/fd
#

# Source the fd script
source "$SCRIPT_DIR/fd.sh"

# List directory search location.
# Customize to suit
__EOF__

# Add the initial `fd-suggest` list to the configuration file
fd-suggest >> $FDRC

echo 'Created new ~/.fdrc configuration file.'

# Presume that we will install to .bash_profile. If it looks like
# .bash_profile is including .bashrc, then we will install to .bashrc.
INSTALL_TO=".bash_profile"
if [ ! -f "$INSTALL_TO" ] || grep -q bashrc "$HOME/$INSTALL_TO" ; then
  INSTALL_TO=".bashrc"
fi

# If it looks like the fdrc file is already being sourced, then exit.
if grep -q fdrc "$HOME/$INSTALL_TO" ; then
  echo "~/.fdrc configuration file is already sourced from ~/$INSTALL_TO)"
  return
fi

cat << __EOF__ >> "$HOME/$INSTALL_TO"

# Source the fd configuration file.
# See: https://github.com/g1a/fd
source "$HOME/.fdrc"
__EOF__

echo "Installed ~/.fdrc in ~/$INSTALL_TO"
