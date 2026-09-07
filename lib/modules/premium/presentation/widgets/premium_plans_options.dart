import 'package:defyx_vpn/common/components/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:defyx_vpn/modules/premium/providers/selected_plan_provider.dart';

class PremiumPlanSelect extends ConsumerWidget {
  final VoidCallback navigateToDetails;

  const PremiumPlanSelect({super.key, required this.navigateToDetails});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedPlan = ref.watch(selectedPlanProvider);

    final plans = ref.watch(plansProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
      child: Column(
        children: [
          Text(
            'Select the plan duration you\'d like to purchase:',
            style: TextStyle(
              color: Colors.black,
              fontSize: 30.sp,
              fontWeight: FontWeight.w300,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 20.h),
          plans.when(
            data: (data) {
              return Column(
                children: data.map((plan) {
                  final isSelectedPlan = selectedPlan == plan;

                  return Padding(
                    padding: EdgeInsets.only(bottom: 12.h),
                    child: GestureDetector(
                      onTap: () {
                        ref.read(selectedPlanProvider.notifier).state = plan;
                      },
                      child: Container(
                        padding: EdgeInsets.all(16.w),
                        decoration: const BoxDecoration(
                          color: Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 24.w,
                              height: 24.h,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelectedPlan
                                      ? const Color(0xFF2563EB)
                                      : Colors.grey,
                                  width: 2,
                                ),
                                color: isSelectedPlan
                                    ? const Color(0xFF2563EB)
                                    : Colors.transparent,
                              ),
                              child: isSelectedPlan
                                  ? Icon(
                                      Icons.check,
                                      color: Colors.white,
                                      size: 16.w,
                                    )
                                  : null,
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                plan.name,
                                style: TextStyle(
                                  color: isSelectedPlan
                                      ? const Color(0xFF1849D6)
                                      : Colors.black,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              '\$${plan.price.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: isSelectedPlan
                                    ? const Color(0xFF21AD86)
                                    : Colors.grey,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              );
            },
            loading: () {
              return const Center(child: CircularProgressIndicator());
            },
            error: (error, stackTrace) => Center(child: Text('Error: $error')),
          ),

          SizedBox(height: 32.h),
          AppButton(
            label: 'Choose',
            onPressed: navigateToDetails,
            variant: AppButtonVariant.outline,
            round: AppButtonRound.circle,
            size: AppButtonSize.medium,
            isLoading: plans.when(
              data: (data) => false,
              loading: () => true,
              error: (error, stackTrace) => false,
            ),
          ),
          SizedBox(height: 20.h),
        ],
      ),
    );
  }
}
