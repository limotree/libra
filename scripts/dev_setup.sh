#!/bin/bash
# Copyright (c) The Libra Core Contributors
# SPDX-License-Identifier: Apache-2.0
# This script sets up the environment for the Libra build by installing necessary dependencies.
#
# Usage ./dev_setup.sh <options>
#   v - verbose, print all statements

# Assumptions for nix systems:
# 1 The running user is the user who will execute the builds.
# 2 .profile will be used to configure the shell
# 3 ${HOME}/bin/ is expected to be on the path - hashicorp tools/hadolint/etc.  will be installed there on linux systems.

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_PATH/.."

function usage {
  echo "Usage:"
  echo "Installs or updates necessary dev tools for libra/libra."
  echo "-b batch mode, no user interactions and miminal output"
  echo "-o intall operations tooling as well: helm, terraform, hadolint, yamllint, vault, docker, kubectl, python3"
  echo "-v verbose mode"
  echo "should be called from the root folder of the libra project"
}

function install_hadolint {
  mkdir -p ${HOME}/bin
  export HADOLINT=${HOME}/bin/hadolint
  export HADOLINT_VER=v1.17.4
  curl -sL -o ${HADOLINT} "https://github.com/hadolint/hadolint/releases/download/${HADOLINT_VER}/hadolint-$(uname -s)-$(uname -m)" && chmod 700 ${HADOLINT}
}


function install_helm {

}

function install_terraform {

}

function install_vault {

}

function install_kubectl {

}

function install_pkg {
    package=$1
    package_manager=$2
    pre_command=""
    if [ `whoami` != 'root' ]; then
      pre_command="sudo "
    fi
    if which $package &>/dev/null; then
        echo "$package is already installed"
    else
        echo "Installing $package."
        if [[ "$PACKAGE_MANAGER" == "yum" ]]; then
                $PRE_COMMAND yum install $package -y
        elif [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
                $PRE_COMMAND apt-get install $package -y
        elif [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
                $PRE_COMMAND pacman -Syu $package --noconfirm
        elif [[ "$PACKAGE_MANAGER" == "brew" ]]; then
                brew install $package
        fi
    fi
}

function install_toolchain {
  version=$1
  if [[ "rustup show | grep $version | wc -l" == "0" ]]; then
    rustup install $version
  else
    echo "$version rust toolchain already installed"
  fi
}

function welcome_message {
cat <<EOF
Welcome to Libra!

This script will download and install the necessary dependencies needed to
build, test and inspect Libra Core. This includes:
	* Rust (and the necessary components, e.g. rust-fmt, clippy)
	* Useful rust tooling (grcov for for code coverage)
	* CMake
	* Clang
        * pkg-config
        * libssl-dev
	* lcov

If you'd prefer to install these dependencies yourself, please exit this script
now with Ctrl-C.
EOF
}

BATCH_MODE=false;
VERBOSE=false;
OPERATIONS=false;

#parse args
while getopts "bvho" arg; do
  case $arg in
    b)
      BATCH_MODE="true"
      ;;
   o)
      OPERATIONS="true"
      ;;
    v)
      VERBOSE=true
      ;;
    h)
      usage;
      exit 0;
      ;;
  esac
done

if [[ $VERBOSE == "true" ]]; then
	set -x
fi

if [ ! -f rust-toolchain ]; then
	echo "Unknown location. Please run this from the libra repository. Abort."
	exit 1
fi

PACKAGE_MANAGER=
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
	if which yum &>/dev/null; then
		PACKAGE_MANAGER="yum"
	elif which apt-get &>/dev/null; then
		PACKAGE_MANAGER="apt-get"
	elif which pacman &>/dev/null; then
		PACKAGE_MANAGER="pacman"
	else
		echo "Unable to find supported package manager (yum, apt-get, or pacman). Abort"
		exit 1
	fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
	if which brew &>/dev/null; then
		PACKAGE_MANAGER="brew"
	else
		echo "Missing package manager Homebrew (https://brew.sh/). Abort"
		exit 1
	fi
else
	echo "Unknown OS. Abort."
	exit 1
fi

if [[ $BATCH_MODE == "false" ]]; then
    welcome_message
    printf "Proceed with installing necessary dependencies? (y/N) > "
    read -e input
    if [[ "$input" != "y"* ]]; then
	    echo "Exiting..."
	    exit 0
    fi
fi

PRE_COMMAND=""
if [ `whoami` != 'root' ]; then
  PRE_COMMAND="sudo "
fi

if [[ $"$PACKAGE_MANAGER" == "apt-get" ]]; then
	[[ BATCH_MODE == "false" ]] && echo "Updating apt-get......"
	$PRE_COMMAND apt-get update
fi


install_pkg cmake $PACKAGE_MANAGER $BATCH_MODE
install_pkg clang $PACKAGE_MANAGER $BATCH_MODE
install_pkg llvm $PACKAGE_MANAGER $BATCH_MODE
install_pkg curl $PACKAGE_MANAGER $BATCH_MODE

#need to change....
install_pkg libssl-dev $PACKAGE_MANAGER $BATCH_MODE
install_pkg pkg-config $PACKAGE_MANAGER $BATCH_MODE  # pkgconfig in centos

# Install Rust
[[ BATCH_MODE == "false" ]] && echo "Installing Rust......"
if rustup --version &>/dev/null; then
	[[ BATCH_MODE == "false" ]] && echo "Rust is already installed"
else
	curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain stable
	CARGO_ENV="$HOME/.cargo/env"
	source "$CARGO_ENV"
fi

# Run update in order to download and install the checked in toolchain

install_toolchain `cat ./cargo-toolchain`
install_toolchain `cat ./rust-toolchain`

# Add all the components that we need
rustup component add rustfmt
rustup component add clippy
cargo install grcov

if [[ `sccache --version` != "sccache 0.2.13" ]]; then
  cargo install sccache --version=0.2.13
fi

if [[ $OPERATIONS == "true" ]]; then
  install_hadolint
  install_helm
  install_terraform
  install_vault
  install_kubectl
fi


[[ BATCH_MODE == "false" ]] && cat <<EOF

Finished installing all dependencies.

You should now be able to build the project by running:
	source $HOME/.cargo/env
	cargo build
EOF

exit 0