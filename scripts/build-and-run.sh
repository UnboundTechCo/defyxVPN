#!/usr/bin/env bash

# ====================================================================
# DefyX VPN - Unified Build & Run Script
# ====================================================================
# Orchestrates: DXcore build.sh → copy framework → Flutter run.sh
# ====================================================================

set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

DXCORE_DIR="$(cd "${SCRIPT_DIR}/../../DXcore-private" && pwd)"
FLUTTER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

# Logging
log() { echo -e "${CYAN}[build-and-run]${NC} $*"; }
success() { echo -e "${GREEN}✅ $*${NC}"; }
error() { echo -e "${RED}❌ $*${NC}" >&2; }

# Config
CLEAN_BUILD=false
SKIP_CORE_BUILD=false
BUILD_ONLY=false
FLUTTER_DEVICE=""
PLATFORM_CHOICE=""

# ====================================================================
# Framework Copy Functions
# ====================================================================

copy_framework() {
    local platform="$1"
    log "📦 Copying ${platform} framework to Flutter project..."
    
    case "${platform}" in
        ios)
            local src="${DXCORE_DIR}/build/ios/IosDXcore.xcframework"
            local dst="${FLUTTER_DIR}/ios/IosDXcore.xcframework"
            ;;
        macos)
            local src="${DXCORE_DIR}/build/macos/MacDXcore.xcframework"
            local dst="${FLUTTER_DIR}/macos/MacDXcore.xcframework"
            ;;
        android)
            local src="${DXCORE_DIR}/build/android/DXcore.aar"
            local dst="${FLUTTER_DIR}/android/app/libs/DXcore.aar"
            mkdir -p "${FLUTTER_DIR}/android/app/libs"
            ;;
    esac
    
    if [[ ! -e "${src}" ]]; then
        error "Framework not found: ${src}"
        return 1
    fi
    
    rm -rf "${dst}"
    cp -R "${src}" "${dst}"
    success "Copied to: ${dst}"
}

# ====================================================================
# Main Workflow
# ====================================================================

build_and_run() {
    local platform="$1"
    
    # Step 1: Build DXcore framework (if not skipped)
    if [[ "${SKIP_CORE_BUILD}" == "false" ]]; then
        log "🔨 Building DXcore framework for ${platform}..."
        cd "${DXCORE_DIR}"
        
        # Map platform to build.sh menu choice
        local build_choice
        case "${platform}" in
            ios) build_choice="2" ;;
            macos) build_choice="5" ;;
            android) build_choice="1" ;;
        esac
        
        # Run build.sh non-interactively
        # Answer: platform choice + version choice (4 = Same Version)
        printf "%s\n4\n" "${build_choice}" | bash ./build.sh || {
            error "DXcore build failed"
            return 1
        }
        
        # Step 2: Copy framework to Flutter project
        copy_framework "${platform}" || return 1
    else
        log "⏭️  Skipping DXcore build"
    fi
    
    if [[ "${BUILD_ONLY}" == "true" ]]; then
        success "Build complete (not running Flutter app)"
        return 0
    fi
    
    # Step 3: Prepare Flutter project
    cd "${FLUTTER_DIR}"
    
    if [[ "${CLEAN_BUILD}" == "true" ]]; then
        log "🧹 Running flutter clean..."
        flutter clean
    fi
    
    log "📦 Running flutter pub get..."
    flutter pub get
    
    # Step 4: Run Flutter app
    log "🚀 Running Flutter app..."
    
    local device_arg=""
    if [[ -n "${FLUTTER_DEVICE}" ]]; then
        device_arg="-d ${FLUTTER_DEVICE}"
    fi
    
    # Use run.sh if it exists (handles Firebase injection)
    if [[ -f "${SCRIPT_DIR}/run.sh" ]]; then
        bash "${SCRIPT_DIR}/run.sh" ${device_arg}
    else
        flutter run ${device_arg}
    fi
}

# ====================================================================
# Menu
# ====================================================================

