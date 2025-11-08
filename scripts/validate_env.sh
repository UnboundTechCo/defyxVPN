#!/bin/bash

# Validate required environment variables
validate_env_vars() {

    # Check if .env file exists
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        echo -e "${RED}❌ .env file not found in project root${NC}"
        exit 1
    fi

    local required_vars=(
        "ANDROID_AD_APP_ID"
        "ANDROID_AD_UNIT_ID"
        "IOS_AD_APP_ID"
        "IOS_AD_UNIT_ID"
        "FIREBASE_PROJECT_NUMBER"
        "FIREBASE_PROJECT_ID"
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
        "LINK_APP_STORE"
        "LINK_TEST_FLIGHT"
        "LINK_GITHUB"
        "LINK_GOOGLE_PLAY"
    )
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