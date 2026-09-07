import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/common/components/dashed_divider.dart';
import 'package:defyx_vpn/common/dtos/plans_dto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PremiumPlanDetails extends StatefulWidget {
  final PlansResponse plan;

  const PremiumPlanDetails({super.key, required this.plan});

  @override
  State<PremiumPlanDetails> createState() => _PremiumPlanDetailsState();
}

class _PremiumPlanDetailsState extends State<PremiumPlanDetails> {
  String? _selectedPaymentMethod;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                plan.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 24.h),

              _buildPlanDetails(plan),

              SizedBox(height: 24.h),

              AppButton(
                label: 'Pay Now',
                onPressed: _handlePayNow,
                variant: AppButtonVariant.blue,
                round: AppButtonRound.circle,
                size: AppButtonSize.medium,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlanDetails(PlansResponse plan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'What You\'ll Get',
          style: TextStyle(
            color: const Color(0xFFA9A9AA),
            fontSize: 30.sp,
            fontWeight: FontWeight.w300,
          ),
        ),
        SizedBox(height: 16.h),
        Text(
          plan.description,
          style: TextStyle(color: const Color(0xFF575757), fontSize: 18.sp),
        ),
        SizedBox(height: 20.h),
        DashedDivider(
          color: const Color(0xFFA9A9AA),
          thickness: 1,
          dashWidth: 6,
          dashSpace: 4,
        ),
        SizedBox(height: 20.h),
        Row(
          // mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\$${plan.price.toStringAsFixed(2)}',
              style: TextStyle(
                color: const Color(0xFF4CAF7F),
                fontSize: 34.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(width: 4.w),
            Text(
              '/ ',
              style: TextStyle(color: const Color(0xFF515151), fontSize: 20.sp),
            ),
            Text(
              '${(plan.duration_days / 30).round()}',
              style: TextStyle(
                color: const Color(0xFF515151),
                fontSize: 20.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              ' Months',
              style: TextStyle(color: const Color(0xFF515151), fontSize: 20.sp),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _handlePayNow() async {
    // Call your payment API here, then show success.
    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
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
                onPressed: () {},
                variant: AppButtonVariant.primary,
                round: AppButtonRound.circle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
