#!/bin/bash

# Update ad value in AndroidManifest.xml and Info.plist from DEFYX_AD_ID
update_ad_id() {
    local android_ad_app_id="$1"
    local ios_ad_app_id="$2"
    local android_manifest="$PROJECT_ROOT/android/app/src/main/AndroidManifest.xml"
    local ios_info_plist="$PROJECT_ROOT/ios/Runner/Info.plist"

    # AndroidManifest.xml
    if [ -n "$android_ad_app_id" ]; then
        sed -i '' 's|<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="[^"]*"/>|<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="'"$android_ad_app_id"'"/>|' "$android_manifest"
        echo -e "${GREEN}✅ Updated Android ad id in AndroidManifest.xml${NC}"
    else
        echo -e "${YELLOW}⚠️  ANDROID_AD_UNIT_ID not set. Skipping AndroidManifest.xml update.${NC}"
    fi
    # Info.plist
    if [ -n "$ios_ad_app_id" ]; then
        sed -i '' "s|<key>GADApplicationIdentifier</key>[[:space:]]*<string>[^<]*</string>|<key>GADApplicationIdentifier</key><string>$ios_ad_app_id</string>|" "$ios_info_plist"
        echo -e "${GREEN}✅ Updated iOS ad id in Info.plist${NC}"
    else
        echo -e "${YELLOW}⚠️  IOS_AD_UNIT_ID not set. Skipping Info.plist update.${NC}"
    fi
}

validate_ad_id() {
    local android_ad_app_id="$1"
    local ios_ad_app_id="$2"
    local android_manifest="$PROJECT_ROOT/android/app/src/main/AndroidManifest.xml"
    local ios_info_plist="$PROJECT_ROOT/ios/Runner/Info.plist"
    local valid=true

    # Check AndroidManifest.xml
    if [ -n "$android_ad_app_id" ]; then
        if ! grep -q "$android_ad_app_id" "$android_manifest"; then
            echo -e "${YELLOW}⚠️  Android ad id $android_ad_app_id not found in AndroidManifest.xml!${NC}"
            valid=false
        fi
    fi

    # Check Info.plist
    if [ -n "$ios_ad_app_id" ]; then
        if ! grep -q "$ios_ad_app_id" "$ios_info_plist"; then
            echo -e "${YELLOW}⚠️  iOS ad id $ios_ad_app_id not found in Info.plist!${NC}"
            valid=false
        fi
    fi

    if [ "$valid" = false ]; then
        return 1
    fi
    return 0
}