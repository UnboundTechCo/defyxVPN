# === Firebase Credentials Injection ===
ANDROID_GOOGLE_SERVICES_JSON="$PROJECT_ROOT/android/app/google-services.json"
BACKUP_ANDROID_GOOGLE_SERVICES_JSON="$ANDROID_GOOGLE_SERVICES_JSON.bak"

inject_firebase_android() {
    cp "$ANDROID_GOOGLE_SERVICES_JSON" "$BACKUP_ANDROID_GOOGLE_SERVICES_JSON"
    # Example: Replace placeholders in google-services.json with values from .env
    # Add your keys to .env as FIREBASE_ANDROID_API_KEY, etc.
    local api_key=$(grep '^FIREBASE_ANDROID_API_KEY=' "$ENV_FILE" | cut -d'=' -f2-)
    local app_id=$(grep '^FIREBASE_ANDROID_APP_ID=' "$ENV_FILE" | cut -d'=' -f2-)
    local project_number=$(grep '^FIREBASE_PROJECT_NUMBER=' "$ENV_FILE" | cut -d'=' -f2-)
    local project_id=$(grep '^FIREBASE_PROJECT_ID=' "$ENV_FILE" | cut -d'=' -f2-)
    # Set storage_bucket from project_id
    local storage_bucket="${project_id}.firebasestorage.app"
    if [ -n "$app_id" ]; then
        sed -i '' "s/\"mobilesdk_app_id\": \"[^\"]*\"/\"mobilesdk_app_id\": \"$app_id\"/" "$ANDROID_GOOGLE_SERVICES_JSON"
    fi
    if [ -n "$project_id" ]; then
        sed -i '' "s/\"project_id\": \"[^\"]*\"/\"project_id\": \"$project_id\"/" "$ANDROID_GOOGLE_SERVICES_JSON"
        # Update storage_bucket
        sed -i '' "s/\"storage_bucket\": \"[^\"]*\"/\"storage_bucket\": \"$storage_bucket\"/" "$ANDROID_GOOGLE_SERVICES_JSON"
    fi
    if [ -n "$project_number" ]; then
        sed -i '' "s/\"project_number\": \"[^\"]*\"/\"project_number\": \"$project_number\"/" "$ANDROID_GOOGLE_SERVICES_JSON"
    fi
    if [ -n "$api_key" ]; then
        sed -i '' "s/\"current_key\": \"[^\"]*\"/\"current_key\": \"$api_key\"/" "$ANDROID_GOOGLE_SERVICES_JSON"
    fi
    echo -e "${GREEN}[OK] Injected Firebase Android credentials${NC}"
}

restore_firebase_android() {
    if [ -f "$BACKUP_ANDROID_GOOGLE_SERVICES_JSON" ]; then
        mv "$BACKUP_ANDROID_GOOGLE_SERVICES_JSON" "$ANDROID_GOOGLE_SERVICES_JSON"
        echo -e "${GREEN}[OK] Restored original google-services.json${NC}"
    fi
}