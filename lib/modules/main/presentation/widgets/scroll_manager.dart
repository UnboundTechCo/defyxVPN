import 'package:flutter/material.dart';
import 'package:defyx_vpn/shared/providers/connection_state_provider.dart';

class ScrollManager {
  final ScrollController scrollController;

  ScrollManager(this.scrollController);

  void handleConnectionStateChange(ConnectionStatus status) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (status == ConnectionStatus.connected) {
        scrollToBottomWithRetry();
      } else {
        scrollToTopWithRetry();
      }
    });
  }

  void handleAdsStateChange(bool showCountdown) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!showCountdown) {
        scrollToTopWithRetry();
      }
    });
  }

  void scrollToBottomWithRetry({int attempts = 3}) {
    if (attempts <= 0) return;
    if (scrollController.hasClients) {
      scrollController.animateTo(
        scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
      );
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        scrollToBottomWithRetry(attempts: attempts - 1);
      });
    }
  }

  void scrollToTopWithRetry({int attempts = 3}) {
    if (attempts <= 0) return;
    if (scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
      );
    } else {
      Future.delayed(const Duration(milliseconds: 300), () {
        scrollToTopWithRetry(attempts: attempts - 1);
      });
    }
  }

  void checkInitialConnectionState(ConnectionStatus status) {
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (status == ConnectionStatus.connected) {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
          );
        }
      } else {
        if (scrollController.hasClients) {
          scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }
}
