#!/bin/bash

# The macOS app has the iOS app's bundle ID, and Firebase allows one Apple app
# per bundle ID, so macOS is configured with the iOS Firebase credentials.
MACOS_GOOGLESERVICE_INFO_PLIST="$PROJECT_ROOT/macos/Runner/GoogleService-Info.plist"
BACKUP_MACOS_GOOGLESERVICE_INFO_PLIST="$MACOS_GOOGLESERVICE_INFO_PLIST.bak"

# A value from .env, without quotes or a trailing \r.
_macos_firebase_env() {
    grep "^$1=" "$ENV_FILE" | cut -d'=' -f2- | tr -d "\"'\r"
}

_set_macos_firebase_value() {
    local key=$1
    local value=$2
    if [ -n "$value" ]; then
        plutil -replace "$key" -string "$value" "$MACOS_GOOGLESERVICE_INFO_PLIST"
    fi
}

inject_firebase_macos() {
    # macOS apps are only built on a Mac, and plutil only exists there.
    if ! command -v plutil >/dev/null 2>&1; then
        return 0
    fi

    cp "$MACOS_GOOGLESERVICE_INFO_PLIST" "$BACKUP_MACOS_GOOGLESERVICE_INFO_PLIST"

    local project_id
    project_id=$(_macos_firebase_env FIREBASE_PROJECT_ID)

    _set_macos_firebase_value API_KEY "$(_macos_firebase_env FIREBASE_IOS_API_KEY)"
    _set_macos_firebase_value GOOGLE_APP_ID "$(_macos_firebase_env FIREBASE_IOS_APP_ID)"
    _set_macos_firebase_value GCM_SENDER_ID "$(_macos_firebase_env FIREBASE_PROJECT_NUMBER)"
    _set_macos_firebase_value PROJECT_ID "$project_id"
    if [ -n "$project_id" ]; then
        _set_macos_firebase_value STORAGE_BUCKET "${project_id}.firebasestorage.app"
    fi

    echo -e "${GREEN}[OK] Injected Firebase macOS credentials${NC}"
}

restore_firebase_macos() {
    if [ -f "$BACKUP_MACOS_GOOGLESERVICE_INFO_PLIST" ]; then
        mv "$BACKUP_MACOS_GOOGLESERVICE_INFO_PLIST" "$MACOS_GOOGLESERVICE_INFO_PLIST"
        echo -e "${GREEN}[OK] Restored original macOS GoogleService-Info.plist${NC}"
    fi
}
