#!/bin/bash

build_windows() {
    local build_type=$1
    echo -e "${BLUE}🤖 Building Windows for $build_type...${NC}"
    update_build_type "$build_type"
    
    flutter clean
    flutter pub get
    
    if [ "$build_type" == "microsoftStore" ]; then
        flutter build windows --release

    elif [ "$build_type" == "github" ]; then
        flutter build windows --release
    else
        echo -e "${RED}❌ Invalid Windows build type${NC}"
        exit 1
    fi
}