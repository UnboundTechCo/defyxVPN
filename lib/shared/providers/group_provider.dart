import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupState {
  final String groupName;

  const GroupState({this.groupName = ''});

  GroupState copyWith({String? groupName}) {
    return GroupState(groupName: groupName ?? this.groupName);
  }
}

final groupStateProvider =
    StateNotifierProvider<GroupStateNotifier, GroupState>((ref) {
  return GroupStateNotifier();
});

class GroupStateNotifier extends StateNotifier<GroupState> {
  GroupStateNotifier() : super(const GroupState());

  void setGroupName(String name) {
    state = state.copyWith(groupName: name.toUpperCase());
  }

  void clearGroupName() {
    state = const GroupState();
  }
}
