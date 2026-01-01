#!/bin/bash

build_ios() {
    local build_type=$1
    echo -e "${BLUE}📱 Building iOS for $build_type...${NC}"
    update_build_type "$build_type"

    flutter clean
    flutter pub get

    if [ "$build_type" == "testFlight" ]; then
        flutter build ipa \
          --release \
          --export-options-plist=ios/exportOptions.plist
    elif [ "$build_type" == "appStore" ]; then
        flutter build ipa \
          --release \
          --export-options-plist=ios/exportOptions.plist
    else
        echo -e "${RED}❌ Invalid iOS build type${NC}"
        exit 1
    fi
}

build_ios_ci() {
    echo -e "${BLUE}📱 Building iOS...${NC}"
    update_build_type "github"

    # Check if .env file exists
    if [ ! -f "${PROJECT_ROOT}/.env" ]; then
        echo -e "${RED}❌ .env file not found in project root${NC}"
        exit 1
    fi

    flutter clean
    flutter pub get
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to update packages${NC}"
        exit 1
    fi

    echo -e "${BLUE}Building IPA for App Store/TestFlight${NC}"
    flutter build ios --release --no-codesign
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ IPA build failed${NC}"
        exit 1
    fi

    # Package IPA using xcodebuild
    cd ios
    xcodebuild -workspace Runner.xcworkspace -scheme Runner -sdk iphoneos -configuration Release archive -archivePath "$PROJECT_ROOT/build/ios/archive/Runner.xcarchive"
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Xcode archive failed${NC}"
        exit 1
    fi
    xcodebuild -exportArchive -archivePath "$PROJECT_ROOT/build/ios/archive/Runner.xcarchive" -exportOptionsPlist "$PROJECT_ROOT/ios/ExportOptions.plist" -exportPath "$PROJECT_ROOT/build/ios/ipa"
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ IPA export failed${NC}"
        exit 1
    fi
}