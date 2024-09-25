#!/bin/bash

#
# fd install script
#
# To install:
#
#     $ source fd-install.sh [--bashrc | --bash_profile | --profile]
#
# By default, this script will install to ~/.bash_profile, unless it looks like
# ~/.bash_profile sources ~/.bashrc (recommended), in which case we install to ~/.bashrc.
# You may stipulate the exact install location by providing the appropriate flag.
#

WITH_CDD=false
FDRC="$HOME/.fdrc"

# Get the path to the directory this script was ran from
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# Presume that we will install to .bash_profile. If it looks like
# .bash_profile is including .bashrc, then we will install to .bashrc.
INSTALL_TO=".bash_profile"
if [ ! -f "$INSTALL_TO" ] || grep -q bashrc "$HOME/$INSTALL_TO" ; then
	INSTALL_TO=".bashrc"
fi

# Parse options
while [ $# -gt 0 ] ; do
	option=$1
	shift

	case "$option" in
		--with-cdd )
			WITH_CDD=true
			;;

		--no-cdd )
			WITH_CDD=false
			;;

		--bashrc )
			INSTALL_TO=".bashrc"
			;;

		--bash_profile )
			INSTALL_TO=".bash_profile"
			;;

		--profile )
			INSTALL_TO=".profile"
			;;
	esac
done

# Disable requested install of cdd if it is already present
if $WITH_CDD && grep -q cddrc "$HOME/$INSTALL_TO" ; then
	echo 'Skipping install of cdd, as it is already present.'
fi

# Install cdd first, if requested
if $WITH_CDD ; then
	CDDRC="$HOME/.cddrc"
	CDD_PATH="$(dirname -- $SCRIPT_DIR)/cdd"
	git clone https://github.com/scriptworld/cdd.git "$CDD_PATH"

	# Write the sourcing of the cdd scripts to our .cddrc file
	cat <<- __EOF__ > $CDDRC

		# Source the cdd script
		source "$CDD_PATH/cdd.sh"
		source "$CDD_PATH/cdd-completion.bash"
__EOF__

	echo 'Created new ~/.cddrc configuration file.'

	cat <<- __EOF__ >> "$HOME/$INSTALL_TO"

		# Source the cdd configuration file.
		# See: https://github.com/scriptworld/cdd
		source "$HOME/.cddrc"
__EOF__
	echo "Installed 'source ~/.cddrc' in ~/$INSTALL_TO"

	# Source cdd so that it is available in this shell
	source ~/.cddrc
fi

# Do not overwrite existing installations
if [ -f "$FDRC" ] ; then
	echo "fd is already installed (~/.fdrc file exists)"
	return
fi

# Source the fd-suggest.sh file so that function is available
source "$SCRIPT_DIR/fd-suggest.sh"

# Write the header of our .fdrc file
cat <<- __EOF__ > $FDRC
	#!/bin/bash

	#
	# Configuration file for fd script
	# See: https://github.com/g1a/fd
	#

	# Use fd-suggest to refresh the FDPATH setting below.
	source "$SCRIPT_DIR/fd-suggest.sh"

	# List directory search location.
	# Customize to suit
__EOF__

# Add the initial `fd-suggest` list to the configuration file
fd-suggest >> $FDRC

# Write the sourcing of the fd scripts to our .fdrc file
cat <<- __EOF__ >> $FDRC

	# Source the fd script
	source "$SCRIPT_DIR/fd.sh"
__EOF__

echo 'Created new ~/.fdrc configuration file.'

# If it looks like the fdrc file is already being sourced, then exit.
if grep -q fdrc "$HOME/$INSTALL_TO" ; then
	echo "~/.fdrc configuration file is already sourced from ~/$INSTALL_TO)"
	return
fi

cat <<- __EOF__ >> "$HOME/$INSTALL_TO"

	# Source the fd configuration file.
	# See: https://github.com/g1a/fd
	source "$HOME/.fdrc"
__EOF__

echo "Installed 'source ~/.fdrc' in ~/$INSTALL_TO"

# Source fd so that it is available in this shell.
source ~/.fdrc
