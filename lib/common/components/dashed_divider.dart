import 'package:flutter/material.dart';

class DashedDivider extends StatelessWidget {
  final Color color;
  final double thickness;
  final double dashWidth;
  final double dashSpace;

  const DashedDivider({
    super.key,
    required this.color,
    this.thickness = 1,
    this.dashWidth = 7,
    this.dashSpace = 5,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final count = (constraints.maxWidth / (dashWidth + dashSpace)).floor();

        return Row(
          children: List.generate(
            count,
            (_) => Padding(
              padding: EdgeInsets.only(right: dashSpace),
              child: SizedBox(
                width: dashWidth,
                height: thickness,
                child: ColoredBox(color: color),
              ),
            ),
          ),
        );
      },
    );
  }
}
