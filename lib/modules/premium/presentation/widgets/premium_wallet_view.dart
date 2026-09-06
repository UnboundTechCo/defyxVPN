import 'package:defyx_vpn/common/components/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class PremiumWalletView extends StatefulWidget {
  const PremiumWalletView({
    super.key,
    required this.balance,
    required this.showTopUpForm,
    required this.isLoading,
  });

  final double balance;
  final VoidCallback showTopUpForm;
  final bool isLoading;

  @override
  State<PremiumWalletView> createState() => _PremiumWalletViewState();
}

class _PremiumWalletViewState extends State<PremiumWalletView> {
  @override
  Widget build(BuildContext context) {
    final symbol = '\$';

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
                        'BALANCE',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 12.h),
                      widget.isLoading
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
                            label: 'Top up',
                            onPressed: () {
                              widget.showTopUpForm();
                            },
                            variant: AppButtonVariant.blue,
                            width: 150.w,
                            round: AppButtonRound.circle,
                            isLoading: widget.isLoading,
                          ),
                          SizedBox(width: 12.w),
                          GestureDetector(
                            onTap: () {
                              // Refresh wallet balance here.
                            },
                            child: Container(
                              width: 40.w,
                              height: 40.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.6),
                              ),
                              child: Icon(
                                Icons.refresh,
                                color: Colors.white,
                                size: 20.w,
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
