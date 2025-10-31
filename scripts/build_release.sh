#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' 

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

GLOBAL_VARS_FILE="${PROJECT_ROOT}/lib/shared/global_vars.dart"
PUBSPEC_FILE="${PROJECT_ROOT}/pubspec.yaml"
ENV_FILE="${PROJECT_ROOT}/.env"

get_current_version() {
    local version=$(grep "^version: " "$PUBSPEC_FILE" | cut -d' ' -f2)
    echo "$version"
}

increment_version() {
    local version=$1
    local increment_type=$2
    local semver=$(echo "$version" | cut -d'+' -f1)
    local build=$(echo "$version" | cut -d'+' -f2)
    
    # Split semver into X.Y.Z components
    local major=$(echo "$semver" | cut -d'.' -f1)
    local minor=$(echo "$semver" | cut -d'.' -f2)
    local patch=$(echo "$semver" | cut -d'.' -f3)
    
    case $increment_type in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            patch=$((patch + 1))
            ;;
    esac
    
    # Always increment build number
    local new_build=$((build + 1))
    
    echo "${major}.${minor}.${patch}+${new_build}"
}

increment_build_number() {
    increment_version "$1" "patch"
}

validate_version() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]; then
        echo -e "${RED}[ERROR] Invalid version format. Please use format: X.Y.Z+B (e.g., 2.6.8+61)${NC}"
        return 1
    fi
    return 0
}

update_version() {
    local version=$1
    if ! validate_version "$version"; then
        return 1
    fi
    
    sed -i '' "s/^version: .*/version: $version/" "$PUBSPEC_FILE"
    echo -e "${GREEN}[OK] Version updated to: $version${NC}"
}

echo "Using config file: $GLOBAL_VARS_FILE"

update_build_type() {
    local build_type=$1
    sed -i '' "s/appBuildType = '[^']*'/appBuildType = '${build_type}'/" "$GLOBAL_VARS_FILE"
    echo -e "${GREEN}[OK] Build type updated to: $build_type${NC}"
}

update_test_mode() {
    local is_test=$1
    sed -i '' "s/IS_TEST_MODE=.*/IS_TEST_MODE=${is_test}/" "$ENV_FILE"
    echo -e "${GREEN}[OK] Test mode updated to: $is_test${NC}"
}

build_ios() {
    local build_type=$1
    echo -e "${BLUE}[iOS] Building iOS for $build_type...${NC}"
    update_build_type "$build_type"
    
    flutter clean
    flutter pub get
    
    if [ "$build_type" == "testFlight" ]; then
        flutter build ipa --release
    elif [ "$build_type" == "appStore" ]; then
        flutter build ipa --release
    else
        echo -e "${RED}[ERROR] Invalid iOS build type${NC}"
        exit 1
    fi
}

build_android() {
    local build_type=$1
    echo -e "${BLUE}[Android] Building Android for $build_type...${NC}"
    update_build_type "$build_type"
    
    flutter clean
    flutter pub get
    
    if [ "$build_type" == "googlePlay" ]; then
        flutter build appbundle --release
    elif [ "$build_type" == "github" ]; then
        flutter build apk --release
    else
        echo -e "${RED}[ERROR] Invalid Android build type${NC}"
        exit 1
    fi
}

select_version_increment() {
    local current_version=$1
    local suggested_versions=""
    
    echo -e "${BLUE}Current version: $current_version${NC}"
    echo -e "${BLUE}Select version number to increment:${NC}"
    echo "1) Major (X.0.0) - For incompatible API changes"
    echo "2) Minor (x.Y.0) - For backwards-compatible functionality"
    echo "3) Patch (x.y.Z) - For backwards-compatible bug fixes"
    echo "4) Same Version - Keep the current version"
    
    read -p "Enter your choice (1-4): " increment_choice
    
    case $increment_choice in
        1)
            suggested_version=$(increment_version "$current_version" "major")
            ;;
        2)
            suggested_version=$(increment_version "$current_version" "minor")
            ;;
        3)
            suggested_version=$(increment_version "$current_version" "patch")
            ;;
        4)
            suggested_version=$current_version
            ;;
        *)
            echo -e "${RED}[ERROR] Invalid choice${NC}"
            return 1
            ;;
    esac
    
    echo -e "${BLUE}Suggested version: $suggested_version${NC}"
    
    while true; do
        read -p "Enter the app version (press Enter for suggested version, or type new version): " version
        
        # If user just pressed Enter, use suggested version
        if [ -z "$version" ]; then
            version=$suggested_version
        fi
        
        if update_version "$version"; then
            break
        fi
    done
    
    return 0
}

