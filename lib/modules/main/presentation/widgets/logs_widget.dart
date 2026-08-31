import 'package:defyx_vpn/common/components/button.dart';
import 'package:defyx_vpn/core/theme/app_theme.dart';
import 'package:defyx_vpn/modules/core/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:async';
import 'package:defyx_vpn/l10n/app_localizations.dart';

// State class for logs
class LogsState {
  final List<String> logs;
  final bool isLoading;

  LogsState({this.logs = const [], this.isLoading = false});

  LogsState copyWith({List<String>? logs, bool? isLoading}) {
    return LogsState(
      logs: logs ?? this.logs,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

// Provider for logs state
class LogsNotifier extends StateNotifier<LogsState> {
  LogsNotifier() : super(LogsState());
  Timer? _refreshTimer;
  bool _isFetching = false; // Track if a fetch operation is in progress
  final Set<String> _existingLogs = {};
  final log = Log(); // Track existing logs to avoid duplicates

  Future<void> fetchLogs() async {
    // Don't start a new fetch if one is already in progress
    if (_isFetching) return;

    _isFetching = true;
    state = state.copyWith(isLoading: true);

    try {
      // Get only new logs from native code

      final String newLogs = log.getLogs();

      if (newLogs.isNotEmpty) {
        // Split new logs by newline
        List<String> newLogEntries = newLogs.split('\n');

        // Filter out empty lines and already shown logs
        List<String> filteredNewLogs =
            newLogEntries.where((log) => log.isNotEmpty && !_existingLogs.contains(log)).toList();

        if (filteredNewLogs.isNotEmpty) {
          // Add new logs to the existing logs set to avoid duplicates
          _existingLogs.addAll(filteredNewLogs);

          // Create the updated log list
          List<String> updatedLogs = [...state.logs, ...filteredNewLogs];

          // Keep only the most recent 100 lines (increased from 50 to show more context)
          if (updatedLogs.length > 200) {
            int excessEntries = updatedLogs.length - 200;
            // Remove excess entries from both the list and the set
            for (int i = 0; i < excessEntries; i++) {
              _existingLogs.remove(updatedLogs[i]);
            }
            updatedLogs = updatedLogs.sublist(excessEntries);
          }

          state = state.copyWith(logs: updatedLogs);
        }
      }
    } catch (e) {
      debugPrint('Error fetching logs: $e');

      // If there was an error, make sure the timer is still running
      // This ensures auto-refresh recovers from errors
      if (_refreshTimer == null || !_refreshTimer!.isActive) {
        startAutoRefresh();
      }
    } finally {
      // Always make sure to reset the flags even if an error occurred
      _isFetching = false;
      state = state.copyWith(isLoading: false);
    }
  }

  void clearLogs() {
    // Clear tracking set and state logs
    _existingLogs.clear();
    state = state.copyWith(logs: []);

    // Clear logs in WarpPlus too and ensure clearUILogs is true since this is explicitly called to clear UI
    Log().clearLogs();
  }

  // Check if the auto-refresh timer is active
  bool isRefreshing() {
    return _refreshTimer != null && _refreshTimer!.isActive;
  }

  void startAutoRefresh() {
    stopAutoRefresh();

    // Use a more frequent timer (500ms) to ensure we catch all logs
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => fetchLogs(),
    );
  }

  void stopAutoRefresh() {
    if (_refreshTimer != null) {
      _refreshTimer!.cancel();
      _refreshTimer = null;
    }
  }

  @override
  void dispose() {
    stopAutoRefresh();
    super.dispose();
  }
}

// Provider for the logs state
final logsProvider = StateNotifierProvider<LogsNotifier, LogsState>((ref) {
  return LogsNotifier();
});

// A utility widget that can be used to add shake-to-show-logs functionality to any screen
class ShakeLogDetector extends ConsumerStatefulWidget {
  final Widget child;

  const ShakeLogDetector({super.key, required this.child});

  @override
  ConsumerState<ShakeLogDetector> createState() => _ShakeLogDetectorState();
}

class _ShakeLogDetectorState extends ConsumerState<ShakeLogDetector> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class LogPopupContent extends ConsumerStatefulWidget {
  const LogPopupContent({super.key});

  @override
  ConsumerState<LogPopupContent> createState() => _LogPopupContentState();
}

class _LogPopupContentState extends ConsumerState<LogPopupContent> {
  final ScrollController scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final logsNotifier = ref.read(logsProvider.notifier);

      final allLogs = Log().getLogs();

      if (allLogs.isNotEmpty) {
        List<String> logEntries = allLogs.split('\n');
        List<String> filteredLogs = logEntries.where((log) => log.isNotEmpty).toList();

        if (filteredLogs.isNotEmpty) {
          logsNotifier._existingLogs.clear();
          logsNotifier._existingLogs.addAll(filteredLogs);
          logsNotifier.state = logsNotifier.state.copyWith(logs: filteredLogs);
        }
      }

      logsNotifier.startAutoRefresh();
    });
  }

  @override
  void dispose() {
    ProviderContainer().read(logsProvider.notifier).stopAutoRefresh();
    scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logsState = ref.watch(logsProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients && logsState.logs.isNotEmpty) {
        try {
          // scrollController.animateTo(
          //   scrollController.position.maxScrollExtent,
          //   duration: const Duration(milliseconds: 200),
          //   curve: Curves.easeOut,
          // );
        } catch (e) {
          debugPrint('Error scrolling to bottom: $e');
        }
      }
    });

    return Container(
      padding: EdgeInsets.all(20.w),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.9,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                flex: 2,
                child: Text(
                  AppLocalizations.of(context).appLogs,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    fontFamily: AppTheme.fontFamily,
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              Flexible(
                flex: 3,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: ref.read(logsProvider.notifier).isRefreshing()
                            ? Colors.green
                            : Colors.red,
                      ),
                    ),
                    SizedBox(width: 4.w),
                    Flexible(
                      child: Text(
                        AppLocalizations.of(context).autoRefresh,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12.sp,
                          fontFamily: AppTheme.fontFamily,
                        ),
                      ),
                    ),
                    SizedBox(width: 4.w),
                    IconButton(
                      icon: Icon(Icons.refresh, color: Colors.grey[700]),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => ref.read(logsProvider.notifier).fetchLogs(),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12.r),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: EdgeInsets.all(12.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (logsState.logs.isEmpty)
                          Text(
                            'Sample log: [INFO] Connection initialized',
                            style: TextStyle(
                              color: Colors.green[700],
                              fontFamily: AppTheme.fontFamily,
                              fontSize: 12.sp,
                            ),
                          ),
                        ...logsState.logs.map((log) {
                          Color textColor = Colors.black87;

                          if (log.contains('ERROR') || log.contains('error')) {
                            textColor = Colors.red[700]!;
                          } else if (log.contains('WARNING') ||
                              log.contains('NEW SESSION') ||
                              log.contains('Warp client stopped gracefully') ||
                              log.contains('Starting Warp with config')) {
                            textColor = Colors.orange[800]!;
                          } else if (log.contains('STEP')) {
                            textColor = Colors.green[700]!;
                          } else if (log.contains('DEBUG')) {
                            textColor = Colors.blue[700]!;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              log,
                              style: TextStyle(
                                color: textColor,
                                fontFamily: AppTheme.fontFamily,
                                fontSize: 12.sp,
                              ),
                            ),
                          );
                        }),
                        // Add extra space at the bottom for better visibility of last log
                        SizedBox(height: 16.h),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8.h,
                  right: 8.w,
                  child: InkWell(
                    onTap: () => ref.read(logsProvider.notifier).clearLogs(),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear_all,
                            color: Colors.grey[700],
                            size: 14.sp,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            AppLocalizations.of(context).clear,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 10.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20.h),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: AppLocalizations.of(context).close,
                  onPressed: () => Navigator.of(context).pop(),
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.secondary,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: AppButton(
                  label: AppLocalizations.of(context).copyLogs,
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: logsState.logs.join('\n')),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context).logsCopied),
                        backgroundColor: const Color(0xFF2A2A2A),
                      ),
                    );
                  },
                  size: AppButtonSize.small,
                  variant: AppButtonVariant.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// For backward compatibility if someone uses the LogScreen directly
