#!/bin/bash

# TestFlight and the Mac App Store take the same upload, so both build types
# end in one signed .pkg in build/macos/pkg. Upload it with Transporter.
build_macos() {
    local build_type=$1
    echo -e "${BLUE}💻 Building macOS for $build_type...${NC}"

    if [ "$build_type" != "testFlight" ] && [ "$build_type" != "appStore" ]; then
        echo -e "${RED}❌ Invalid macOS build type${NC}"
        exit 1
    fi
    update_build_type "$build_type"

    flutter clean
    flutter pub get

    # Writes the Flutter settings and pods the archive needs, without building
    # the app twice.
    flutter build macos --release --config-only

    local macos_dir="$PROJECT_ROOT/macos"
    local archive_path="$PROJECT_ROOT/build/macos/archive/Runner.xcarchive"
    local export_path="$PROJECT_ROOT/build/macos/pkg"
    local export_options="$PROJECT_ROOT/build/macos/ExportOptions.plist"
    local team_id
    team_id=$(grep -m1 -oE 'DEVELOPMENT_TEAM = [A-Z0-9]+' "$macos_dir/Runner.xcodeproj/project.pbxproj" | awk '{print $3}')

    # CI installs the Mac App Store profiles and names them in
    # MACOS_APP_PROFILE and MACOS_TUNNEL_PROFILE, which the Release settings
    # of the app and the tunnel read. A Mac with a signed-in Xcode account
    # signs automatically instead.
    local archive_signing export_signing
    if [ -n "${MACOS_APP_PROFILE:-}" ] && [ -n "${MACOS_TUNNEL_PROFILE:-}" ]; then
        echo -e "${BLUE}🔏 Signing with profiles \"$MACOS_APP_PROFILE\" and \"$MACOS_TUNNEL_PROFILE\"${NC}"
        archive_signing=(
            CODE_SIGN_STYLE=Manual
            "CODE_SIGN_IDENTITY=Apple Distribution"
            "MACOS_APP_PROFILE=$MACOS_APP_PROFILE"
            "MACOS_TUNNEL_PROFILE=$MACOS_TUNNEL_PROFILE"
        )
        export_signing="	<key>signingStyle</key>
	<string>manual</string>
	<key>signingCertificate</key>
	<string>Apple Distribution</string>
	<key>installerSigningCertificate</key>
	<string>3rd Party Mac Developer Installer</string>
	<key>provisioningProfiles</key>
	<dict>
		<key>de.unboundtech.defyxvpn</key>
		<string>$MACOS_APP_PROFILE</string>
		<key>de.unboundtech.defyxvpn.PacketTunnel</key>
		<string>$MACOS_TUNNEL_PROFILE</string>
	</dict>"
    else
        archive_signing=(-allowProvisioningUpdates)
        export_signing="	<key>signingStyle</key>
	<string>automatic</string>"
    fi

    xcodebuild \
        -workspace "$macos_dir/Runner.xcworkspace" \
        -scheme Runner \
        -configuration Release \
        -archivePath "$archive_path" \
        "${archive_signing[@]}" \
        archive || {
        echo -e "${RED}❌ macOS archive failed${NC}"
        return 1
    }

    mkdir -p "$(dirname "$export_options")"
    cat > "$export_options" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key>
	<string>app-store-connect</string>
	<key>destination</key>
	<string>export</string>
	<key>teamID</key>
	<string>$team_id</string>
$export_signing
</dict>
</plist>
EOF

    local export_flags=()
    if [ "${archive_signing[0]}" = "-allowProvisioningUpdates" ]; then
        export_flags=(-allowProvisioningUpdates)
    fi

    xcodebuild \
        -exportArchive \
        -archivePath "$archive_path" \
        -exportPath "$export_path" \
        -exportOptionsPlist "$export_options" \
        ${export_flags[@]+"${export_flags[@]}"} || {
        echo -e "${RED}❌ macOS export failed${NC}"
        return 1
    }

    echo -e "${GREEN}✅ macOS package: $export_path${NC}"

    upload_macos_dsyms "$archive_path"
}

upload_macos_dsyms() {
    local archive_path=$1
    local dsym_dir="$archive_path/dSYMs"
    local upload_script="$PROJECT_ROOT/macos/Pods/FirebaseCrashlytics/upload-symbols"
    local google_service="$PROJECT_ROOT/macos/Runner/GoogleService-Info.plist"

    echo -e "${BLUE}[POST-BUILD] Checking for macOS dSYMs to upload...${NC}"

    if [ ! -d "$dsym_dir" ]; then
        echo -e "${YELLOW}⚠️  dSYM directory not found: $dsym_dir${NC}"
        return 0
    fi

    if [ ! -f "$upload_script" ]; then
        echo -e "${YELLOW}⚠️  Firebase upload-symbols script not found${NC}"
        return 0
    fi

    echo -e "${CYAN}📤 Uploading macOS dSYMs to Firebase Crashlytics...${NC}"

    if "$upload_script" -gsp "$google_service" -p mac "$dsym_dir"; then
        echo -e "${GREEN}✅ dSYM upload successful${NC}"
    else
        echo -e "${YELLOW}⚠️  dSYM upload failed with exit code: $?${NC}"
    fi
}