# Update ad value in AndroidManifest.xml and Info.plist from DEFYX_AD_ID
update_ad_id() {
    local android_ad_app_id="$1"
    local ios_ad_app_id="$2"
    local android_manifest="$PROJECT_ROOT/android/app/src/main/AndroidManifest.xml"
    local ios_info_plist="$PROJECT_ROOT/ios/Runner/Info.plist"

    # AndroidManifest.xml
    if [ -n "$android_ad_app_id" ]; then
        # Using perl to avoid shell interpretation issues with XML angle brackets
        perl -i -pe "s|<meta-data android:name=\"com.google.android.gms.ads.APPLICATION_ID\" android:value=\"[^\"]*\"/>|<meta-data android:name=\"com.google.android.gms.ads.APPLICATION_ID\" android:value=\"$android_ad_app_id\"/>|" "$android_manifest"
        echo -e "${GREEN}[OK] Updated Android ad id in AndroidManifest.xml${NC}"
    else
        echo -e "${YELLOW}[WARN]  ANDROID_AD_UNIT_ID not set. Skipping AndroidManifest.xml update.${NC}"
    fi
    # Info.plist
    if [ -n "$ios_ad_app_id" ]; then
        # Using perl to avoid shell interpretation issues with XML angle brackets  
        perl -i -pe "s|<key>GADApplicationIdentifier</key>\\s*<string>[^<]*</string>|<key>GADApplicationIdentifier</key><string>$ios_ad_app_id</string>|" "$ios_info_plist"
        echo -e "${GREEN}[OK] Updated iOS ad id in Info.plist${NC}"
    else
        echo -e "${YELLOW}[WARN]  IOS_AD_UNIT_ID not set. Skipping Info.plist update.${NC}"
    fi
}

validate_ad_id() {
    local android_ad_app_id="$1"
    local ios_ad_app_id="$2"
    local android_manifest="$PROJECT_ROOT/android/app/src/main/AndroidManifest.xml"
    local ios_info_plist="$PROJECT_ROOT/ios/Runner/Info.plist"
    local valid=true

    # Check AndroidManifest.xml
    if [ -n "$android_ad_app_id" ]; then
        if ! grep -q "$android_ad_app_id" "$android_manifest"; then
            echo -e "${YELLOW}[WARN]  Android ad id $android_ad_app_id not found in AndroidManifest.xml!${NC}"
            valid=false
        fi
    fi

    # Check Info.plist
    if [ -n "$ios_ad_app_id" ]; then
        if ! grep -q "$ios_ad_app_id" "$ios_info_plist"; then
            echo -e "${YELLOW}[WARN]  iOS ad id $ios_ad_app_id not found in Info.plist!${NC}"
            valid=false
        fi
    fi

    if [ "$valid" = false ]; then
        return 1
    fi
    return 0
}

# === Firebase Credentials Injection ===
ANDROID_GOOGLE_SERVICES_JSON="$PROJECT_ROOT/android/app/google-services.json"
IOS_GOOGLESERVICE_INFO_PLIST="$PROJECT_ROOT/ios/Runner/GoogleService-Info.plist"
BACKUP_ANDROID_GOOGLE_SERVICES_JSON="$ANDROID_GOOGLE_SERVICES_JSON.bak"
BACKUP_IOS_GOOGLESERVICE_INFO_PLIST="$IOS_GOOGLESERVICE_INFO_PLIST.bak"

