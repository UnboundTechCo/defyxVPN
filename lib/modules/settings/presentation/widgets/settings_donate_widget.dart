import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/custom_webview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class SettingsDonateWidget extends ConsumerWidget {
  final WidgetRef ref;
  final bool shouldExecuteAction;
  final bool Function()? onTapBefore;

  const SettingsDonateWidget({
    super.key,
    required this.ref,
    this.shouldExecuteAction = true,
    this.onTapBefore,
  });

  void _handleOpenDonationPage(BuildContext context, WidgetRef ref) {
    final url = dotenv.env["WEBSITE_DONATION"];
    final l10n = AppLocalizations.of(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CustomWebViewScreen(url: url!, title: l10n.settingsDonation),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return  Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          debugPrint('[DonateWidget] Tap detected! shouldExecuteAction=$shouldExecuteAction');
          if (shouldExecuteAction) {
            bool shouldExecute = onTapBefore?.call() ?? true;
            if (shouldExecute) {
              debugPrint('[DonateWidget] Opening donation page');
              _handleOpenDonationPage(context, ref);
            } else {
              debugPrint('[DonateWidget] Scrolling, not executing action');
            }
          }
        },
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.settingsDonation.toUpperCase(),
                  style: TextStyle(
                    fontSize: 17.sp,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                SizedBox(
                  width: 206.w,
                  child: Text(
                    l10n.settingsDonationDescription,
                    style: TextStyle(fontSize: 13.sp, color: Colors.white60),
                    maxLines: 3,
                    softWrap: true,
                  ),
                ),
              ],
            ),
            SizedBox(width: 10.w),
            Container(
              width: 50,
              height: 50,
              padding: EdgeInsets.all(13.w),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50.r),
                color: const Color(0xFF6F7987),
              ),
              child: AppIcons.money(width: 24, height: 24),
            ),
          ],
        ),
      ),
    );
  }
}
