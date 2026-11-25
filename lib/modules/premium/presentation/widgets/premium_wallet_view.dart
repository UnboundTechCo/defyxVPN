import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/l10n/app_localizations.dart';
import 'package:defyx_vpn/modules/premium/providers/premium_wallet_provider.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:defyx_vpn/shared/widgets/tv_focusable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PremiumWalletView extends StatefulWidget {
  const PremiumWalletView({
    super.key,
    required this.balance,
    required this.showTopUpForm,
    required this.isLoading,
    required this.ref,
  });

  final double balance;
  final VoidCallback showTopUpForm;
  final bool isLoading;
  final WidgetRef ref;

  @override
  State<PremiumWalletView> createState() => _PremiumWalletViewState();
}

class _PremiumWalletViewState extends State<PremiumWalletView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _refreshController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );
  bool _isRefreshing = false;

  @override
  void dispose() {
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _refetchBalance(WidgetRef ref) async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);
    _refreshController.repeat();
    try {
      ref.invalidate(balanceProvider);
      await ref.read(balanceProvider.future);
    } catch (_) {
    } finally {
      if (mounted) {
        _refreshController
          ..stop()
          ..reset();
        setState(() => _isRefreshing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final symbol = '\$';
    final isLoggedIn = widget.ref.read(authProvider.notifier).isLoggedIn;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          child: Column(
            children: [
              Center(
                child: Container(
                  padding: EdgeInsets.all(24.w),
                  child: Column(
                    children: [
                      Text(
                        AppLocalizations.of(context).balance,
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      !widget.ref.read(authProvider.notifier).isLoggedIn
                          ? Text(
                              '-',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 36.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : widget.isLoading
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                  ),
                                )
                              : RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: symbol,
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 36.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      TextSpan(
                                        text: widget.balance.toStringAsFixed(2),
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 36.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                      SizedBox(height: 20.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppButton(
                            label: AppLocalizations.of(context).topUp,
                            onPressed: () {
                              widget.showTopUpForm();
                            },
                            variant: AppButtonVariant.blue,
                            width: 150.w,
                            round: AppButtonRound.circle,
                            isLoading: widget.isLoading,
                          ),
                          SizedBox(width: 12.w),
                          TvFocusable(
                            onTap: () {
                              if (isLoggedIn) {
                                _refetchBalance(widget.ref);
                              }
                            },
                            behavior: HitTestBehavior.deferToChild,
                            shape: BoxShape.circle,
                            child: Container(
                              width: 40.w,
                              height: 40.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.6),
                              ),
                              child: RotationTransition(
                                turns: _refreshController,
                                child: Icon(
                                  Icons.refresh,
                                  color: Colors.white,
                                  size: 20.w,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
