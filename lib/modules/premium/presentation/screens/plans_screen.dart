import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/common/dtos/plans_dto.dart';
import 'package:defyx_vpn/modules/premium/presentation/widgets/premium_plans_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key});

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  String? _selectedPaymentMethod;

  @override
  Widget build(BuildContext context) {
    // final selectedPlan = ref.watch(selectedPlanProvider);

    return PremiumPlanSelect();
  }

  Widget _buildPlanDetails(PlansResponse? plan) {
    if (plan == null) return const SizedBox();

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12.r),
        color: Colors.grey.withValues(alpha: 0.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'What You\'ll Get',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),
          // ...plan.des.map((feature) {
          //   return Padding(
          //     padding: EdgeInsets.only(bottom: 12.h),
          //     child: Row(
          //       children: [
          //         Icon(
          //           Icons.check_circle,
          //           color: const Color(0xFF4CAF7F),
          //           size: 20.w,
          //         ),
          //         SizedBox(width: 12.w),
          //         Expanded(
          //           child: Text(
          //             feature,
          //             style: TextStyle(
          //               color: Colors.grey,
          //               fontSize: 13.sp,
          //               height: 1.4,
          //             ),
          //           ),
          //         ),
          //       ],
          //     ),
          //   );
          // }).toList(),
          if (plan.price > 0)
            Padding(
              padding: EdgeInsets.only(top: 16.h),
              child: Divider(color: Colors.grey.withValues(alpha: 0.3)),
            ),
          if (plan.price > 0)
            Padding(
              padding: EdgeInsets.only(top: 16.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '\$${plan.price.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: const Color(0xFF4CAF7F),
                      fontSize: 28.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    '/ ${plan.duration_days ~/ 30} MONTHS',
                    style: TextStyle(color: Colors.grey, fontSize: 12.sp),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Method',
          style: TextStyle(
            color: Colors.white,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(child: _buildPaymentButton('PayPal', '💳')),
            SizedBox(width: 8.w),
            Expanded(child: _buildPaymentButton('Master Card', '💳')),
            SizedBox(width: 8.w),
            Expanded(child: _buildPaymentButton('Apple Pay', '🍎')),
          ],
        ),
      ],
    );
  }

  Widget _buildPaymentButton(String method, String icon) {
    final isSelected = _selectedPaymentMethod == method;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = method),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2563EB)
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? const Color(0xFF2563EB).withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Column(
          children: [
            Text(icon, style: TextStyle(fontSize: 20.sp)),
            SizedBox(height: 4.h),
            Text(
              method,
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePayNow() async {
    if (_selectedPaymentMethod == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a payment method'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Show success dialog
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey.withValues(alpha: 0.1),
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
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Your subscription has been activated',
                style: TextStyle(color: Colors.grey, fontSize: 13.sp),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),
              AppButton(
                label: 'Continue',
                onPressed: () => Navigator.pop(context),
                variant: AppButtonVariant.secondary,
                round: AppButtonRound.circle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
