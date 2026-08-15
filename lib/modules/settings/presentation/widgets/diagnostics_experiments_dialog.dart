import 'dart:io';

import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/main/presentation/widgets/logs_widget.dart';
import 'package:defyx_vpn/shared/providers/haptics_provider.dart';
import 'package:defyx_vpn/shared/providers/language_provider.dart';
import 'package:defyx_vpn/shared/widgets/defyx_switch.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DiagnosticsExperimentsDialog extends ConsumerStatefulWidget {
  const DiagnosticsExperimentsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const DiagnosticsExperimentsDialog(),
    );
  }

  @override
  ConsumerState<DiagnosticsExperimentsDialog> createState() =>
      _DiagnosticsExperimentsDialogState();
}

class _DiagnosticsExperimentsDialogState
    extends ConsumerState<DiagnosticsExperimentsDialog> {
  final MenuController _languageMenuController = MenuController();

  bool get _isMobilePlatform =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String _languageLabel(AppLocalizations l10n, AppLanguage language) {
    switch (language) {
      case AppLanguage.english:
        return l10n.english;
      // case AppLanguage.persian:
      //   return l10n.persian;
      case AppLanguage.chinese:
        return l10n.chinese;
      case AppLanguage.russian:
        return l10n.russian;
    }
  }

  TextStyle get _labelStyle => TextStyle(
    fontSize: 14.sp,
    fontFamily: 'Lato',
    fontWeight: FontWeight.w600,
    color: Colors.black87,
    letterSpacing: 0.3,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final languageState = ref.watch(languageProvider);
    final languageNotifier = ref.read(languageProvider.notifier);
    final hapticsEnabled = ref.watch(hapticsProvider);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      child: Container(
        padding: EdgeInsets.all(20.w),
        width: 343.w,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15.r),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.settingsDiagnosticsExperiments,
              style: TextStyle(
                fontFamily: 'Lato',
                fontSize: 20.sp,
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            SizedBox(height: 16.h),
            _buildLanguageRow(l10n, languageState, languageNotifier),
            if (_isMobilePlatform) ...[
              SizedBox(height: 12.h),
              _buildHapticsRow(l10n, hapticsEnabled),
            ],
            SizedBox(height: 12.h),
            _buildAppLogsRow(l10n),
            SizedBox(height: 20.h),
            AppButton(
              label: l10n.gotIt,
              onPressed: () => Navigator.of(context).pop(),
              size: AppButtonSize.small,
              variant: AppButtonVariant.secondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageRow(
    AppLocalizations l10n,
    LanguageState languageState,
    LanguageNotifier languageNotifier,
  ) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.language.toUpperCase(), style: _labelStyle),
          MenuAnchor(
            controller: _languageMenuController,
            alignmentOffset: Offset(0, 4.h),
            consumeOutsideTap: true,
            useRootOverlay: true,
            style: MenuStyle(
              alignment: AlignmentDirectional.bottomEnd,
              backgroundColor: WidgetStateProperty.all(Colors.white),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              elevation: WidgetStateProperty.all(8),
              padding: WidgetStateProperty.all(EdgeInsets.zero),
            ),
            menuChildren: [
              ConstrainedBox(
                constraints: BoxConstraints(maxHeight: 220.h),
                child: SingleChildScrollView(
                  child: SizedBox(
                    width: 180.w,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _languageOption(
                          label: l10n.settingsAutoDetect,
                          selected: languageState.isAutoDetect,
                          onTap: () {
                            languageNotifier.enableAutoDetect();
                            _languageMenuController.close();
                          },
                        ),
                        ...AppLanguage.values.map(
                          (language) => _languageOption(
                            label: _languageLabel(l10n, language),
                            selected:
                                !languageState.isAutoDetect &&
                                languageState.language == language,
                            onTap: () {
                              languageNotifier.changeLanguage(language);
                              _languageMenuController.close();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            builder: (context, controller, child) {
              return GestureDetector(
                onTap: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                child: child,
              );
            },
            child: Text(
              languageState.isAutoDetect
                  ? l10n.settingsAutoDetect
                  : _languageLabel(l10n, languageState.language),
              style: TextStyle(
                fontSize: 14.sp,
                fontFamily: 'Lato',
                color: Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _languageOption({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        color: selected ? const Color(0xFFF0F0F0) : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15.sp,
            fontFamily: 'Lato',
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildHapticsRow(AppLocalizations l10n, bool hapticsEnabled) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(l10n.settingsHapticFeedback.toUpperCase(), style: _labelStyle),
          DefyxSwitch(
            value: hapticsEnabled,
            onChanged: (value) =>
                ref.read(hapticsProvider.notifier).setEnabled(value),
          ),
        ],
      ),
    );
  }

  Widget _buildAppLogsRow(AppLocalizations l10n) {
    return InkWell(
      onTap: () => showAppLogsOverlay(context),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 6.h),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(l10n.appLogs.toUpperCase(), style: _labelStyle),
            Icon(Icons.chevron_right, size: 20.sp, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
