#!/bin/bash

# Script to find hardcoded strings in Dart files
# This helps identify strings that need to be moved to localization files

echo "==================================="
echo "Finding Hardcoded Strings in Dart Files"
echo "==================================="
echo ""

# Find Text widgets with hardcoded strings
echo "📝 Text widgets with hardcoded strings:"
echo "-----------------------------------"
grep -r "Text(" lib/ --include="*.dart" | grep -E "Text\(['\"]" | grep -v "TextStyle" | grep -v "context.l10n" | grep -v "AppLocalizations" | head -20

echo ""
echo "📝 SnackBar with hardcoded content:"
echo "-----------------------------------"
grep -r "SnackBar" lib/ --include="*.dart" | grep -E "content:" | head -10

echo ""
echo "📝 Dialog titles:"
echo "-----------------------------------"
grep -r "AlertDialog\|Dialog" lib/ --include="*.dart" | grep -E "title:" | head -10

echo ""
echo "==================================="
echo "To update these strings:"
echo "1. Add the string to lib/l10n/app_en.arb"
echo "2. Add translations to app_fa.arb, app_zh.arb, app_ru.arb"
echo "3. Run: flutter gen-l10n"
echo "4. Replace hardcoded string with context.l10n.yourKey"
echo "==================================="
