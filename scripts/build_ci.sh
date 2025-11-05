#!/bin/bash

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

GLOBAL_VARS_FILE="${PROJECT_ROOT}/lib/shared/global_vars.dart"
PUBSPEC_FILE="${PROJECT_ROOT}/pubspec.yaml"

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

build_android_github() {
    echo -e "${BLUE}🤖 Building Android for GitHub...${NC}"
    update_build_type "github"

    flutter clean
    flutter pub get
    flutter build apk --release
}

### MAIN (non-interactive)
current_version=$(get_current_version)
new_version=$(increment_version "$current_version" "patch")
update_version "$new_version"

build_android_github

echo -e "${GREEN}✅ CI Android GitHub build completed!${NC}"
