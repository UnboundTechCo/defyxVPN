// Example: How to update splash_screen.dart to use localization

// Add this import at the top:
import 'package:defyx_vpn/core/utils/localization_extension.dart';
// or
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Then in the _buildSubtitle method, replace:
Widget _buildSubtitle() {
  return Text(
    "Crafted for secure internet access,\ndesigned for everyone, everywhere",
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: 'Lato',
      fontSize: 18.sp,
      color: const Color(0xFFCFCFCF),
      fontWeight: FontWeight.w500,
    ),
  );
}

// With:
Widget _buildSubtitle() {
  return Text(
    context.l10n.splashSubtitle,  // Using the extension
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: 'Lato',
      fontSize: 18.sp,
      color: const Color(0xFFCFCFCF),
      fontWeight: FontWeight.w500,
    ),
  );
}

// Or using AppLocalizations directly:
Widget _buildSubtitle() {
  return Text(
    AppLocalizations.of(context)!.splashSubtitle,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontFamily: 'Lato',
      fontSize: 18.sp,
      color: const Color(0xFFCFCFCF),
      fontWeight: FontWeight.w500,
    ),
  );
}
