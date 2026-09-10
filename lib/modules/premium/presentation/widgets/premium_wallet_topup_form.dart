import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/common/components/text_field.dart';
import 'package:defyx_vpn/core/purchase/purchase_service.dart';
import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/modules/premium/providers/premium_wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';

class PremiumTopUp extends StatefulWidget {
  const PremiumTopUp({
    super.key,
    required this.currentBalance,
    required this.ref,
    required this.closeTopUpForm,
  });

  final double currentBalance;
  final WidgetRef ref;
  final VoidCallback closeTopUpForm;

  @override
  State<PremiumTopUp> createState() => _PremiumTopUpState();
}

class _PremiumTopUpState extends State<PremiumTopUp> {
  final _amountController = TextEditingController();
  String _selectedPaymentMethod = 'Apple Pay';

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> refreshBalance() async {
    widget.ref.invalidate(balanceProvider);
    await widget.ref.read(balanceProvider.future);
  }

  Future<void> _handleTopUpPayment() async {
    final amount = double.tryParse(_amountController.text);
    final purchaseService = BalancePurchaseService(
      ref: widget.ref,
      productIds: const {
        'de.unboundtech.defyxvpn.balance.1',
        'de.unboundtech.defyxvpn.balance.2',
        'de.unboundtech.defyxvpn.balance.3',
        'de.unboundtech.defyxvpn.balance.5',
        'de.unboundtech.defyxvpn.balance.10',
      },
      refreshBalance: refreshBalance,
    );
    await purchaseService.initialize();
    await purchaseService.purchase('de.unboundtech.defyxvpn.balance.$amount');

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle,
                color: const Color(0xFF4CAF7F),
                size: 64.w,
              ),
              SizedBox(height: 16.h),
              Text(
                'Payment Successful',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Your wallet has been topped up',
                style: TextStyle(color: Colors.grey, fontSize: 18.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              AppButton(
                label: 'Continue',
                onPressed: () {
                  Navigator.pop(context);
                  widget.closeTopUpForm();
                  _amountController.clear();
                },
                variant: AppButtonVariant.primary,
                size: AppButtonSize.medium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentButton(String method, String icon) {
    final isSelected = _selectedPaymentMethod == method;

    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 14.w),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : Colors.grey.withValues(alpha: 0.3),
          ),
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              icon,
              width: 24.w,
              height: 24.w,
              colorFilter: ColorFilter.mode(
                isSelected ? const Color(0xFF2563EB) : Colors.black,
                BlendMode.srcIn,
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              method,
              style: TextStyle(
                color: isSelected ? const Color(0xFF2563EB) : Colors.black,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [_buildPaymentButton('Apple Pay', AppIcons.applePath)],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Please enter the wallet top-up amount:',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 30.sp,
                  fontWeight: FontWeight.w300,
                ),
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Text(
                    "\$",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 34.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Expanded(
                    child: AppTextField(
                      controller: _amountController,
                      hintText: '100.00',
                      variant: AppTextFieldVariant.standard,
                      size: AppTextFieldSize.large,
                      keyboardType: TextInputType.numberWithOptions(),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 32.h),
              _buildPaymentMethods(),
              SizedBox(height: 24.h),
              AppButton(
                label: 'Pay Now',
                onPressed: _handleTopUpPayment,
                variant: AppButtonVariant.blue,
                size: AppButtonSize.medium,
                round: AppButtonRound.circle,
              ),
              SizedBox(height: 16.h),
              AppButton(
                label: 'Back',
                onPressed: widget.closeTopUpForm,
                variant: AppButtonVariant.tertiary,
                size: AppButtonSize.medium,
                round: AppButtonRound.circle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
