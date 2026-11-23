
#!/bin/bash

build_android() {
    local build_type=$1
    echo -e "${BLUE}🤖 Building Android for $build_type...${NC}"
    
    update_build_type "$build_type"
    
    flutter clean
    flutter pub get

    if [ "$build_type" == "googlePlay" ]; then
        # The TV bundle goes first: both builds write to the same path, and
        # app-release.aab must end up being the phone bundle.
        echo -e "${GREEN}Building Android TV appbundle for Google Play...${NC}"
        flutter build appbundle --release -P tvBuild=true || exit 1
        mkdir -p build/app/outputs/bundle/tv
        mv build/app/outputs/bundle/release/app-release.aab build/app/outputs/bundle/tv/app-tv-release.aab
        echo -e "${GREEN}✅ TV AAB built: build/app/outputs/bundle/tv/app-tv-release.aab${NC}"

        echo -e "${GREEN}Building appbundle for Google Play...${NC}"
        flutter build appbundle --release || exit 1
        echo -e "${GREEN}✅ AAB built successfully${NC}"
    elif [ "$build_type" == "github" ]; then
        echo -e "${GREEN}Building APKs for GitHub...${NC}"
        flutter build apk --release
        flutter build apk --split-per-abi --release
        
        # Get version for file renaming
        local version=$(grep "^version: " "$PUBSPEC_FILE" | cut -d' ' -f2)
        local version_name=$(echo "$version" | cut -d'+' -f1)
        
        # Rename APK files
        local apk_dir="build/app/outputs/flutter-apk"
        
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
        
        echo -e "${GREEN}✅ APKs built and renamed successfully${NC}"
    else
        echo -e "${RED}❌ Invalid Android build type: $build_type${NC}"
        exit 1
    fi
}
