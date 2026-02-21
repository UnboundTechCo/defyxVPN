import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FlowLineState {
  final int step;
  final int totalSteps;

  const FlowLineState({this.step = 0, this.totalSteps = 0});

  FlowLineState copyWith({int? step, int? totalSteps}) {
    return FlowLineState(
      step: step ?? this.step,
      totalSteps: totalSteps ?? this.totalSteps,
    );
  }
}

final flowLineStepProvider =
    NotifierProvider<FlowLineStepNotifier, FlowLineState>(
      FlowLineStepNotifier.new,
    );

class FlowLineStepNotifier extends Notifier<FlowLineState> {
  static const String _flowLineStepKey = 'flow_line_step';

  @override
  FlowLineState build() {
    _loadSavedStep();
    return const FlowLineState();
  }

  Future<void> _loadSavedStep() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStep = prefs.getInt(_flowLineStepKey);
      if (savedStep != null) {
        state = state.copyWith(step: savedStep);
      }
    } catch (e) {
      debugPrint('Error loading saved flow line step: $e');
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
}
