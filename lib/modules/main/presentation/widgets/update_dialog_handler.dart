import 'package:flutter/material.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/update_dialog.dart';

class UpdateDialogHandler {
  static bool dialogShowedOnce = false;
  static Future<void> checkAndShowUpdates(
    BuildContext context,
    Future<Map<String, dynamic>> Function() checkForUpdate,
  ) async {
    try {
      if (dialogShowedOnce) return;
      if (!context.mounted) return;

      final updateInfo = await checkForUpdate();

      if (!context.mounted) return;

      if (updateInfo['forceUpdate'] && updateInfo['update']) {
        await showUpdateDialog(context, true, []);
        dialogShowedOnce = true;
      } else if (updateInfo['update']) {
        await showUpdateDialog(context, false, updateInfo['changeLog']);
        dialogShowedOnce = true;
      }
    } catch (e) {
      debugPrint('Error checking for updates: $e');
    }
  }

  static Future<void> showUpdateDialog(
    BuildContext context,
    bool forceUpdate,
    List<dynamic> updateInfo,
  ) async {
    if (!context.mounted) {
      debugPrint('Widget is not mounted, cannot show dialog');
      return;
    }

    try {
      if (forceUpdate) {
        await CustomUpdateDialog.showUpdateDialog(
          context,
          updateType: UpdateType.required,
        );
      } else {
        await CustomUpdateDialog.showUpdateDialog(
          context,
          updateType: UpdateType.optional,
          features: updateInfo,
        );
      }
    } catch (e) {
      debugPrint('Error showing update dialog: $e');
    }
  }
}
