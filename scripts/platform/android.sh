
#!/bin/bash

build_android() {
    local build_type=$1
    echo -e "${BLUE}🤖 Building Android for $build_type...${NC}"
    update_build_type "$build_type"
    
    flutter clean
    flutter pub get

    flutter build appbundle --release

    # Change to github type for APK builds and clean to prevent version contamination
    update_build_type "github"
    flutter clean
    flutter pub get
    flutter build apk --release
    flutter build apk --split-per-abi --release
    
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
