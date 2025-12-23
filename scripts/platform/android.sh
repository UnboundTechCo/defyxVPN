
#!/bin/bash

build_android() {
    local build_type=$1
    echo -e "${BLUE}🤖 Building Android for $build_type...${NC}"
    update_build_type "$build_type"
    
    flutter clean
    flutter pub get

    flutter build appbundle --release

    update_build_type "github"
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

build_android_ci() {
    echo -e "${BLUE}🤖 Building Android...${NC}"
    update_build_type "github"

    flutter clean
    flutter pub get
    if [ $? -ne 0 ]; then
        echo -e "${RED}❌ Failed to update packages${NC}"
        exit 1
    fi

    if [ "$UPLOAD_TO_PLAY_STORE" = "true" ]; then
        echo -e "${BLUE}Building AAB for Google Play upload${NC}"
        flutter build appbundle --release
        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ AAB build failed${NC}"
            exit 1
        fi
    else
        echo -e "${BLUE}Building APK${NC}"
        flutter build apk --release
        flutter build apk --split-per-abi --release 

        if [ $? -ne 0 ]; then
            echo -e "${RED}❌ APK build failed${NC}"
            exit 1
        fi
    fi
}
