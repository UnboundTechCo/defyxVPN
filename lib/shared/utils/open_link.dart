import 'package:defyx_vpn/app/router/app_router.dart';
import 'package:defyx_vpn/shared/layout/navbar/widgets/custom_webview_screen.dart';
import 'package:defyx_vpn/shared/tv/tv_support.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [url] in an external app (browser, Telegram, …).
///
/// Android TV devices often have no browser, so the launch fails there. On TV
/// the link then opens in the in-app web view instead of doing nothing.
Future<void> openLink(String url, {String? title}) async {
  final uri = Uri.parse(url);
  var launched = false;
  try {
    launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (e) {
    debugPrint('Error launching URL: $e');
  }
  if (launched || !TvSupport.isTv) return;

  final navigator = rootNavigatorKey.currentState;
  if (navigator == null) return;
  await navigator.push(
    MaterialPageRoute<void>(
      builder: (_) => CustomWebViewScreen(url: url, title: title ?? uri.host),
    ),
  );
}
