import 'package:defyx_vpn/modules/core/log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'dart:async';

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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF3D3D3D), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'App Logs',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Lato',
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: ref.read(logsProvider.notifier).isRefreshing()
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Auto-refresh',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontFamily: 'Lato',
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () => ref.read(logsProvider.notifier).fetchLogs(),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(8),
            ),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
              maxWidth: MediaQuery.of(context).size.width * 0.9,
            ),
            child: Stack(
              children: [
                SingleChildScrollView(
                  controller: scrollController,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (logsState.logs.isEmpty)
                          const Text(
                            'Sample log: [INFO] Connection initialized',
                            style: TextStyle(
                              color: Colors.green,
                              fontFamily: 'Lato',
                              fontSize: 12,
                            ),
                          ),
                        ...logsState.logs.map((log) {
                          Color textColor = Colors.grey;

                          if (log.contains('ERROR') || log.contains('error')) {
                            textColor = Colors.red;
                          } else if (log.contains('WARNING') ||
                              log.contains('NEW SESSION') ||
                              log.contains('Warp client stopped gracefully') ||
                              log.contains('Starting Warp with config')) {
                            textColor = Colors.orange;
                          } else if (log.contains('STEP')) {
                            textColor = Colors.green;
                          } else if (log.contains('DEBUG')) {
                            textColor = Colors.blue;
                          }

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              log,
                              style: TextStyle(
                                color: textColor,
                                fontFamily: 'Lato',
                                fontSize: 12,
                              ),
                            ),
                          );
                        }),
                        // Add extra space at the bottom for better visibility of last log
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: InkWell(
                    onTap: () => ref.read(logsProvider.notifier).clearLogs(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.clear_all,
                            color: Colors.white70,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Clear',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
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
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3D3D3D),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Close'),
              ),
              ElevatedButton(
                onPressed: () {
                  Clipboard.setData(
                    ClipboardData(text: logsState.logs.join('\n')),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logs copied to clipboard'),
                      backgroundColor: Color(0xFF2A2A2A),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Copy Logs'),
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
            borderRadius: BorderRadius.circular(16),
          ),
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
