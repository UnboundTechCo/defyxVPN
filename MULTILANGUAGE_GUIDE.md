# Multi-Language Support Documentation

This document explains how the multi-language (internationalization) feature is implemented in the Defyx VPN app.

## Supported Languages

The app currently supports the following languages:
- **English** (en) - Default
- **فارسی / Farsi** (fa) - Persian
- **中文 / Chinese** (zh)
- **Русский / Russian** (ru)

## Architecture

### 1. Configuration Files

#### `l10n.yaml`
This file configures the localization generation:
- ARB files location: `lib/l10n/`
- Template file: `app_en.arb` (English)
- Output file: `app_localizations.dart`

#### ARB Files in `lib/l10n/`
- `app_en.arb` - English translations (template)
- `app_fa.arb` - Farsi/Persian translations
- `app_zh.arb` - Chinese translations
- `app_ru.arb` - Russian translations

### 2. Language Provider

**File:** `lib/shared/providers/language_provider.dart`

The language provider manages:
- Current language selection
- Language persistence using SharedPreferences
- Language switching functionality

**Usage:**
```dart
// Read current language
final languageState = ref.watch(languageProvider);

// Change language
ref.read(languageProvider.notifier).changeLanguage(AppLanguage.russian);
```

### 3. Language Selector Widget

**File:** `lib/shared/widgets/language_selector.dart`

A reusable widget that displays all available languages and allows users to switch between them.

**Usage in Settings:**
```dart
import 'package:defyx_vpn/shared/widgets/language_selector.dart';

// In your settings screen:
const LanguageSelector()
```

## How to Use Translations

### 1. Access Translations in Widgets

Using the extension:
```dart
import 'package:defyx_vpn/core/utils/localization_extension.dart';

Text(context.l10n.connect)
```

Using AppLocalizations directly:
```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

Text(AppLocalizations.of(context)!.connect)
```

### 2. Example Replacements

Replace hardcoded strings:

**Before:**
```dart
Text('Connect')
```

**After:**
```dart
Text(context.l10n.connect)
```

**Before:**
```dart
const Text('Privacy Policy')
```

**After:**
```dart
Text(context.l10n.privacyPolicy)
```

## Adding New Translations

### Step 1: Add to English ARB file
Edit `lib/l10n/app_en.arb`:
```json
{
  "newKey": "English Text",
  "@newKey": {
    "description": "Description of what this text is for"
  }
}
```

### Step 2: Add to all other ARB files
Add the same key with translated text to:
- `app_fa.arb` (Farsi)
- `app_zh.arb` (Chinese)
- `app_ru.arb` (Russian)

### Step 3: Generate localization files
Run in terminal:
```bash
flutter gen-l10n
```

Or simply run:
```bash
flutter pub get
```

This will generate the localization classes in `.dart_tool/flutter_gen/gen_l10n/`

### Step 4: Use in code
```dart
Text(context.l10n.newKey)
```

## Available Translation Keys

Here are the currently available translation keys:

- `appTitle` - Application title
- `splashSubtitle` - Splash screen subtitle
- `connect` - Connect button
- `disconnect` - Disconnect button
- `connected` - Connected status
- `disconnected` - Disconnected status
- `connecting` - Connecting status
- `speedTest` - Speed test label
- `download` - Download label
- `upload` - Upload label
- `ping` - Ping label
- `latency` - Latency label
- `jitter` - Jitter label
- `packetLoss` - Packet loss label
- `settings` - Settings menu
- `introduction` - Introduction menu item
- `privacyPolicy` - Privacy policy
- `termsAndConditions` - Terms and conditions
- `ourWebsite` - Our website
- `sourceCode` - Source code link
- `openSourceLicenses` - Open source licenses
- `betaCommunity` - Beta community
- `close` - Close button
- `copyLogs` - Copy logs button
- `logsCopied` - Logs copied message
- `quickMenu` - Quick menu
- `noInternet` - No internet status
- `error` - Error status
- `loading` - Loading status
- `analyzing` - Analyzing status
- `mbps` - Megabits per second unit
- `ms` - Milliseconds unit
- `language` - Language setting
- `english` - English language name
- `persian` - Persian language name
- `chinese` - Chinese language name
- `russian` - Russian language name

## Implementation Checklist

To fully integrate multi-language support:

1. ✅ Add `flutter_localizations` to `pubspec.yaml`
2. ✅ Create `l10n.yaml` configuration
3. ✅ Create ARB translation files for all languages
4. ✅ Create language provider
5. ✅ Update `app.dart` with localization delegates
6. ✅ Create language selector widget
7. ✅ Create localization extension helper
8. ⏳ Run `flutter gen-l10n` to generate code
9. ⏳ Replace hardcoded strings with localized versions
10. ⏳ Add language selector to settings screen

## Text Direction Support

The app automatically handles RTL (Right-to-Left) for languages like Farsi:
- Farsi (Persian) uses RTL text direction
- UI elements will automatically flip for RTL languages
- No additional code needed for basic RTL support

## Best Practices

1. **Always use translation keys** instead of hardcoded strings
2. **Add descriptive @descriptions** in the English ARB file
3. **Keep keys consistent** across all ARB files
4. **Test with all languages** to ensure UI layout works
5. **Consider text expansion** - some languages need more space
6. **Use proper fonts** that support all character sets

## Troubleshooting

### Localization files not generating?
Run: `flutter clean && flutter pub get && flutter gen-l10n`

### Language not changing?
- Check if SharedPreferences is working
- Ensure provider is properly overridden in app.dart
- Restart the app after changing language

### Missing translations?
- Verify the key exists in all ARB files
- Check for typos in key names
- Regenerate with `flutter gen-l10n`

## Future Enhancements

Potential improvements:
- Add more languages (Arabic, Spanish, French, etc.)
- Implement automatic language detection based on device settings
- Add date/time formatting per locale
- Add number formatting per locale
- Add plural support for count-based strings
