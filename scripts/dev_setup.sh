#!/bin/bash
# Copyright (c) The Libra Core Contributors
# SPDX-License-Identifier: Apache-2.0
# This script sets up the environment for the Libra build by installing necessary dependencies.
#
# Usage ./dev_setup.sh <options>
#   v - verbose, print all statements

SCRIPT_PATH="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
cd "$SCRIPT_PATH/.."

function usage {
  echo "Usage:"
  echo "Installs or updates necessary dev tools for libra/libra."
  echo "-b batch mode, no user interactions and miminal output"
  echo "-v verbose mode"
  echo "should be called from the root folder of the libra project"
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
	* lcov

If you'd prefer to install these dependencies yourself, please exit this script
now with Ctrl-C.
EOF
}

BATCH_MODE=false;
VERBOSE=false

#parse args
while getopts "bvh" arg; do
  case $arg in
    b)
      BATCH_MODE="true"
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

if [ ! -f Cargo.toml ]; then
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

if [[ $"$PACKAGE_MANAGER" == "apt-get" ]]; then
	[[ BATCH_MODE == "false" ]] && echo "Updating apt-get......"
	sudo apt-get update
fi

[[ BATCH_MODE == "false" ]] && echo "Installing CMake......"
if which cmake &>/dev/null; then
	[[ BATCH_MODE == "false" ]] && echo "CMake is already installed"
else
	if [[ "$PACKAGE_MANAGER" == "yum" ]]; then
		sudo yum install cmake -y
	elif [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
		sudo apt-get install cmake -y
	elif [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
		sudo pacman -Syu cmake --noconfirm
	elif [[ "$PACKAGE_MANAGER" == "brew" ]]; then
		brew install cmake
	fi
fi

[[ BATCH_MODE == "false" ]] && echo "Installing Clang......"
if which clang &>/dev/null; then
        [[ BATCH_MODE == "false" ]] && echo "Clang is already installed"
else
        if [[ "$PACKAGE_MANAGER" == "yum" ]]; then
                sudo yum install clang -y
        elif [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
                sudo apt-get install clang llvm 
        elif [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
                sudo pacman -Syu clang --noconfirm
        elif [[ "$PACKAGE_MANAGER" == "brew" ]]; then
                brew install llvm
        fi
fi


[[ BATCH_MODE == "false" ]] && echo "Installing curl......"
if which curl &>/dev/null; then
        [[ BATCH_MODE == "false" ]] && echo "Clang is already installed"
else
        if [[ "$PACKAGE_MANAGER" == "yum" ]]; then
                sudo yum install curl -y
        elif [[ "$PACKAGE_MANAGER" == "apt-get" ]]; then
                sudo apt-get install curl
        elif [[ "$PACKAGE_MANAGER" == "pacman" ]]; then
                sudo pacman -Syu curl --noconfirm
        elif [[ "$PACKAGE_MANAGER" == "brew" ]]; then
                brew install curl
        fi
fi

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


[[ BATCH_MODE == "false" ]] && cat <<EOF

Finished installing all dependencies.

You should now be able to build the project by running:
	source $HOME/.cargo/env
	cargo build
EOF
