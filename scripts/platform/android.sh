
#!/bin/bash

build_android() {
    local build_type=$1
    echo -e "${BLUE}🤖 Building Android for $build_type...${NC}"
    
    # Get version from pubspec.yaml
    local version=$(grep "^version: " "$PUBSPEC_FILE" | cut -d' ' -f2)
    local version_name=$(echo "$version" | cut -d'+' -f1)
    local version_code=$(echo "$version" | cut -d'+' -f2)
    
    echo -e "${GREEN}Building with version: $version_name+$version_code${NC}"
    
    update_build_type "$build_type"
    
    flutter clean
    flutter pub get

    flutter build appbundle --release --build-name="$version_name" --build-number="$version_code"

    # Change to github type for APK builds and clean to prevent version contamination
    update_build_type "github"
    flutter clean
    flutter pub get
    flutter build apk --release --build-name="$version_name" --build-number="$version_code"
    flutter build apk --split-per-abi --release --build-name="$version_name" --build-number="$version_code"
    
    # Rename APK files
    local apk_dir="build/app/outputs/flutter-apk"
    
    # Rename split APKs
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
    
    # Rename universal APK
    if [ -f "$apk_dir/app-release.apk" ]; then
        mv "$apk_dir/app-release.apk" "$apk_dir/DefyxVPN-$version_name-universal.apk"
        echo -e "${GREEN}✅ Renamed to DefyxVPN-$version_name-universal.apk${NC}"
    fi
    
    # if [ "$build_type" == "googlePlay" ]; then
    #    flutter build appbundle --release
    # elif [ "$build_type" == "github" ]; then
    #    flutter build apk --release
    #    flutter build apk --split-per-abi --release
    #    flutter build appbundle --release
    # else
    #    echo -e "${RED}❌ Invalid Android build type${NC}"
    #    exit 1
    # fi
}
