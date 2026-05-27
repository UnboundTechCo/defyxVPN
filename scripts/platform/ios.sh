#!/bin/bash

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