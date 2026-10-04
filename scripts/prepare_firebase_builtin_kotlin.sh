#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"
cd "$project_root"

pub_cache="${PUB_CACHE:-$HOME/.pub-cache}"

for plugin in firebase_analytics firebase_core; do
    version=$(awk -v package="$plugin" '
        $0 == "  " package ":" { reading = 1; next }
        reading && /^    version: / { gsub(/[" ]/, "", $2); print $2; exit }
        reading && /^  [^ ]/ { exit }
    ' pubspec.lock)
    gradle_file="${pub_cache}/hosted/pub.dev/${plugin}-${version}/android/build.gradle"
    if [[ -z "$version" || ! -f "$gradle_file" ]]; then
        printf 'Could not find cached Gradle script for %s\n' "$plugin" >&2
        exit 1
    fi

    count=$(grep -Ec "^[[:space:]]*apply plugin: 'kotlin-android'[[:space:]]*$" "$gradle_file" || true)
    if [[ "$count" == "1" ]]; then
        perl -0pi -e 's{^([ \t]*)apply plugin: \x27kotlin-android\x27}{$1pluginManager.apply(\x27kotlin-android\x27)}m' "$gradle_file"
    elif [[ "$count" != "0" ]] || ! grep -Fq "pluginManager.apply('kotlin-android')" "$gradle_file"; then
        printf 'Unexpected Kotlin plugin declaration in %s\n' "$gradle_file" >&2
        exit 1
    fi
done

ads_version=$(awk '
    $0 == "  google_mobile_ads:" { reading = 1; next }
    reading && /^    version: / { gsub(/[" ]/, "", $2); print $2; exit }
    reading && /^  [^ ]/ { exit }
' pubspec.lock)
webview_version=$(awk '
    $0 == "  webview_flutter_android:" { reading = 1; next }
    reading && /^    version: / { gsub(/[" ]/, "", $2); print $2; exit }
    reading && /^  [^ ]/ { exit }
' pubspec.lock)
ads_dir="${pub_cache}/hosted/pub.dev/google_mobile_ads-${ads_version}/android/src/main/java/io/flutter/plugins/googlemobileads"
ads_wrapper="${ads_dir}/FlutterMobileAdsWrapper.java"
ads_plugin="${ads_dir}/GoogleMobileAdsPlugin.java"
webview_api="${pub_cache}/hosted/pub.dev/webview_flutter_android-${webview_version}/android/src/main/java/io/flutter/plugins/webviewflutter/WebViewFlutterAndroidExternalApi.java"

if [[ -z "$ads_version" || -z "$webview_version" || ! -f "$ads_wrapper" || ! -f "$ads_plugin" || ! -f "$webview_api" ]]; then
    printf 'Could not find cached Google Mobile Ads or WebView Android sources\n' >&2
    exit 1
fi
if ! grep -Fq 'getWebView(@NonNull FlutterPlugin.FlutterPluginBinding binding' "$webview_api"; then
    printf 'The locked WebView Android plugin does not provide the binding-based getWebView API\n' >&2
    exit 1
fi

if grep -Fq 'FlutterEngine flutterEngine' "$ads_wrapper"; then
    perl -0pi -e 's/import io\.flutter\.embedding\.engine\.FlutterEngine;/import io.flutter.embedding.engine.plugins.FlutterPlugin;/; s/public void registerWebView\(int webViewId, FlutterEngine flutterEngine\)/public void registerWebView(int webViewId, FlutterPlugin.FlutterPluginBinding pluginBinding)/; s/WebViewFlutterAndroidExternalApi\.getWebView\(flutterEngine, webViewId\)/WebViewFlutterAndroidExternalApi.getWebView(pluginBinding, webViewId)/' "$ads_wrapper"
fi
if grep -Fq 'registerWebView(webViewId, pluginBinding.getFlutterEngine())' "$ads_plugin"; then
    perl -0pi -e 's/registerWebView\(webViewId, pluginBinding\.getFlutterEngine\(\)\)/registerWebView(webViewId, pluginBinding)/' "$ads_plugin"
fi
if grep -Fq 'WebViewFlutterAndroidExternalApi.getWebView(flutterEngine, webViewId)' "$ads_wrapper" || grep -Fq 'registerWebView(webViewId, pluginBinding.getFlutterEngine())' "$ads_plugin"; then
    printf 'Could not update the deprecated WebView API calls in google_mobile_ads %s\n' "$ads_version" >&2
    exit 1
fi