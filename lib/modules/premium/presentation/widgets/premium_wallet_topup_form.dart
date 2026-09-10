import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/core/purchase/purchase_service.dart';
import 'package:defyx_vpn/modules/premium/providers/premium_wallet_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
  final List<double> _amountOptions = [1, 2, 3, 5, 10];
  double? _selectedAmount;
  bool _isProcessing = false;

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> refreshBalance() async {
    widget.ref.invalidate(balanceProvider);
    await widget.ref.read(balanceProvider.future);
  }

  Future<void> _handleTopUpPayment() async {
    if (_selectedAmount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select an amount')));
      return;
    }
    setState(() => _isProcessing = true);

    final amount = _selectedAmount;
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
                  setState(() => _selectedAmount = null);
                },
                variant: AppButtonVariant.primary,
                size: AppButtonSize.medium,
              ),
            ],
          ),
        ),
      ),
    );
    setState(() => _isProcessing = false);
  }

  Widget _buildAmountPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: _amountOptions.map((amount) {
            final isSelected = _selectedAmount == amount;
            return GestureDetector(
              onTap: () => setState(() => _selectedAmount = amount),
              child: Container(
                width: 100.w,
                height: 80.h,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF2563EB)
                        : Colors.grey.withValues(alpha: 0.3),
                    width: isSelected ? 2 : 1,
                  ),
                  color: isSelected
                      ? const Color(0xFF2563EB).withValues(alpha: 0.1)
                      : Colors.white,
                ),
                child: Center(
                  child: Text(
                    '\$${amount.toInt()}',
                    style: TextStyle(
                      color: isSelected
                          ? const Color(0xFF2563EB)
                          : Colors.black,
                      fontSize: 28.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
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
                'Please select the wallet top-up amount:',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 30.sp,
                  fontWeight: FontWeight.w300,
                ),
              ),
              SizedBox(height: 24.h),
              _buildAmountPicker(),
              SizedBox(height: 24.h),
              AppButton(
                label: 'Pay Now',
                onPressed: _handleTopUpPayment,
                variant: AppButtonVariant.blue,
                size: AppButtonSize.medium,
                round: AppButtonRound.circle,
                isLoading: _isProcessing,
              ),
              SizedBox(height: 16.h),
              AppButton(
                label: 'Back',
                onPressed: widget.closeTopUpForm,
                variant: AppButtonVariant.tertiary,
                size: AppButtonSize.medium,
                round: AppButtonRound.circle,
                isLoading: _isProcessing,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
