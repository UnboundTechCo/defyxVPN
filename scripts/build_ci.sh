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
source "$SCRIPT_DIR/validate_env.sh"

### MAIN (non-interactive)
if [ "$UPLOAD_TO_APP_STORE" = "true" ]; then
    validate_env_vars ios
    build_ios_ci
else
    validate_env_vars android
    build_android_ci
fi

echo -e "${GREEN}✅ CI build completed!${NC}"
