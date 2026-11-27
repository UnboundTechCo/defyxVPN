#!/bin/bash

update_build_type() {
    local build_type=$1
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/appBuildType = '[^']*'/appBuildType = '${build_type}'/" "$GLOBAL_VARS_FILE"
    else
        sed -i "s/appBuildType = '[^']*'/appBuildType = '${build_type}'/" "$GLOBAL_VARS_FILE"
    fi
    echo -e "${GREEN}✅ Build type updated to: $build_type${NC}"
}

update_test_mode() {
    local is_test=$1
    if [[ "$(uname)" == "Darwin" ]]; then
        sed -i '' "s/IS_TEST_MODE=.*/IS_TEST_MODE=${is_test}/" "$ENV_FILE"
    else
        sed -i "s/IS_TEST_MODE=.*/IS_TEST_MODE=${is_test}/" "$ENV_FILE"
    fi
    echo -e "${GREEN}✅ Test mode updated to: $is_test${NC}"
}

select_environment() {
    echo -e "${BLUE}What kind of build do you want?${NC}"
    echo "1) Test"
    echo "2) Production"

    read -p "Enter your choice (1-2): " choice

    case $choice in
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

    update_test_mode "$IS_TEST_MODE"
}

select_platform() {
  echo -e "${BLUE}Select platform to build:${NC}"
  echo "1) iOS - TestFlight"
  echo "2) iOS - App Store"
  echo "3) Android - Google Play"
  echo "4) Android - GitHub"
  echo "5) Windows - Microsoft Store"
  echo "6) Windows - GitHub"
  echo "7) macOS - TestFlight"
  echo "8) macOS - App Store"
  echo "9) Exit"

  echo -n "Enter your choice (1-9): "
  read choice
  SELECTED_PLATFORM=$choice
}
execute_build() {
    local choice=$1

    # Leave before any credentials are written, since exiting skips the restore below.
    if [ "$choice" == "9" ]; then
        echo -e "${BLUE}👋 Goodbye!${NC}"
        exit 0
    fi

    env_file="$PROJECT_ROOT/.env"
    android_ad_app_id=$(grep '^ANDROID_AD_APP_ID=' "$env_file" | cut -d'=' -f2-)
    ios_ad_app_id=$(grep '^IOS_AD_APP_ID=' "$env_file" | cut -d'=' -f2-)
    orig_ad_id="ca-app-pub-0000000000000000~0000000000"

    update_ad_id "$android_ad_app_id" "$ios_ad_app_id"
    if ! validate_ad_id "$android_ad_app_id" "$ios_ad_app_id"; then
        echo -e "${RED}❌ Ad ID validation failed. Build aborted.${NC}"
        update_ad_id "$orig_ad_id" "$orig_ad_id"
        exit 1
    fi

    # Inject Firebase credentials before build
    inject_firebase_android
    inject_firebase_ios
    inject_firebase_macos

    # A build that fails returns non-zero; restore first, then fail.
    local status=0
    case $choice in
        1) build_ios "testFlight" || status=$? ;;
        2) build_ios "appStore" || status=$? ;;
        3) build_android "googlePlay" || status=$? ;;
        4) build_android "github" || status=$? ;;
        5) build_windows "microsoftStore" || status=$? ;;
        6) build_windows "github" || status=$? ;;
        7) build_macos "testFlight" || status=$? ;;
        8) build_macos "appStore" || status=$? ;;
        *)
            echo -e "${RED}❌ Invalid choice${NC}"
            status=1
            ;;
    esac

    # Restore IDs
    update_ad_id "$orig_ad_id" "$orig_ad_id"
    restore_firebase_android
    restore_firebase_ios
    restore_firebase_macos

    if [ "$status" -ne 0 ]; then
        echo -e "${RED}❌ Build failed${NC}"
        exit "$status"
    fi
    echo -e "${GREEN}✅ Build process completed!${NC}"
}
