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
}