import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/common/dtos/subscription_usage_dto.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/core/utils/toast_util.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/core/vpn.dart';
import 'package:defyx_vpn/modules/settings/models/settings_item.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/jump_server_dialog.dart';
import 'package:defyx_vpn/modules/settings/presentation/widgets/subscription_usage_ring.dart';
import 'package:defyx_vpn/modules/settings/providers/marketplace_info_provider.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class MarketplaceInfoSheet extends ConsumerStatefulWidget {
  final SettingsItem item;

  const MarketplaceInfoSheet({super.key, required this.item});

  static Future<void> show(BuildContext context, SettingsItem item) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      builder: (_) => MarketplaceInfoSheet(item: item),
    );
  }

  @override
  ConsumerState<MarketplaceInfoSheet> createState() =>
      _MarketplaceInfoSheetState();
}

class _MarketplaceInfoSheetState extends ConsumerState<MarketplaceInfoSheet> {
  static const Color _dataColor = Color(0xFF10B981);
  static const Color _timeColor = Color(0xFFFFC927);
  static const String _emptyValue = '--';

  bool _isJumping = false;

  String get _label => widget.item.title;

  Future<void> _handleJump() async {
    if (_isJumping) return;

    final l10n = AppLocalizations.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    final isVpnRunning = ref.read(connectionStateProvider).status.isVpnRunning;

    if (isVpnRunning) {
      final confirmed = await JumpServerDialog.show(context);
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isJumping = true);
    try {
      if (isVpnRunning) {
        await VPN(container).disconnectIfRunning(ref);
      }
      await ref.read(marketplaceInfoServiceProvider).jumpServer(_label);
      ToastUtil.showToast(l10n.marketplaceInfoJumpSuccess);
      if (mounted) {
        ref.invalidate(subscriptionUsageProvider(_label));
      }
    } catch (error) {
      ToastUtil.showToast(
        '${l10n.marketplaceInfoJumpFailed}: ${_errorMessage(error)}',
      );
    } finally {
      if (mounted) {
        setState(() => _isJumping = false);
      }
    }
  }

  String _errorMessage(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  String _formatVolume(double volume) => volume == volume.roundToDouble()
      ? volume.toInt().toString()
      : volume.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final usage = ref.watch(subscriptionUsageProvider(_label));

    return PopScope(
      canPop: !_isJumping,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(38.w, 29.h, 38.w, 38.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                SizedBox(height: 20.h),
                Text(
                  l10n.marketplaceInfoDescription,
                  style: TextStyle(
                    fontSize: 16.5.sp,
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFF8A8A8A),
                    height: 1.3,
                  ),
                ),
                SizedBox(height: 26.h),
                usage.when(
                  skipLoadingOnRefresh: false,
                  data: (usage) => _buildUsage(l10n, usage),
                  loading: () => _buildRings(
                    const SubscriptionUsageRingShimmer(),
                    const SubscriptionUsageRingShimmer(),
                  ),
                  error: (_, _) => _buildUsageError(l10n),
                ),
                SizedBox(height: 25.h),
                _buildJumpCard(l10n),
                SizedBox(height: 20.h),
                AppButton(
                  label: l10n.gotIt,
                  variant: AppButtonVariant.secondary,
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        AppIcons.premiumVerified(width: 20.w, height: 20.w),
        SizedBox(width: 13.w),
        Expanded(
          child: Text(
            _label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 18.sp,
              fontFamily: AppTheme.fontFamily,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRings(Widget dataRing, Widget timeRing) {
    return Row(
      children: [
        Expanded(child: AspectRatio(aspectRatio: 1, child: dataRing)),
        SizedBox(width: 27.w),
        Expanded(child: AspectRatio(aspectRatio: 1, child: timeRing)),
      ],
    );
  }

  Widget _buildUsage(AppLocalizations l10n, SubscriptionUsageResponse usage) {
    return _buildRings(
      SubscriptionUsageRing(
        usedFraction: usage.usedVolumeFraction,
        remaining: _formatVolume(usage.remainingVolumeGb),
        total:
            '${_formatVolume(usage.totalVolumeGb)} ${l10n.marketplaceInfoGigabytes}',
        label: l10n.marketplaceInfoRemainingData,
        color: _dataColor,
      ),
      SubscriptionUsageRing(
        usedFraction: usage.usedDaysFraction,
        remaining: usage.remainingDays.toString(),
        total: '${usage.totalDays} ${l10n.marketplaceInfoDays.toUpperCase()}',
        label: l10n.marketplaceInfoRemainingTime,
        color: _timeColor,
      ),
    );
  }

  Widget _buildUsageError(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildRings(
          SubscriptionUsageRing(
            usedFraction: 0,
            remaining: _emptyValue,
            total: l10n.marketplaceInfoGigabytes,
            label: l10n.marketplaceInfoRemainingData,
            color: _dataColor,
          ),
          SubscriptionUsageRing(
            usedFraction: 0,
            remaining: _emptyValue,
            total: l10n.marketplaceInfoDays.toUpperCase(),
            label: l10n.marketplaceInfoRemainingTime,
            color: _timeColor,
          ),
        ),
        SizedBox(height: 16.h),
        Container(
          padding: EdgeInsetsDirectional.fromSTEB(12.w, 4.h, 4.w, 4.h),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF6E0),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 18.sp,
                color: const Color(0xFFD99A00),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  l10n.marketplaceInfoUsageError,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontFamily: AppTheme.fontFamily,
                    color: const Color(0xFF6B5200),
                    height: 1.3,
                  ),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.invalidate(subscriptionUsageProvider(_label)),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1F4D3F),
                ),
                child: Text(
                  l10n.marketplaceInfoRetry.toUpperCase(),
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontFamily: AppTheme.fontFamily,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJumpCard(AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.all(15.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE3E3E3)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF8FE3C9),
              borderRadius: BorderRadius.circular(6.r),
            ),
            child: AppIcons.jump(width: 26.w, height: 26.w),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Text(
              l10n.marketplaceInfoJumpDescription,
              style: TextStyle(
                fontSize: 14.sp,
                fontFamily: AppTheme.fontFamily,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF1A1A1A),
                height: 1.2,
              ),
            ),
          ),
          SizedBox(width: 12.w),
          _buildJumpButton(l10n),
        ],
      ),
    );
  }

  Widget _buildJumpButton(AppLocalizations l10n) {
    const foregroundColor = Color(0xFF1F4D3F);

    return SizedBox(
      height: 41.h,
      child: TextButton(
        onPressed: _isJumping ? null : _handleJump,
        style: TextButton.styleFrom(
          minimumSize: Size(60.w, 41.h),
          padding: EdgeInsets.symmetric(horizontal: 10.w),
          backgroundColor: const Color(0xFFF0F0F0),
          disabledBackgroundColor: const Color(0xFFF0F0F0),
          foregroundColor: foregroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
        ),
        child: _isJumping
            ? SizedBox(
                width: 16.w,
                height: 16.w,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
                ),
              )
            : Text(
                l10n.marketplaceInfoJump.toUpperCase(),
                style: TextStyle(
                  fontSize: 14.sp,
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w500,
                  color: foregroundColor,
                ),
              ),
      ),
    );
  }
}