show_menu() {
    echo ""
    echo "════════════════════════════════════════════════"
    echo -e "${BOLD}${CYAN}   DefyX VPN - Build & Run${NC}"
    echo "════════════════════════════════════════════════"
    echo ""
    echo "    1) 📱 iOS          - Build & run"
    echo "    2) 🖥️  macOS        - Build & run"
    echo "    3) 🤖 Android      - Build & run"
    echo ""
    echo "    4) ⚡ iOS (Flutter only)   - Skip DXcore rebuild"
    echo "    5) ⚡ macOS (Flutter only) - Skip DXcore rebuild"
    echo "    6) ⚡ Android (Flutter only) - Skip DXcore rebuild"
    echo ""
    echo "    0) 🚪 Exit"
    echo ""
    echo "════════════════════════════════════════════════"
    echo ""
}

process_choice() {
    CLEAN_BUILD=false
    SKIP_CORE_BUILD=false
    
    case "$1" in
        1) PLATFORM_CHOICE="ios"; CLEAN_BUILD=true ;;
        2) PLATFORM_CHOICE="macos"; CLEAN_BUILD=true ;;
        3) PLATFORM_CHOICE="android"; CLEAN_BUILD=true ;;
        4) PLATFORM_CHOICE="ios"; SKIP_CORE_BUILD=true; CLEAN_BUILD=true ;;
        5) PLATFORM_CHOICE="macos"; SKIP_CORE_BUILD=true; CLEAN_BUILD=true ;;
        6) PLATFORM_CHOICE="android"; SKIP_CORE_BUILD=true; CLEAN_BUILD=true ;;
        0) log "Goodbye! 👋"; exit 0 ;;
        *) error "Invalid choice"; return 1 ;;
    esac
    return 0
}

# ====================================================================
# Main
# ====================================================================

main() {
    # Validate environment
    [[ ! -d "${DXCORE_DIR}" ]] && { error "DXcore-private not found"; exit 1; }
    [[ ! -d "${FLUTTER_DIR}" ]] && { error "defyxVPN-public not found"; exit 1; }
    [[ ! -f "${DXCORE_DIR}/build.sh" ]] && { error "build.sh not found"; exit 1; }
    
    # Command line mode
    if [[ $# -gt 0 ]]; then
        while [[ $# -gt 0 ]]; do
            case "$1" in
                ios|macos|android) PLATFORM_CHOICE="$1"; shift ;;
                --clean) CLEAN_BUILD=true; shift ;;
                --skip-core) SKIP_CORE_BUILD=true; shift ;;
                --build-only) BUILD_ONLY=true; shift ;;
                -d|--device) FLUTTER_DEVICE="$2"; shift 2 ;;
                --help|-h)
                    echo "Usage: $0 [ios|macos|android] [OPTIONS]"
                    echo ""
                    echo "Options:"
                    echo "  --clean       Clean Flutter build"
                    echo "  --skip-core   Skip DXcore rebuild"
                    echo "  --build-only  Build only, don't run"
                    echo "  -d DEVICE     Target device"
                    echo ""
                    echo "Examples:"
                    echo "  $0 ios                  # Build and run"
                    echo "  $0 macos --clean        # Clean build"
                    echo "  $0 ios --skip-core      # Flutter only"
                    echo "  $0                      # Interactive menu"
                    exit 0
                    ;;
                *) error "Unknown option: $1"; exit 1 ;;
            esac
        done
        
        [[ -z "${PLATFORM_CHOICE}" ]] && { error "Platform required"; exit 1; }
        build_and_run "${PLATFORM_CHOICE}"
        exit $?
    fi
    
    # Interactive menu mode
    while true; do
        show_menu
        read -p "Enter your choice (0-9): " choice
        echo ""
        
        if ! process_choice "${choice}"; then
            sleep 1
            continue
        fi
        
        if build_and_run "${PLATFORM_CHOICE}"; then
            echo ""
            read -p "Build another platform? (y/N): " again
            [[ ! "${again}" =~ ^[Yy]$ ]] && { log "Goodbye! 👋"; exit 0; }
        else
            error "Build failed"
            read -p "Try again? (y/N): " retry
            [[ ! "${retry}" =~ ^[Yy]$ ]] && exit 1
        fi
    done
}

main "$@"
