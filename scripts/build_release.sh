#!/bin/bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPT_DIR/colors.sh"
source "$SCRIPT_DIR/paths.sh"
source "$SCRIPT_DIR/version.sh"
source "$SCRIPT_DIR/ios.sh"
source "$SCRIPT_DIR/android.sh"
source "$SCRIPT_DIR/ads.sh"
source "$SCRIPT_DIR/menu.sh"
source "$SCRIPT_DIR/firebase_ios.sh"
source "$SCRIPT_DIR/firebase_android.sh"

echo "Using config file: $GLOBAL_VARS_FILE"

select_environment

select_platform

current_version=$(get_current_version)
select_version_increment "$current_version"

execute_build "$SELECTED_PLATFORM"