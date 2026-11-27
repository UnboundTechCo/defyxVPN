#!/bin/bash

build_ios() {
    local build_type=$1
    echo -e "${BLUE}📱 Building iOS for $build_type...${NC}"

    if [ "$build_type" != "testFlight" ] && [ "$build_type" != "appStore" ]; then
        echo -e "${RED}❌ Invalid iOS build type${NC}"
        return 1
    fi

    update_build_type "$build_type"

    flutter clean
    flutter pub get

    # CI signs manually and points this at the export options it wrote
    # (.github/actions/ios-signing). Without it, Xcode exports with the
    # project's automatic signing, as on a developer's Mac.
    local export_options=()
    if [ -n "${IOS_EXPORT_OPTIONS_PLIST:-}" ]; then
        export_options=(--export-options-plist="$IOS_EXPORT_OPTIONS_PLIST")
    fi

    # Return on a failed build, so the caller still restores the injected
    # credentials and then fails.
    if ! flutter build ipa --release "${export_options[@]}"; then
        echo -e "${RED}❌ iOS build failed${NC}"
        return 1
    fi
    if ! compgen -G "$PROJECT_ROOT/build/ios/ipa/*.ipa" >/dev/null; then
        echo -e "${RED}❌ No IPA in $PROJECT_ROOT/build/ios/ipa${NC}"
        return 1
    fi
    echo -e "${GREEN}✅ IPA built: $(ls "$PROJECT_ROOT"/build/ios/ipa/*.ipa)${NC}"

    # Post-build dSYM upload (safety net in case build phase fails)
    upload_dsyms_post_build
}

upload_dsyms_post_build() {
    echo -e "${BLUE}[POST-BUILD] Checking for dSYMs to upload...${NC}"
    
    # Get absolute paths (don't rely on PROJECT_ROOT variable)
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    local project_root="$(cd "$script_dir/../.." && pwd)"
    local dsym_dir="$project_root/build/ios/archive/Runner.xcarchive/dSYMs"
    local upload_script="$project_root/ios/Pods/FirebaseCrashlytics/upload-symbols"
    local google_service="$project_root/ios/Runner/GoogleService-Info.plist"
    
    echo -e "${BLUE}[POST-BUILD] Paths:${NC}"
    echo -e "${BLUE}  dSYM dir: $dsym_dir${NC}"
    echo -e "${BLUE}  Upload script: $upload_script${NC}"
    echo -e "${BLUE}  Google service: $google_service${NC}"
    
    if [ ! -d "$dsym_dir" ]; then
        echo -e "${YELLOW}⚠️  dSYM directory not found: $dsym_dir${NC}"
        return 0
    fi
    
    if [ ! -f "$upload_script" ]; then
        echo -e "${YELLOW}⚠️  Firebase upload-symbols script not found${NC}"
        return 0
    fi
    
    if [ ! -f "$google_service" ]; then
        echo -e "${RED}❌ GoogleService-Info.plist not found (credentials may not be injected)${NC}"
        return 0
    fi
    
    echo -e "${CYAN}📤 Uploading dSYMs to Firebase Crashlytics...${NC}"
    
    if "$upload_script" -gsp "$google_service" -p ios "$dsym_dir"; then
        echo -e "${GREEN}✅ dSYM upload successful${NC}"
    else
        local exit_code=$?
        echo -e "${YELLOW}⚠️  dSYM upload failed with exit code: $exit_code${NC}"
        echo -e "${YELLOW}   (This may be expected if build phase already uploaded)${NC}"
    fi
}