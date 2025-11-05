#!/bin/bash

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