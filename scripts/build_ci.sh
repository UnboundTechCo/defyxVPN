#!/bin/bash
#By atomic
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

GLOBAL_VARS_FILE="${PROJECT_ROOT}/lib/shared/global_vars.dart"
PUBSPEC_FILE="${PROJECT_ROOT}/pubspec.yaml"

# Validate required environment variables
validate_env_vars() {
    local required_vars=("ANDROID_AD_UNIT_ID" "IOS_AD_UNIT_ID" "APP_STORE_LINK" "TEST_FLIGHT_LINK" "GITHUB_LINK" "GOOGLE_PLAY_LINK" "IS_TEST_MODE")
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            echo -e "${RED}❌ Environment variable $var is not set${NC}"
            exit 1
        fi
    done
    echo -e "${GREEN}✅ All required environment variables are set${NC}"
}

get_current_version() {
    local version=$(grep "^version: " "$PUBSPEC_FILE" | cut -d' ' -f2)
    echo "$version"
}

increment_version() {
    local version=$1
    local increment_type=$2
    local semver=$(echo "$version" | cut -d'+' -f1)
    local build=$(echo "$version" | cut -d'+' -f2)

    local major=$(echo "$semver" | cut -d'.' -f1)
    local minor=$(echo "$semver" | cut -d'.' -f2)
    local patch=$(echo "$semver" | cut -d'.' -f3)

    case $increment_type in
        "major")
            major=$((major + 1)); minor=0; patch=0 ;;
        "minor")
            minor=$((minor + 1)); patch=0 ;;
        "patch")
            patch=$((patch + 1)) ;;
    esac

    local new_build=$((build + 1))
    echo "${major}.${minor}.${patch}+${new_build}"
}

validate_version() {
    local version=$1
    [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+$ ]]
}

update_version() {
    local version=$1
    if ! validate_version "$version"; then
        echo -e "${RED}❌ Invalid version format: $version${NC}"
        exit 1
    fi
    sed -i "s/^version: .*/version: $version/" "$PUBSPEC_FILE"
    echo -e "${GREEN}✅ Version updated to: $version${NC}"
}

update_build_type() {
    local build_type=$1
    sed -i "s/appBuildType = '[^']*'/appBuildType = '${build_type}'/" "$GLOBAL_VARS_FILE"
    echo -e "${GREEN}✅ Build type updated to: $build_type${NC}"
}

build_android() {
    echo -e "${BLUE}🤖 Building Android...${NC}"
    update_build_type "github"

    # Check if .env file exists
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        echo -e "${RED}❌ .env file not found in project root${NC}"
        exit 1
    fi

    flutter clean
    flutter pub get
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to update packages${NC}"
        exit 1
    fi

    if [ "$UPLOAD_TO_PLAY_STORE" = "true" ]; then
        echo -e "${BLUE}Building AAB for Google Play upload${NC}"
        flutter build appbundle --release
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ AAB build failed${NC}"
            exit 1
        fi
    else
        echo -e "${BLUE}Building APK${NC}"
        flutter build apk --release
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ APK build failed${NC}"
            exit 1
        fi
    fi
}

build_ios() {
    echo -e "${BLUE}📱 Building iOS...${NC}"
    update_build_type "github"

    # Check if .env file exists
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        echo -e "${RED}❌ .env file not found in project root${NC}"
        exit 1
    fi

    flutter clean
    flutter pub get
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to update packages${NC}"
        exit 1
    fi

    echo -e "${BLUE}Building IPA for App Store/TestFlight${NC}"
    flutter build ios --release --no-codesign
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ IPA build failed${NC}"
        exit 1
    fi

    # Package IPA using xcodebuild
    cd ios
    xcodebuild -workspace Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration Release archive -archivePath "$PROJECT_ROOT/build/ios/archive/Runner.xcarchive"
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Xcode archive failed${NC}"
        exit 1
    fi
    xcodebuild -exportArchive -archivePath "$PROJECT_ROOT/build/ios/archive/Runner.xcarchive" -exportOptionsPlist "$PROJECT_ROOT/ios/ExportOptions.plist" -exportPath "$PROJECT_ROOT/build/ios/ipa"
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ IPA export failed${NC}"
        exit 1
    fi
}

### MAIN (non-interactive)
validate_env_vars
current_version=$(get_current_version)
new_version=$(increment_version "$current_version" "patch")
update_version "$new_version"
echo "APP_VERSION=$new_version" >> "$GITHUB_ENV"

if [ "$UPLOAD_TO_APP_STORE" = "true" ]; then
    build_ios
else
    build_android
fi

echo -e "${GREEN}✅ CI build completed!${NC}"
