#!/bin/bash

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SETUP_DIR="${SCRIPT_DIR}/setup"
PLATFORM_DIR="${SCRIPT_DIR}/platform"

source "$SETUP_DIR/colors.sh"
source "$SETUP_DIR/paths.sh"
source "$SETUP_DIR/validate_env.sh"
source "$SETUP_DIR/ads.sh"

source "$PLATFORM_DIR/firebase/firebase_ios.sh"
source "$PLATFORM_DIR/firebase/firebase_android.sh"

set -e

echo "Running app"

android_ad_app_id=$(grep '^ANDROID_AD_APP_ID=' "$ENV_FILE" | cut -d'=' -f2-)
ios_ad_app_id=$(grep '^IOS_AD_APP_ID=' "$ENV_FILE" | cut -d'=' -f2-)
orig_ad_id="ca-app-pub-0000000000000000~0000000000"

# Cleanup function that always runs
cleanup() {
    echo -e "\n${YELLOW}🧹 Running cleanup...${NC}"
    restore_firebase_ios
    restore_firebase_android
    update_ad_id "$orig_ad_id" "$orig_ad_id"
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

# Set trap to ensure cleanup runs on exit, interrupt, or termination
trap cleanup EXIT INT TERM

update_ad_id "$android_ad_app_id" "$ios_ad_app_id"
if ! validate_ad_id "$android_ad_app_id" "$ios_ad_app_id"; then
    echo -e "${RED}❌ Ad ID validation failed. Build aborted.${NC}"
    exit 1
fi  


inject_firebase_ios
inject_firebase_android

flutter run "$@"

