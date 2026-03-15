import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlowLineState {
  final int step;
  final int totalSteps;
  final String mode;

  const FlowLineState({this.step = 0, this.totalSteps = 0, this.mode = ''});

  FlowLineState copyWith({int? step, int? totalSteps, String? mode}) {
    return FlowLineState(
      step: step ?? this.step,
      totalSteps: totalSteps ?? this.totalSteps,
      mode: mode ?? this.mode,
        
    );
  }
}

final flowLineProvider =
    StateNotifierProvider<FlowLineNotifier, FlowLineState>((ref) {
      return FlowLineNotifier();
    });

class FlowLineNotifier extends StateNotifier<FlowLineState> {
  static const String _flowLineStepKey = 'flow_line_step';
  static const String _flowLineMode = 'flow_line_mode';

  FlowLineNotifier() : super(const FlowLineState()) {
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStep = prefs.getInt(_flowLineStepKey);
      final savedMode = prefs.getString(_flowLineMode);

      state = FlowLineState(step: savedStep ?? 0, mode: savedMode ?? '');
    } catch (e) {
      debugPrint('Error loading saved flow line data: $e');
    }
  }

  Future<void> _saveStep() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_flowLineStepKey, state.step);
    } catch (e) {
      debugPrint('Error saving flow line step: $e');
    }
  }

  void setStep(int step) {
    state = state.copyWith(step: step);
    _saveStep();
  }

  void setTotalSteps(int totalSteps) {
    state = state.copyWith(totalSteps: totalSteps);
    _saveStep();
  }

  void incrementStep() {
    state = state.copyWith(step: state.step + 1);
    _saveStep();
  }

  void resetStep() {
    state = const FlowLineState(step: 0);
    _saveStep();
  }

  Future<void> setMode(String mode) async {
    state = state.copyWith(mode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_flowLineMode, mode);
  }
}
