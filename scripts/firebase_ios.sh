IOS_GOOGLESERVICE_INFO_PLIST="$PROJECT_ROOT/ios/Runner/GoogleService-Info.plist"
BACKUP_IOS_GOOGLESERVICE_INFO_PLIST="$IOS_GOOGLESERVICE_INFO_PLIST.bak"

inject_firebase_ios() {
    cp "$IOS_GOOGLESERVICE_INFO_PLIST" "$BACKUP_IOS_GOOGLESERVICE_INFO_PLIST"
    # Example: Replace placeholders in GoogleService-Info.plist with values from .env
    local ios_api_key=$(grep '^FIREBASE_IOS_API_KEY=' "$ENV_FILE" | cut -d'=' -f2-)
    local ios_app_id=$(grep '^FIREBASE_IOS_APP_ID=' "$ENV_FILE" | cut -d'=' -f2-)
    local ios_sender_id=$(grep '^FIREBASE_PROJECT_NUMBER=' "$ENV_FILE" | cut -d'=' -f2-)
    local project_id=$(grep '^FIREBASE_PROJECT_ID=' "$ENV_FILE" | cut -d'=' -f2-)
    # Set storage_bucket from project_id
    local storage_bucket="${project_id}.firebasestorage.app"
    if [ -n "$ios_api_key" ]; then
        sed -i '' "s|<key>API_KEY</key><string>[^<]*</string>|<key>API_KEY</key><string>$ios_api_key</string>|" "$IOS_GOOGLESERVICE_INFO_PLIST"
    fi
    if [ -n "$ios_app_id" ]; then
        sed -i '' "s|<key>GOOGLE_APP_ID</key><string>[^<]*</string>|<key>GOOGLE_APP_ID</key><string>$ios_app_id</string>|" "$IOS_GOOGLESERVICE_INFO_PLIST"
    fi
    if [ -n "$ios_sender_id" ]; then
        sed -i '' "s|<key>GCM_SENDER_ID</key><string>[^<]*</string>|<key>GCM_SENDER_ID</key><string>$ios_sender_id</string>|" "$IOS_GOOGLESERVICE_INFO_PLIST"
    fi
    if [ -n "$project_id" ]; then
        sed -i '' "s|<key>PROJECT_ID</key><string>[^<]*</string>|<key>PROJECT_ID</key><string>$project_id</string>|" "$IOS_GOOGLESERVICE_INFO_PLIST"
        # Update STORAGE_BUCKET
        sed -i '' "s|<key>STORAGE_BUCKET</key><string>[^<]*</string>|<key>STORAGE_BUCKET</key><string>$storage_bucket</string>|" "$IOS_GOOGLESERVICE_INFO_PLIST"
    fi
    echo -e "${GREEN}[OK] Injected Firebase iOS credentials${NC}"
}

restore_firebase_ios() {
    if [ -f "$BACKUP_IOS_GOOGLESERVICE_INFO_PLIST" ]; then
        mv "$BACKUP_IOS_GOOGLESERVICE_INFO_PLIST" "$IOS_GOOGLESERVICE_INFO_PLIST"
        echo -e "${GREEN}[OK] Restored original GoogleService-Info.plist${NC}"
    fi
}