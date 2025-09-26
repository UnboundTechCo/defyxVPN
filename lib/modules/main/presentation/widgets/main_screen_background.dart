import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:defyx_vpn/core/theme/app_colors.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';

class MainScreenBackground extends StatelessWidget {
  final Widget child;
  final ConnectionStatus connectionStatus;

  const MainScreenBackground({
    super.key,
    required this.child,
    required this.connectionStatus,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      appBar: connectionStatus == ConnectionStatus.connected
          ? AppBar(
              backgroundColor: Colors.black,
              elevation: 0,
              systemOverlayStyle: SystemUiOverlayStyle.light,
              toolbarHeight: 0,
            )
          : null,
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: _getCurrentGradient(connectionStatus),
        ),
        child: child,
      ),
    );
  }

  LinearGradient _getCurrentGradient(ConnectionStatus connectionState) {
    switch (connectionState) {
      case ConnectionStatus.disconnected:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.topGradientReadyToConnect,
            AppColors.middleGradient,
            AppColors.bottomGradient,
          ],
          stops: const [0.2, 0.7, 1.0],
        );
      case ConnectionStatus.connected:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.topGradient, AppColors.bottomGradientConnected],
          stops: const [0.0, 1.0],
        );
      case ConnectionStatus.noInternet:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.topGradient,
            AppColors.middleGradientNoInternet,
            AppColors.bottomGradientNoInternet,
          ],
          stops: const [0.2, 0.7, 1.0],
        );
      case ConnectionStatus.error:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.topGradient,
            AppColors.middleGradientFailedToConnect,
            AppColors.bottomGradientFailedToConnect,
          ],
          stops: const [0.2, 0.7, 1.0],
        );
      case ConnectionStatus.loading:
      case ConnectionStatus.analyzing:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.topGradientConnecting,
            AppColors.middleGradientConnecting,
            AppColors.bottomGradientConnecting,
          ],
          stops: const [0.2, 0.7, 1.0],
        );
      default:
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.topGradientReadyToConnect,
            AppColors.middleGradient,
            AppColors.bottomGradient,
          ],
          stops: const [0.2, 0.7, 1.0],
        );
    }
  }
}