class LogScreen extends ConsumerStatefulWidget {
  const LogScreen({super.key});

  @override
  ConsumerState<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends ConsumerState<LogScreen> {
  @override
  void initState() {
    super.initState();

    // Show logs immediately
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Get the full logs from WarpPlus
      final allLogs = Log().getLogs();

      if (allLogs.isNotEmpty) {
        final logsNotifier = ref.read(logsProvider.notifier);

        // Process the logs
        List<String> logEntries = allLogs.split('\n');

        // Filter out empty entries
        List<String> filteredLogs = logEntries.where((log) => log.isNotEmpty).toList();

        if (filteredLogs.isNotEmpty) {
          // Reset existing logs set to avoid duplicates with a fresh start
          logsNotifier._existingLogs.clear();
          logsNotifier._existingLogs.addAll(filteredLogs);

          // Update the state with all logs
          logsNotifier.state = logsNotifier.state.copyWith(logs: filteredLogs);
        }
      }

      // Start auto-refresh to get new logs
      ref.read(logsProvider.notifier).startAutoRefresh();
      _showLogPopup();
    });
  }

  void _showLogPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.r),
          ),
          insetPadding: EdgeInsets.symmetric(horizontal: 24.w),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: const LogPopupContent(),
        );
      },
    ).then((_) {
      ref.read(logsProvider.notifier).stopAutoRefresh();
      if (mounted) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

// Shared entry point for showing the log viewer as a full-screen overlay
void showAppLogsOverlay(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: const Color.fromARGB(13, 0, 0, 0),
          child: const LogScreen(),
        ),
      );
    },
  );
}
