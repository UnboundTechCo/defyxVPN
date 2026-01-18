import 'package:defyx_vpn/shared/layout/navbar/widgets/copyable_link.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/intro_link_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class IntroductionDialog extends StatelessWidget {
  const IntroductionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15.r)),
      child: Container(
        padding: EdgeInsets.all(25.w),
        width: 343.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.introduction,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            SizedBox(height: 15.h),
            Text(
              l10n.defyxGoal,
              style: TextStyle(
                fontSize: 15.sp,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 10.h),
            Text(
              l10n.learnMore,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: 15.h),
            IntroLinkItem(
              title: l10n.sourceCode,
              url: 'https://github.com/UnboundTechCo/defyxVPN',
            ),
            SizedBox(height: 10.h),
            IntroLinkItem(
              title: l10n.openSourceLicenses,
              url:
                  'https://github.com/UnboundTechCo/DXcore?tab=readme-ov-file#third-party-licenses',
            ),
            SizedBox(height: 10.h),
            CopyableLink(text: 'defyxvpn.com'),
            SizedBox(height: 10.h),
            IntroLinkItem(
              title: l10n.betaCommunity,
              url: 'https://t.me/+KuigyCHadIpiNDhi',
            ),
            SizedBox(height: 20.h),
            SizedBox(
              width: double.infinity,
              height: 46.h,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  shadowColor: Colors.transparent,
                  backgroundColor: Colors.grey[200],
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  l10n.gotIt,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
