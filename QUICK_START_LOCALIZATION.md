# Quick Start Guide: Multi-Language Setup

## ✅ What's Been Done

I've successfully set up multi-language support for your Defyx VPN app with support for:
- 🇬🇧 **English** (en) - Default
- 🇮🇷 **فارسی / Farsi** (fa) - Persian
- 🇨🇳 **中文 / Chinese** (zh)
- 🇷🇺 **Русский / Russian** (ru)

## 📁 Files Created/Modified

### Configuration Files
- ✅ `l10n.yaml` - Localization configuration
- ✅ `pubspec.yaml` - Added flutter_localizations dependency

### Translation Files (in `lib/l10n/`)
- ✅ `app_en.arb` - English translations (template)
- ✅ `app_fa.arb` - Farsi/Persian translations
- ✅ `app_zh.arb` - Chinese translations
- ✅ `app_ru.arb` - Russian translations

### Provider & Widgets
- ✅ `lib/shared/providers/language_provider.dart` - Language management
- ✅ `lib/shared/widgets/language_selector.dart` - Language selector UI
- ✅ `lib/core/utils/localization_extension.dart` - Helper extension

### Updated Files
- ✅ `lib/app/app.dart` - Integrated localization support

### Documentation
- ✅ `MULTILANGUAGE_GUIDE.md` - Complete implementation guide
- ✅ `LOCALIZATION_EXAMPLES.dart` - Code examples
- ✅ `scripts/find_hardcoded_strings.sh` - Helper script

## 🚀 Next Steps

### 1. Generate Localization Files
Run this command in your terminal:
```bash
flutter pub get
flutter gen-l10n
```

This will generate the localization classes in `.dart_tool/flutter_gen/gen_l10n/`

### 2. Add Language Selector to Settings

Open your settings screen and add the language selector widget:

```dart
import 'package:defyx_vpn/shared/widgets/language_selector.dart';

// In your settings screen widget tree:
const LanguageSelector()
```

### 3. Replace Hardcoded Strings

Example - Update your splash screen:

**Before:**
```dart
Text("Crafted for secure internet access,\ndesigned for everyone, everywhere")
```

**After:**
```dart
import 'package:defyx_vpn/core/utils/localization_extension.dart';

Text(context.l10n.splashSubtitle)
```

### 4. Common Replacements

Here are some common strings you'll want to replace:

```dart
// Buttons
'Connect' → context.l10n.connect
'Disconnect' → context.l10n.disconnect
'Close' → context.l10n.close

// Status
'Connected' → context.l10n.connected
'Disconnected' → context.l10n.disconnected
'Connecting' → context.l10n.connecting

// Menu items
'Settings' → context.l10n.settings
'Privacy Policy' → context.l10n.privacyPolicy
'Terms & Conditions' → context.l10n.termsAndConditions

// Speed test
'DOWNLOAD' → context.l10n.download
'UPLOAD' → context.l10n.upload
'PING' → context.l10n.ping
'LATENCY' → context.l10n.latency
```

## 📝 Adding New Translations

When you need to add a new translatable string:

1. **Add to English file** (`lib/l10n/app_en.arb`):
```json
{
  "myNewString": "My Text in English",
  "@myNewString": {
    "description": "Description of what this text is for"
  }
}
```

2. **Add to other language files** with translations:
- `app_fa.arb`: "متن من به فارسی"
- `app_zh.arb`: "我的中文文本"
- `app_ru.arb`: "Мой текст на русском"

3. **Regenerate**:
```bash
flutter gen-l10n
```

4. **Use in code**:
```dart
Text(context.l10n.myNewString)
```

## 🔍 Finding Hardcoded Strings

Use the helper script to find strings that need translation:
```bash
chmod +x scripts/find_hardcoded_strings.sh
./scripts/find_hardcoded_strings.sh
```

## 🎨 RTL Support

Farsi (Persian) is automatically configured for RTL (Right-to-Left) text direction. Flutter will handle the layout mirroring automatically.

## 🧪 Testing

Test your app with different languages:

```dart
// Read current language
final currentLang = ref.watch(languageProvider).language;

// Change language
ref.read(languageProvider.notifier).changeLanguage(AppLanguage.farsi);
ref.read(languageProvider.notifier).changeLanguage(AppLanguage.chinese);
ref.read(languageProvider.notifier).changeLanguage(AppLanguage.russian);
ref.read(languageProvider.notifier).changeLanguage(AppLanguage.english);
```

## 📚 Available Translation Keys

All available keys are documented in `MULTILANGUAGE_GUIDE.md`, including:
- App title and branding
- Connection states
- Speed test labels
- Menu items
- Status messages
- Units (Mbps, ms)
- Language names

## 💡 Tips

1. **Always import the extension** for easier access:
   ```dart
   import 'package:defyx_vpn/core/utils/localization_extension.dart';
   ```

2. **Use const when possible**:
   ```dart
   // Don't use const with localized strings
   Text(context.l10n.connect) // ✅ Correct
   const Text(context.l10n.connect) // ❌ Won't work
   ```

3. **Test UI with all languages** to ensure text fits properly

4. **Keep ARB files in sync** - all language files should have the same keys

## 🐛 Troubleshooting

**Issue: "AppLocalizations not found"**
- Solution: Run `flutter pub get && flutter gen-l10n`

**Issue: Language not changing**
- Solution: Hot restart the app (not just hot reload)

**Issue: RTL not working for Farsi**
- Solution: This should work automatically, but ensure you're using Material/Cupertino widgets

## 📞 Need Help?

Refer to the complete guide: `MULTILANGUAGE_GUIDE.md`

---

**You're all set! 🎉** 

The foundation is complete. Now you just need to:
1. Run `flutter pub get && flutter gen-l10n`
2. Add the language selector to your settings
3. Gradually replace hardcoded strings with localized versions
