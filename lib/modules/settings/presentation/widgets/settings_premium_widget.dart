import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage.dart';
import 'package:defyx_vpn/core/data/local/secure_storage/secure_storage_const.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_premium_info_dialog.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_premium_login_dialog.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/settings_premium_trouble_dialog.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final secureStorage = ref.watch(secureStorageProvider);

  final token = await secureStorage.read(premiumTokenKey);

  return token != null && token.isNotEmpty;
});

class SettingsPremiumWidget extends ConsumerWidget {
  final WidgetRef ref;
  final bool shouldExecuteAction;
  final bool Function()? onTapBefore;

  const SettingsPremiumWidget({
    super.key,
    required this.ref,
    this.shouldExecuteAction = true,
    this.onTapBefore,
  });

  void _handleOpenLoginDialog(BuildContext context, WidgetRef ref) {
    final connectionState = ref.read(connectionStateProvider);

    if (connectionState.status == ConnectionStatus.connected) {
      SettingsPremiumLoginDialog.show(context, ref);
      return;
    }
    SettingsPremiumInfoDialog.show(context, ref);
  }

  Widget _buildLoginButton(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final authState = ref.watch(authProvider);

    return authState.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text(l10n.error),
      data: (authData) {
        final defaultTapHandler = authData.isLoggedIn
            ? () => SettingsPremiumTroubleDialog.show(
                context,
                ref,
                authData.email,
              )
            : () => _handleOpenLoginDialog(context, ref);

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            debugPrint('[PremiumWidget] Tap detected! shouldExecuteAction=$shouldExecuteAction, isLoggedIn=${authData.isLoggedIn}');
            if (shouldExecuteAction) {
              bool shouldExecute = onTapBefore?.call() ?? true;
              if (shouldExecute) {
                debugPrint('[PremiumWidget] Executing tap handler');
                defaultTapHandler.call();
              } else {
                debugPrint('[PremiumWidget] Scrolling, not executing action');
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
                    l10n.settingsMarketplace.toUpperCase(),
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
                      l10n.marketplaceDescription,
                      style: TextStyle(fontSize: 13.sp, color: Colors.white60),
                      maxLines: 3,
                      softWrap: true,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppIcons.info(
                        height: 16,
                        width: 16,
                        colorFilter: ColorFilter.mode(
                          Colors.white.withOpacity(0.16),
                          BlendMode.srcIn,
                        ),
                      ),
                      SizedBox(width: 4.w),

                      authData.isLoggedIn
                          ? Text(
                              l10n.loggedIn,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: const Color(0xFFA3FF8C),
                              ),
                            )
                          : Text(
                              l10n.loginOrRegister,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: const Color(0xFFFF9A9A),
                              ),
                            ),
                    ],
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
                child: AppIcons.shop(width: 24, height: 24),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        // #EAEAEA29
        // color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(color: Colors.white.withOpacity(0.16), width: 1),
      ),
      child: _buildLoginButton(context, ref),
    );
  }
}
