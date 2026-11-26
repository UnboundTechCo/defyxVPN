
#!/bin/bash

build_android() {
    local build_type=$1
    echo -e "${BLUE}🤖 Building Android for $build_type...${NC}"
    
    update_build_type "$build_type"
    
    flutter clean
    flutter pub get

    if [ "$build_type" == "googlePlay" ]; then
        # The TV bundle goes first: both builds write to the same path, and
        # app-release.aab must end up being the phone bundle. Paths start at
        # PROJECT_ROOT because the script may run from another directory.
        local bundle_dir="$PROJECT_ROOT/build/app/outputs/bundle"
        echo -e "${GREEN}Building Android TV appbundle for Google Play...${NC}"
        flutter build appbundle --release -P tvBuild=true || exit 1
        mkdir -p "$bundle_dir/tv"
        mv "$bundle_dir/release/app-release.aab" "$bundle_dir/tv/app-tv-release.aab" || exit 1
        echo -e "${GREEN}✅ TV AAB built: $bundle_dir/tv/app-tv-release.aab${NC}"

        echo -e "${GREEN}Building appbundle for Google Play...${NC}"
        flutter build appbundle --release || exit 1
        echo -e "${GREEN}✅ AAB built successfully${NC}"
    elif [ "$build_type" == "github" ]; then
        echo -e "${GREEN}Building APKs for GitHub...${NC}"
        # Stop on a failed build: going on hid the error, and CI only failed
        # later, at attestation, with "Could not find subject".
        flutter build apk --release || exit 1
        flutter build apk --split-per-abi --release || exit 1
        
        # Get version for file renaming
        local version=$(grep "^version: " "$PUBSPEC_FILE" | cut -d' ' -f2)
        local version_name=$(echo "$version" | cut -d'+' -f1)
        
        # Rename APK files
        local apk_dir="$PROJECT_ROOT/build/app/outputs/flutter-apk"
        
        if [ -f "$apk_dir/app-armeabi-v7a-release.apk" ]; then
            mv "$apk_dir/app-armeabi-v7a-release.apk" "$apk_dir/DefyxVPN-$version_name-armeabi-v7a.apk"
            echo -e "${GREEN}✅ Renamed to DefyxVPN-$version_name-armeabi-v7a.apk${NC}"
        fi
        
        if [ -f "$apk_dir/app-arm64-v8a-release.apk" ]; then
            mv "$apk_dir/app-arm64-v8a-release.apk" "$apk_dir/DefyxVPN-$version_name-arm64-v8a.apk"
            echo -e "${GREEN}✅ Renamed to DefyxVPN-$version_name-arm64-v8a.apk${NC}"
        fi
        
        if [ -f "$apk_dir/app-x86_64-release.apk" ]; then
            mv "$apk_dir/app-x86_64-release.apk" "$apk_dir/DefyxVPN-$version_name-x86_64.apk"
            echo -e "${GREEN}✅ Renamed to DefyxVPN-$version_name-x86_64.apk${NC}"
        fi
        
        if [ -f "$apk_dir/app-release.apk" ]; then
            mv "$apk_dir/app-release.apk" "$apk_dir/DefyxVPN-$version_name-universal.apk"
            echo -e "${GREEN}✅ Renamed to DefyxVPN-$version_name-universal.apk${NC}"
        fi
        
        if ! compgen -G "$apk_dir/DefyxVPN-$version_name-*.apk" >/dev/null; then
            echo -e "${RED}❌ No APKs found in $apk_dir${NC}"
            exit 1
        fi
        echo -e "${GREEN}✅ APKs built and renamed successfully${NC}"
    else
        echo -e "${RED}❌ Invalid Android build type: $build_type${NC}"
        exit 1
    fi
}
