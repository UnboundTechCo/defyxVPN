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
        echo -e "${RED}❌ Invalid version format. Please use format: X.Y.Z+B (e.g., 2.6.8+61)${NC}"
        return 1
    fi
    return 0
}

update_version() {
    local version=$1
    if ! validate_version "$version"; then
        return 1
    fi
    
    sed -i "" "s/^version: .*/version: $version/" "$PUBSPEC_FILE"
    echo -e "${GREEN}✅ Version updated to: $version${NC}"
}

echo "Using config file: $GLOBAL_VARS_FILE"

update_build_type() {
    local build_type=$1
    sed -i "" "s/appBuildType = '[^']*'/appBuildType = '${build_type}'/" "$GLOBAL_VARS_FILE"
    echo -e "${GREEN}✅ Build type updated to: $build_type${NC}"
}

update_test_mode() {
    local is_test=$1
    sed -i "" "s/IS_TEST_MODE=.*/IS_TEST_MODE=${is_test}/" "$ENV_FILE"
    echo -e "${GREEN}✅ Test mode updated to: $is_test${NC}"
}

build_ios() {
    local build_type=$1
    echo -e "${BLUE}📱 Building iOS for $build_type...${NC}"
    update_build_type "$build_type"
    
    flutter clean
    flutter pub get
    
    if [ "$build_type" == "testFlight" ]; then
        flutter build ipa --release
    elif [ "$build_type" == "appStore" ]; then
        flutter build ipa --release
    else
        echo -e "${RED}❌ Invalid iOS build type${NC}"
        exit 1
    fi
}

build_android() {
    local build_type=$1
    echo -e "${BLUE}🤖 Building Android for $build_type...${NC}"
    update_build_type "$build_type"
    
    flutter clean
    flutter pub get
    
    if [ "$build_type" == "googlePlay" ]; then
        flutter build appbundle --release
    elif [ "$build_type" == "github" ]; then
        flutter build apk --release
    else
        echo -e "${RED}❌ Invalid Android build type${NC}"
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
            echo -e "${RED}❌ Invalid choice${NC}"
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
        sed -i '' 's|<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="[^"]*"/>|<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="'"$android_ad_app_id"'"/>|' "$android_manifest"
        echo -e "${GREEN}✅ Updated Android ad id in AndroidManifest.xml${NC}"
    else
        echo -e "${YELLOW}⚠️  ANDROID_AD_UNIT_ID not set. Skipping AndroidManifest.xml update.${NC}"
    fi
    # Info.plist
    if [ -n "$ios_ad_app_id" ]; then
        sed -i '' "s|<key>GADApplicationIdentifier</key>[[:space:]]*<string>[^<]*</string>|<key>GADApplicationIdentifier</key><string>$ios_ad_app_id</string>|" "$ios_info_plist"
        echo -e "${GREEN}✅ Updated iOS ad id in Info.plist${NC}"
    else
        echo -e "${YELLOW}⚠️  IOS_AD_UNIT_ID not set. Skipping Info.plist update.${NC}"
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
            echo -e "${YELLOW}⚠️  Android ad id $android_ad_app_id not found in AndroidManifest.xml!${NC}"
            valid=false
        fi
    fi

    # Check Info.plist
    if [ -n "$ios_ad_app_id" ]; then
        if ! grep -q "$ios_ad_app_id" "$ios_info_plist"; then
            echo -e "${YELLOW}⚠️  iOS ad id $ios_ad_app_id not found in Info.plist!${NC}"
            valid=false
        fi
    fi

    if [ "$valid" = false ]; then
        return 1
    fi
    return 0
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
        echo -e "${GREEN}✅ Test build selected${NC}"
        ;;
    2)
        BUILD_ENV="production"
        IS_TEST_MODE="false"
        echo -e "${GREEN}✅ Production build selected${NC}"
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
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

# Update ad ids and store original values
update_ad_id "$android_ad_app_id" "$ios_ad_app_id"
if ! validate_ad_id "$android_ad_app_id" "$ios_ad_app_id"; then
    echo -e "${RED}❌ Ad ID validation failed. Build aborted.${NC}"
    # Restore original ad ids before exit if needed
    update_ad_id "$orig_ad_id" "$orig_ad_id"
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
        echo -e "${BLUE}👋 Goodbye!${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Invalid choice${NC}"
        # Restore original ad ids after build
        update_ad_id "$orig_ad_id" "$orig_ad_id"
        exit 1
        ;;
esac

# Restore original ad ids after build
update_ad_id "$orig_ad_id" "$orig_ad_id"
echo -e "${GREEN}✅ Build process completed!${NC}"