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
FD_CONFIG_DIR="$HOME/.config/fd"
FDRC="$FD_CONFIG_DIR/fdrc"
FD_PATH="$FD_CONFIG_DIR/fd-path"

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
	CDDRC="$FD_CONFIG_DIR/cddrc"
	mkdir -p "$FD_CONFIG_DIR"
	CDD_PATH="$(dirname -- $SCRIPT_DIR)/cdd"
	git clone https://github.com/scriptworld/cdd.git "$CDD_PATH"

	# Write the sourcing of the cdd scripts to our .cddrc file
	cat <<- __EOF__ > $CDDRC

		# Source the cdd script
		source "$CDD_PATH/cdd.sh"
		source "$CDD_PATH/cdd-completion.bash"
__EOF__

	echo 'Created new ~/.config/fd/cddrc configuration file.'

	cat <<- __EOF__ >> "$HOME/$INSTALL_TO"

		# Source the cdd configuration file.
		# See: https://github.com/scriptworld/cdd
		source "$HOME/.config/fd/cddrc"
__EOF__
	echo "Installed 'source ~/.config/fd/cddrc' in ~/$INSTALL_TO"

	# Source cdd so that it is available in this shell
	source ~/.config/fd/cddrc
fi

# Do not overwrite existing installations
if [ -f "$FDRC" ] ; then
	echo "fd is already installed (~/.config/fd/fdrc file exists)"
	return
fi

# Ensure config directory exists
mkdir -p "$FD_CONFIG_DIR"

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

	# Source the fd script
	source "$SCRIPT_DIR/fd.sh"
__EOF__

# Add the initial `fd-suggest` list to the configuration file
(
	echo '#!/bin/bash'
	echo
	echo '# List directory search locations.'
	echo '# Customize to suit'
	fd-suggest
) >> $FD_PATH

echo 'Created new ~/.config/fd/fdrc configuration file and ~/.config/fd/fd-path file.'

# If it looks like the fdrc file is already being sourced, then exit.
if grep -q fdrc "$HOME/$INSTALL_TO" ; then
	echo "~/.config/fd/fdrc configuration file is already sourced from ~/$INSTALL_TO)"
	return
fi

cat <<- __EOF__ >> "$HOME/$INSTALL_TO"

	# Source the fd configuration file.
	# See: https://github.com/g1a/fd
	source "$HOME/.config/fd/fdrc"
__EOF__

echo "Installed 'source ~/.config/fd/fdrc' in ~/$INSTALL_TO"

# Source fd so that it is available in this shell.
source ~/.config/fd/fdrc