inject_firebase_android() {
    cp "$ANDROID_GOOGLE_SERVICES_JSON" "$BACKUP_ANDROID_GOOGLE_SERVICES_JSON"
    # Example: Replace placeholders in google-services.json with values from .env
    # Add your keys to .env as FIREBASE_ANDROID_API_KEY, etc.
    local api_key=$(grep '^FIREBASE_ANDROID_API_KEY=' "$ENV_FILE" | cut -d'=' -f2-)
    local app_id=$(grep '^FIREBASE_ANDROID_APP_ID=' "$ENV_FILE" | cut -d'=' -f2-)
    local project_number=$(grep '^FIREBASE_PROJECT_NUMBER=' "$ENV_FILE" | cut -d'=' -f2-)
    local project_id=$(grep '^FIREBASE_PROJECT_ID=' "$ENV_FILE" | cut -d'=' -f2-)
    # Set storage_bucket from project_id
    local storage_bucket="${project_id}.firebasestorage.app"
    if [ -n "$app_id" ]; then
        sed -i '' "s/\"mobilesdk_app_id\": \"[^\"]*\"/\"mobilesdk_app_id\": \"$app_id\"/" "$ANDROID_GOOGLE_SERVICES_JSON"
    fi
    if [ -n "$project_id" ]; then
        sed -i '' "s/\"project_id\": \"[^\"]*\"/\"project_id\": \"$project_id\"/" "$ANDROID_GOOGLE_SERVICES_JSON"
        # Update storage_bucket
        sed -i '' "s/\"storage_bucket\": \"[^\"]*\"/\"storage_bucket\": \"$storage_bucket\"/" "$ANDROID_GOOGLE_SERVICES_JSON"
    fi
    if [ -n "$project_number" ]; then
        sed -i '' "s/\"project_number\": \"[^\"]*\"/\"project_number\": \"$project_number\"/" "$ANDROID_GOOGLE_SERVICES_JSON"
    fi
    if [ -n "$api_key" ]; then
        sed -i '' "s/\"current_key\": \"[^\"]*\"/\"current_key\": \"$api_key\"/" "$ANDROID_GOOGLE_SERVICES_JSON"
    fi
    echo -e "${GREEN}[OK] Injected Firebase Android credentials${NC}"
}

restore_firebase_android() {
    if [ -f "$BACKUP_ANDROID_GOOGLE_SERVICES_JSON" ]; then
        mv "$BACKUP_ANDROID_GOOGLE_SERVICES_JSON" "$ANDROID_GOOGLE_SERVICES_JSON"
        echo -e "${GREEN}[OK] Restored original google-services.json${NC}"
    fi
}

inject_firebase_ios() {
    cp "$IOS_GOOGLESERVICE_INFO_PLIST" "$BACKUP_IOS_GOOGLESERVICE_INFO_PLIST"
    # Example: Replace placeholders in GoogleService-Info.plist with values from .env
    local ios_api_key=$(grep '^FIREBASE_IOS_API_KEY=' "$ENV_FILE" | cut -d'=' -f2-)
    local ios_app_id=$(grep '^FIREBASE_IOS_APP_ID=' "$ENV_FILE" | cut -d'=' -f2-)
    local ios_sender_id=$(grep '^FIREBASE_PROJECT_NUMBER=' "$ENV_FILE" | cut -d'=' -f2-)
    local project_id=$(grep '^FIREBASE_PROJECT_ID=' "$ENV_FILE" | cut -d'=' -f2-)
    # Set storage_bucket from project_id
    local storage_bucket="${project_id}.firebasestorage.app"
    if [ -n "$ios_api_key" ]; then
        sed -i '' "s|<key>API_KEY</key><string>[^<]*</string>|<key>API_KEY</key><string>$ios_api_key</string>|" "$IOS_GOOGLESERVICE_INFO_PLIST"
    fi
    if [ -n "$ios_app_id" ]; then
        sed -i '' "s|<key>GOOGLE_APP_ID</key><string>[^<]*</string>|<key>GOOGLE_APP_ID</key><string>$ios_app_id</string>|" "$IOS_GOOGLESERVICE_INFO_PLIST"
    fi
    if [ -n "$ios_sender_id" ]; then
        sed -i '' "s|<key>GCM_SENDER_ID</key><string>[^<]*</string>|<key>GCM_SENDER_ID</key><string>$ios_sender_id</string>|" "$IOS_GOOGLESERVICE_INFO_PLIST"
    fi
    if [ -n "$project_id" ]; then
        sed -i '' "s|<key>PROJECT_ID</key><string>[^<]*</string>|<key>PROJECT_ID</key><string>$project_id</string>|" "$IOS_GOOGLESERVICE_INFO_PLIST"
        # Update STORAGE_BUCKET
        sed -i '' "s|<key>STORAGE_BUCKET</key><string>[^<]*</string>|<key>STORAGE_BUCKET</key><string>$storage_bucket</string>|" "$IOS_GOOGLESERVICE_INFO_PLIST"
    fi
    echo -e "${GREEN}[OK] Injected Firebase iOS credentials${NC}"
}

