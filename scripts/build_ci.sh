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
current_version=$(get_current_version)
echo "APP_VERSION=$current_version" >> "$GITHUB_ENV"

android_ad_app_id=$(grep '^ANDROID_AD_APP_ID=' "$ENV_FILE" | cut -d'=' -f2-)
ios_ad_app_id=$(grep '^IOS_AD_APP_ID=' "$ENV_FILE" | cut -d'=' -f2-)
orig_ad_id="ca-app-pub-0000000000000000~0000000000"

update_ad_id "$android_ad_app_id" "$ios_ad_app_id"
if ! validate_ad_id "$android_ad_app_id" "$ios_ad_app_id"; then
    echo -e "${RED}❌ Ad ID validation failed. Build aborted.${NC}"
    update_ad_id "$orig_ad_id" "$orig_ad_id"
    exit 1
fi  

if [ "$UPLOAD_TO_APP_STORE" = "true" ]; then
    validate_env_vars ios
    inject_firebase_ios
    build_ios_ci
    restore_firebase_ios
else
    validate_env_vars android
    inject_firebase_android
    build_android_ci
    restore_firebase_android
fi

# Restore IDs
update_ad_id "$orig_ad_id" "$orig_ad_id"
echo -e "${GREEN}✅ CI build completed!${NC}"
