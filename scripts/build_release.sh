#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SETUP_DIR="${SCRIPT_DIR}/setup"
PLATFORM_DIR="${SCRIPT_DIR}/platform"

source "$SETUP_DIR/colors.sh"
source "$SETUP_DIR/paths.sh"
source "$SETUP_DIR/validate_env.sh"
source "$SETUP_DIR/version.sh"
source "$SETUP_DIR/ads.sh"
source "$SETUP_DIR/menu.sh"

source "$PLATFORM_DIR/android.sh"
source "$PLATFORM_DIR/ios.sh"
source "$PLATFORM_DIR/windows.sh"
source "$PLATFORM_DIR/firebase/firebase_ios.sh"
source "$PLATFORM_DIR/firebase/firebase_android.sh"

echo "Using config file: $GLOBAL_VARS_FILE"

validate_env_vars

select_environment

select_platform

current_version=$(get_current_version)
select_version_increment "$current_version"

execute_build "$SELECTED_PLATFORM"