restore_firebase_ios() {
    if [ -f "$BACKUP_IOS_GOOGLESERVICE_INFO_PLIST" ]; then
        mv "$BACKUP_IOS_GOOGLESERVICE_INFO_PLIST" "$IOS_GOOGLESERVICE_INFO_PLIST"
        echo -e "${GREEN}[OK] Restored original GoogleService-Info.plist${NC}"
    fi
}

# First question: Test or Production?
echo -e "${BLUE}What kind of build do you want?${NC}"
echo "1) Test"
echo "2) Production"

read -p "Enter your choice (1-2): " build_env_choice

case $build_env_choice in
    1)
        BUILD_ENV="test"
        IS_TEST_MODE="true"
        echo -e "${GREEN}[OK] Test build selected${NC}"
        ;;
    2)
        BUILD_ENV="production"
        IS_TEST_MODE="false"
        echo -e "${GREEN}[OK] Production build selected${NC}"
        ;;
    *)
        echo -e "${RED}[ERROR] Invalid choice${NC}"
        exit 1
        ;;
esac

# Update test mode in global_vars.dart
update_test_mode "$IS_TEST_MODE"

echo -e "${BLUE}Select platform to build:${NC}"
echo "1) iOS - TestFlight"
echo "2) iOS - App Store"
echo "3) Android - Google Play"
echo "4) Android - GitHub"
echo "5) Exit"

read -p "Enter your choice (1-5): " choice

# Get current version and handle version increment
current_version=$(get_current_version)

if ! select_version_increment "$current_version"; then
    exit 1
fi

env_file="$PROJECT_ROOT/.env"
android_ad_app_id=$(grep '^ANDROID_AD_APP_ID=' "$env_file" | cut -d'=' -f2-)
ios_ad_app_id=$(grep '^IOS_AD_APP_ID=' "$env_file" | cut -d'=' -f2-)
orig_ad_id="ca-app-pub-0000000000000000~0000000000"

# Inject Firebase credentials before build
inject_firebase_android
inject_firebase_ios

# Update ad ids and store original values
update_ad_id "$android_ad_app_id" "$ios_ad_app_id"
if ! validate_ad_id "$android_ad_app_id" "$ios_ad_app_id"; then
    echo -e "${RED}[ERROR] Ad ID validation failed. Build aborted.${NC}"
    # Restore original ad ids before exit if needed
    update_ad_id "$orig_ad_id" "$orig_ad_id"
    restore_firebase_android
    restore_firebase_ios
    exit 1
fi

case $choice in
    1)
        build_ios "testFlight"
        ;;
    2)
        build_ios "appStore"
        ;;
    3)
        build_android "googlePlay"
        ;;
    4)
        build_android "github"
        ;;
    5)
        echo -e "${BLUE}[Bye] Goodbye!${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}[ERROR] Invalid choice${NC}"
        # Restore original ad ids after build
        update_ad_id "$orig_ad_id" "$orig_ad_id"
        restore_firebase_android
        restore_firebase_ios
        exit 1
        ;;
esac

# Restore original ad ids after build
update_ad_id "$orig_ad_id" "$orig_ad_id"
restore_firebase_android
restore_firebase_ios
echo -e "${GREEN}[OK] Build process completed!${NC}"
