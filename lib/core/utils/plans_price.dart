import 'package:defyx_vpn/common/dtos/plans_dto.dart';

import 'package:flutter_timezone/flutter_timezone.dart';

Future<String> calculateInternationalPrice(PlansResponse plan) async {
  final String currentTimeZone = (await FlutterTimezone.getLocalTimezone())
      .identifier
      .toLowerCase();
  final isLocal = currentTimeZone.contains("tehran");
  if (isLocal) {
    return plan.price.toStringAsFixed(2);
  }
  return (plan.price * plan.international_price_multiplier).toStringAsFixed(2);
}
