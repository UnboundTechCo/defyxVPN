import 'package:defyx_vpn/core/theme/app_icons.dart';
import 'package:defyx_vpn/shared/services/animation_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:lottie/lottie.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart'
    as vpn;
import 'package:path_drawing/path_drawing.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';

class ConnectionButton extends StatefulWidget {
  final VoidCallback onTap;

  const ConnectionButton({super.key, required this.onTap});

  @override
  State<ConnectionButton> createState() => _ConnectionButtonState();
}

class _ConnectionButtonState extends State<ConnectionButton>
    with TickerProviderStateMixin {
  final AnimationService _animationService = AnimationService();
  late AnimationController _animationController;
  late AnimationController _shieldLoadingController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _shieldRotationAnimation;

  Timer? _timer;
  int _seconds = 0;
  String _formattedTime = "00:00:00";

  static const String _connectionStartTimeKey = 'connection_start_time';
  static const String _lastSecondsCountKey = 'last_seconds_count';
  static const String _isConnectedKey = 'is_connected';

  // Responsive dimensions
  late double _buttonSize;
  late double _iconSize;
  late double _animationSize;
  late double _pulseMaxSize;

  @override
  void initState() {
    super.initState();
    _initializeDimensions();
    _setupAnimations();
    _loadConnectionTime();
  }

  void _initializeDimensions() {
    // Base dimensions that scale properly with screen size
    _buttonSize = 120.w;
    _iconSize = 55.w;
    _animationSize = 105.w; // Extra large to completely fill shield
    _pulseMaxSize = 350.w;
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      vsync: this,
      duration: _animationService.adjustDuration(const Duration(milliseconds: 2000)),
    );
    _animationService.conditionalRepeat(_animationController, reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _shieldLoadingController = AnimationController(
      vsync: this,
      duration: _animationService.adjustDuration(const Duration(milliseconds: 1500)),
    );

    _shieldRotationAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shieldLoadingController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _animationController.dispose();
    _shieldLoadingController.dispose();
    super.dispose();
  }

  // Load connection time from shared preferences
  Future<void> _loadConnectionTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isConnected = prefs.getBool(_isConnectedKey) ?? false;

      if (isConnected) {
        if (prefs.containsKey(_lastSecondsCountKey)) {
          _seconds = prefs.getInt(_lastSecondsCountKey) ?? 0;
        } else if (prefs.containsKey(_connectionStartTimeKey)) {
          final startTimeMs = prefs.getInt(_connectionStartTimeKey) ?? 0;
          if (startTimeMs > 0) {
            final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
            _seconds = ((currentTimeMs - startTimeMs) / 1000).floor();
          }
        }
        _updateFormattedTime();
      }
    } catch (e) {
      debugPrint('Error loading connection time: $e');
    }
  }

  Future<void> _saveConnectionTime({bool isConnected = true}) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (isConnected) {
        if (!prefs.containsKey(_connectionStartTimeKey)) {
          final currentTimeMs = DateTime.now().millisecondsSinceEpoch;
          final startTimeMs = currentTimeMs - (_seconds * 1000);
          await prefs.setInt(_connectionStartTimeKey, startTimeMs);
        }
        await prefs.setInt(_lastSecondsCountKey, _seconds);
        await prefs.setBool(_isConnectedKey, true);
      } else {
        await prefs.remove(_connectionStartTimeKey);
        await prefs.setBool(_isConnectedKey, false);
      }
    } catch (e) {
      debugPrint('Error saving connection time: $e');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _updateFormattedTime();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      _seconds++;
      _updateFormattedTime();

      // CRITICAL FIX: Only setState if actually mounted and timer display is needed
      if (mounted) {
        setState(() {});
      }

      // Save less frequently to reduce I/O operations
      if (_seconds % 10 == 0) {
        _saveConnectionTime();
      }
    });

    _saveConnectionTime();
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
    _saveConnectionTime(isConnected: false);
  }

  Future<void> _resetTimer() async {
    _timer?.cancel();
    _timer = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_connectionStartTimeKey);
      await prefs.remove(_lastSecondsCountKey);
      await prefs.setBool(_isConnectedKey, false);

      setState(() {
        _seconds = 0;
        _updateFormattedTime();
      });
    } catch (e) {
      debugPrint('Error resetting timer: $e');
    }
  }

  void _updateFormattedTime() {
    final hours = _seconds ~/ 3600;
    final minutes = (_seconds % 3600) ~/ 60;
    final seconds = _seconds % 60;
    _formattedTime = "${hours.toString().padLeft(2, '0')}:"
        "${minutes.toString().padLeft(2, '0')}:"
        "${seconds.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, child) {
        final connectionState = ref.watch(vpn.connectionStateProvider);

        // Handle timer based on connection status
        _handleTimerState(connectionState.status);

        return Stack(
          alignment: Alignment.center,
          children: [
            // Pulse animation rings
            _buildPulseRings(),

            // Main connection button
            _buildMainButton(connectionState),

            // Timer display
            _buildTimerDisplay(connectionState.status),
          ],
        );
      },
    );
  }

  void _handleTimerState(vpn.ConnectionStatus status) {
    switch (status) {
      case vpn.ConnectionStatus.connected:
        if (_timer == null) _startTimer();
        _shieldLoadingController.stop();
        break;
      case vpn.ConnectionStatus.disconnected:
        if (_seconds > 0) _resetTimer();
        _shieldLoadingController.stop();
        break;
      case vpn.ConnectionStatus.loading:
        _shieldLoadingController.stop();
        break;
      case vpn.ConnectionStatus.analyzing:
        _animationService.conditionalRepeat(_shieldLoadingController);
        break;
      case vpn.ConnectionStatus.disconnecting:
        _animationService.conditionalRepeat(_shieldLoadingController);
        break;
      default:
        if (_timer != null) _stopTimer();
        _shieldLoadingController.stop();
    }
  }

  Widget _buildPulseRings() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Extra outer ring
            _buildPulseRing(
              opacity: (0.3 * (1 - _pulseAnimation.value)).clamp(0.02, 0.1),
              scale: 1.1 + (_pulseAnimation.value * 0.2),
            ),

            // Outer ring
            _buildPulseRing(
              opacity: (0.35 * (1 - _pulseAnimation.value)).clamp(0.05, 0.15),
              scale: 0.9 + (_pulseAnimation.value * 0.2),
            ),

            // Middle ring
            _buildPulseRing(
              opacity: (0.32 * (1 - _pulseAnimation.value * 0.8)).clamp(
                0.08,
                0.25,
              ),
              scale: 0.7 + (_pulseAnimation.value * 0.2),
            ),
            // Inner ring
            _buildPulseRing(
              opacity: (0.4 * (1 - _pulseAnimation.value * 0.6)).clamp(
                0.15,
                0.3,
              ),
              scale: 0.5 + (_pulseAnimation.value * 0.2),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPulseRing({required double opacity, required double scale}) {
    return Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: scale,
        child: AppIcons.shieldAnime(
          width: _pulseMaxSize,
          height: _pulseMaxSize,
        ),
      ),
    );
  }

  Widget _buildMainButton(vpn.ConnectionState connectionState) {
    return SizedBox(
      width: _buttonSize,
      height: _buttonSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shield background/border
          AppIcons.shieldAnime(width: _buttonSize, height: _buttonSize),

          // Shield loading animation overlay (only for analyzing state)
          if (connectionState.status == vpn.ConnectionStatus.analyzing ||
              connectionState.status == vpn.ConnectionStatus.disconnecting)
            AnimatedBuilder(
              animation: _shieldRotationAnimation,
              builder: (context, child) {
                return CustomPaint(
                  size: Size(_buttonSize, _buttonSize),
                  painter: ShieldLoadingPainter(
                    progress: _shieldRotationAnimation.value,
                    size: _buttonSize,
                  ),
                );
              },
            ),

          // All interactive content clipped to shield shape
          // Perfectly aligned with shield edges
          Positioned.fill(
            child: ClipPath(
              clipper: SvgShieldClipper(size: _buttonSize),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Subtle gradient background inside shield
                  Container(
                    width: _buttonSize,
                    height: _buttonSize,
                    decoration: BoxDecoration(color: Colors.transparent),
                  ),

                  // Interactive material with InkWell
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: widget.onTap,
                      splashColor: Colors.white.withValues(alpha: 0.2),
                      highlightColor: Colors.white.withValues(alpha: 0.1),
                      child: Container(
                        width: _buttonSize,
                        height: _buttonSize,
                        alignment: Alignment.center,
                        child: _buildButtonContent(connectionState.status),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonContent(vpn.ConnectionStatus status) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Base icon - now properly masked within shield
        _buildStatusIcon(status),

        // Loading animation overlay - now properly masked within shield
        if (status == vpn.ConnectionStatus.loading ||
            status == vpn.ConnectionStatus.analyzing)
          _buildLoadingAnimation(),
      ],
    );
  }

  Widget _buildStatusIcon(vpn.ConnectionStatus status) {
    Widget icon;
    switch (status) {
      case vpn.ConnectionStatus.connected:
        icon = AppIcons.defyxCheck(width: _iconSize, height: _iconSize);
        break;
      case vpn.ConnectionStatus.noInternet:
        icon = AppIcons.defyxError(width: _iconSize, height: _iconSize);
        break;
      case vpn.ConnectionStatus.error:
        icon = AppIcons.defyxReload(width: _iconSize, height: _iconSize);
        break;
      case vpn.ConnectionStatus.loading:
      case vpn.ConnectionStatus.analyzing:
        icon = AppIcons.defyxLoading(width: _iconSize, height: _iconSize);
        break;
      case vpn.ConnectionStatus.disconnected:
      default:
        icon = AppIcons.defyxStandby(width: _iconSize, height: _iconSize);
    }

    return icon;
  }

  Widget _buildLoadingAnimation() {
    return Lottie.asset(
      'assets/lottie/scan.json',
      width: _animationSize,
      height: _animationSize,
      fit: BoxFit.cover,
      // Ensure animation stays within the shield bounds
      alignment: Alignment.center,
    );
  }

  Widget _buildTimerDisplay(vpn.ConnectionStatus status) {
    if (status != vpn.ConnectionStatus.connected) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: 70.h,
      child: Text(
        _formattedTime,
        style: TextStyle(
          color: Colors.white,
          fontSize: 16.sp,
          fontFamily: 'Lato',
          fontWeight: FontWeight.w500,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

class SvgShieldClipper extends CustomClipper<Path> {
  final double size;

  const SvgShieldClipper({required this.size});

  @override
  Path getClip(Size clipSize) {
    const String svgPathData =
        "M51.39 1.16517L100.313 21.8855C100.72 22.0581 100.966 22.4781 100.917 22.918L94.1288 83.2901C93.9546 84.8395 93.1841 86.2602 91.9806 87.2513L51.6357 120.476C51.2665 120.781 50.7336 120.781 50.3643 120.476L10.0194 87.2513C8.8159 86.2602 8.04544 84.8395 7.87124 83.2901L1.08337 22.918C1.03392 22.4781 1.27953 22.0581 1.68712 21.8855L50.61 1.16517C50.8593 1.0596 51.1407 1.0596 51.39 1.16517Z";

    final path = parseSvgPathData(svgPathData);

    // Get the exact bounds of the SVG path
    final bounds = path.getBounds();

    // Calculate the scale to fit exactly within clipSize (no reduction)
    final scaleX = clipSize.width / bounds.width;
    final scaleY = clipSize.height / bounds.height;

    // Use uniform scaling to maintain the shield shape
    final scale = math.min(scaleX, scaleY);

    // Center the scaled path
    final scaledWidth = bounds.width * scale;
    final scaledHeight = bounds.height * scale;
    final offsetX = (clipSize.width - scaledWidth) / 2;
    final offsetY = (clipSize.height - scaledHeight) / 2;

    // Transform the path
    final matrix4 = Matrix4.identity()
      ..translate(
        offsetX - (bounds.left * scale),
        offsetY - (bounds.top * scale),
      )
      ..scale(scale, scale);

    return path.transform(matrix4.storage);
  }

  @override
  bool shouldReclip(covariant SvgShieldClipper oldClipper) {
    return oldClipper.size != size;
  }
}

class ShieldLoadingPainter extends CustomPainter {
  final double progress;
  final double size;

  ShieldLoadingPainter({required this.progress, required this.size});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    const String svgPathData =
        "M51.39 1.16517L100.313 21.8855C100.72 22.0581 100.966 22.4781 100.917 22.918L94.1288 83.2901C93.9546 84.8395 93.1841 86.2602 91.9806 87.2513L51.6357 120.476C51.2665 120.781 50.7336 120.781 50.3643 120.476L10.0194 87.2513C8.8159 86.2602 8.04544 84.8395 7.87124 83.2901L1.08337 22.918C1.03392 22.4781 1.27953 22.0581 1.68712 21.8855L50.61 1.16517C50.8593 1.0596 51.1407 1.0596 51.39 1.16517Z";

    final path = parseSvgPathData(svgPathData);
    final bounds = path.getBounds();

    // Scale and center the path - exactly match the ClipPath calculation
    final scaleX = canvasSize.width / bounds.width;
    final scaleY = canvasSize.height / bounds.height;
    final scale = math.min(scaleX, scaleY);

    final scaledWidth = bounds.width * scale;
    final scaledHeight = bounds.height * scale;
    final offsetX = (canvasSize.width - scaledWidth) / 2;
    final offsetY = (canvasSize.height - scaledHeight) / 2;

    final matrix4 = Matrix4.identity()
      ..translate(
        offsetX - (bounds.left * scale),
        offsetY - (bounds.top * scale),
      )
      ..scale(scale, scale);

    final transformedPath = path.transform(matrix4.storage);

    // Create gradient paint for loading effect
    final sweepGradient = SweepGradient(
      center: Alignment.center,
      startAngle: 0,
      endAngle: 2 * math.pi,
      colors: [
        Colors.transparent,
        Colors.transparent,
        Colors.white.withValues(alpha: 0.8),
        Colors.white,
        Colors.white.withValues(alpha: 0.8),
        Colors.transparent,
        Colors.transparent,
      ],
      stops: const [0.0, 0.3, 0.45, 0.5, 0.55, 0.7, 1.0],
      transform: GradientRotation(progress * 2 * math.pi),
    );

    final paint = Paint()
      ..shader = sweepGradient.createShader(
        Rect.fromLTWH(0, 0, canvasSize.width, canvasSize.height),
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawPath(transformedPath, paint);
  }

  @override
  bool shouldRepaint(covariant ShieldLoadingPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
