import 'dart:io';
import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/shared/tv/tv_support.dart';
import 'package:defyx_vpn/shared/utils/tv_keyboard_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';

/// The company's own sites. defyxvpn.com redirects its privacy policy and
/// terms to unboundtech.de, so both are always allowed.
const _firstPartyHosts = {'defyxvpn.com', 'unboundtech.de'};

/// The hosts a web view started at [url] may show: its own host and the
/// company's sites.
Set<String> webViewDefaultHosts(String url) => {
  ..._firstPartyHosts,
  if ((Uri.tryParse(url)?.host ?? '').isNotEmpty)
    Uri.parse(url).host.toLowerCase(),
};

/// Whether the in-app web view may show [uri]: https on one of [hosts] or
/// their subdomains. [hosts] are lower case.
bool webViewAllows(Uri uri, Set<String> hosts) {
  if (uri.scheme != 'https') return false;
  final host = uri.host.toLowerCase();
  return hosts.any((allowed) => host == allowed || host.endsWith('.$allowed'));
}

/// Shows one of the app's own web pages inside the app.
///
/// The view only stays on https pages of [allowedHosts] (and their
/// subdomains), which default to the host of [url] and the company's sites. A link anywhere else opens
/// in the browser instead, and schemes such as intent:, file: or javascript:
/// are refused. Pages run JavaScript but get no bridge to the app, no file or
/// content access, no mixed content and no third-party cookies.
class CustomWebViewScreen extends StatefulWidget {
  final String url;
  final String title;
  final Set<String>? allowedHosts;

  const CustomWebViewScreen({
    super.key,
    required this.url,
    required this.title,
    this.allowedHosts,
  });

  @override
  State<CustomWebViewScreen> createState() => _CustomWebViewScreenState();
}

class _CustomWebViewScreenState extends State<CustomWebViewScreen> {
  WebViewController? _controller;
  bool _isLoading = true;

  // Links with these schemes may leave the app, to the browser or mail app.
  static const _externalSchemes = {'https', 'http', 'mailto', 'tel'};

  late final Set<String> _allowedHosts = {
    for (final host in widget.allowedHosts ?? webViewDefaultHosts(widget.url))
      if (host.isNotEmpty) host.toLowerCase(),
  };

  bool _isAllowed(Uri uri) => webViewAllows(uri, _allowedHosts);

  NavigationDecision _decide(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (_isAllowed(uri)) return NavigationDecision.navigate;
    // Frames inside an allowed page may load other https sites, such as a
    // payment form; they cannot take over the screen.
    if (!request.isMainFrame && uri.scheme == 'https') {
      return NavigationDecision.navigate;
    }
    if (request.isMainFrame && _externalSchemes.contains(uri.scheme)) {
      _openOutside(uri);
    } else {
      debugPrint('Web view refused ${uri.scheme}: navigation');
    }
    return NavigationDecision.prevent;
  }

  Future<void> _openOutside(Uri uri) async {
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Could not open $uri outside the app: $e');
    }
  }

  @override
  void initState() {
    super.initState();

    if (!(Platform.isAndroid || Platform.isIOS)) {
      _openInBrowser();
      return;
    }

    _initializeWebView();
  }

  Future<void> _initializeWebView() async {
    // Clear all cookies before loading to prevent tracking
    await WebViewCookieManager().clearCookies();

    // Use platform-specific params for native cookie blocking
    late final PlatformWebViewControllerCreationParams params;

    if (Platform.isIOS) {
      // iOS: Use WKWebView which blocks 3rd-party cookies by default (iOS 14+)
      params = WebKitWebViewControllerCreationParams(
        allowsInlineMediaPlayback: true,
        mediaTypesRequiringUserAction: const {},
      );
    } else if (Platform.isAndroid) {
      // Android: Use native WebView with built-in privacy features
      params = AndroidWebViewControllerCreationParams();
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    final controller = WebViewController.fromPlatformCreationParams(params)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final decision = _decide(request);
            if (decision == NavigationDecision.navigate) {
              // Clear cookies before every navigation to prevent tracking persistence
              WebViewCookieManager().clearCookies();
            }
            return decision;
          },
          onPageStarted: (String url) async {
            // Clear cookies when page starts loading as an additional safeguard
            await WebViewCookieManager().clearCookies();
            if (mounted) {
              setState(() {
                _isLoading = true;
              });
            }
          },
          onPageFinished: (String url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..setUserAgent(
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 DNT/1',
      );

    if (controller.platform is AndroidWebViewController) {
      final android = controller.platform as AndroidWebViewController;
      await android.setAllowFileAccess(false);
      await android.setAllowContentAccess(false);
      await android.setGeolocationEnabled(false);
      await android.setMixedContentMode(MixedContentMode.neverAllow);
      final cookies = WebViewCookieManager().platform;
      if (cookies is AndroidWebViewCookieManager) {
        await cookies.setAcceptThirdPartyCookies(android, false);
      }
    }

    // Only the page's own host is ever loaded directly.
    final start = Uri.tryParse(widget.url);
    if (start == null || !_isAllowed(start)) {
      debugPrint('Web view refused to open ${widget.url}');
      if (start != null && _externalSchemes.contains(start.scheme)) {
        await _openOutside(start);
      }
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await controller.loadRequest(start);

    _controller = controller;

    if (mounted) {
      setState(() {});
    }

    debugPrint(
      'WebView initialized: Native privacy + continuous cookie blocking',
    );
  }

  Future<void> _openInBrowser() async {
    final uri = Uri.parse(widget.url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          debugPrint('Could not launch URL: ${widget.url}');
        }
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error launching URL: $e');
      }
    } finally {
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // For desktop platforms, show loading while opening browser
    if (!(Platform.isAndroid || Platform.isIOS)) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primary),
              SizedBox(height: 16.h),
              Text(
                'Opening in browser...',
                style: TextStyle(fontSize: 16.sp, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _handleScrollKeys,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          leading: IconButton(
            autofocus: TvSupport.isTv,
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            widget.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: 20.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: Stack(
          children: [
            if (_controller != null)
              // On TV the web view is not a D-pad focus stop (it would trap
              // focus); Up/Down scroll it instead, see _handleScrollKeys.
              ExcludeFocus(
                excluding: TvSupport.isTv,
                child: WebViewWidget(controller: _controller!),
              )
            else
              const SizedBox.shrink(),
            if (_isLoading)
              Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
          ],
        ),
      ),
    );
  }

  /// Scrolls the page with Up/Down while D-pad focus stays on Close.
  KeyEventResult _handleScrollKeys(FocusNode node, KeyEvent event) {
    final controller = _controller;
    if (controller == null || event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final direction = TvKeyboardHelper.directionOf(event);
    if (direction != TraversalDirection.up &&
        direction != TraversalDirection.down) {
      return KeyEventResult.ignored;
    }
    final sign = direction == TraversalDirection.down ? 1 : -1;
    controller.runJavaScript(
      'window.scrollBy({top: $sign * window.innerHeight * 0.6, '
      'behavior: "smooth"});',
    );
    return KeyEventResult.handled;
  }
}
