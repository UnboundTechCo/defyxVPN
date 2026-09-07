import 'package:flutter_riverpod/flutter_riverpod.dart';

enum PremiumTab { account, plans, wallet, support }

final premiumTabProvider = StateProvider<PremiumTab>(
  (ref) => PremiumTab.account,
);
