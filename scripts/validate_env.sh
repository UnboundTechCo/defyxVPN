#!/bin/bash

# Validate required environment variables for a given platform
validate_env_vars() {
    local platform="$1"

    # Check if .env file exists
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        echo -e "${RED}❌ .env file not found in project root${NC}"
        exit 1
    fi

    # Common variables (not platform-specific)
    local common_vars=(
        "LINK_APP_STORE"
        "LINK_TEST_FLIGHT"
        "LINK_GITHUB"
        "LINK_GOOGLE_PLAY"
        "FIREBASE_PROJECT_NUMBER"
        "FIREBASE_PROJECT_ID"
    )

    # Platform-specific Firebase and Ad variables
    local platform_vars=()
    case "$platform" in
        android)
            platform_vars=(
                "ANDROID_AD_APP_ID"
                "ANDROID_AD_UNIT_ID"
                "FIREBASE_ANDROID_API_KEY"
                "FIREBASE_ANDROID_APP_ID"
            )
            ;;
        ios)
            platform_vars=(
                "IOS_AD_APP_ID"
                "IOS_AD_UNIT_ID"
                "FIREBASE_IOS_API_KEY"
                "FIREBASE_IOS_APP_ID"
            )
            ;;
        windows)
            platform_vars=(
                "FIREBASE_WINDOWS_API_KEY"
                "FIREBASE_WINDOWS_APP_ID"
                "FIREBASE_WINDOWS_MEASUREMENT_ID"
            )
            ;;
        web)
            platform_vars=(
                "FIREBASE_WEB_API_KEY"
                "FIREBASE_WEB_APP_ID"
                "FIREBASE_WEB_MEASUREMENT_ID"
            )
            ;;
        *)
            platform_vars=(
                "ANDROID_AD_APP_ID"
                "ANDROID_AD_UNIT_ID"
                "IOS_AD_APP_ID"
                "IOS_AD_UNIT_ID"
                "FIREBASE_ANDROID_API_KEY"
                "FIREBASE_ANDROID_APP_ID"
                "FIREBASE_IOS_API_KEY"
                "FIREBASE_IOS_APP_ID"
                "FIREBASE_WINDOWS_API_KEY"
                "FIREBASE_WINDOWS_APP_ID"
                "FIREBASE_WINDOWS_MEASUREMENT_ID"
                "FIREBASE_WEB_API_KEY"
                "FIREBASE_WEB_APP_ID"
                "FIREBASE_WEB_MEASUREMENT_ID"
            )
            ;;
    esac

    local required_vars=("${platform_vars[@]}" "${common_vars[@]}")

    has_errors=false
    for var in "${required_vars[@]}"; do
        if ! grep -q "^${var}=" "${PROJECT_ROOT}/.env"; then
            echo -e "${RED}❌ Environment variable $var is missing in .env file${NC}"
            has_errors=true
        fi
    done

    if [ "$has_errors" = true ]; then
        exit 1
    fi
}