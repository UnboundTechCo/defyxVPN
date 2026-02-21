import 'package:flutter_riverpod/flutter_riverpod.dart';

class GroupState {
  final String groupName;

  const GroupState({this.groupName = ''});

  GroupState copyWith({String? groupName}) {
    return GroupState(groupName: groupName ?? this.groupName);
  }
}

final groupStateProvider = NotifierProvider<GroupStateNotifier, GroupState>(
  GroupStateNotifier.new,
);

class GroupStateNotifier extends Notifier<GroupState> {
  @override
  GroupState build() => const GroupState();

  void setGroupName(String name) {
    state = state.copyWith(groupName: name.toUpperCase());
  }

  void clearGroupName() {
    state = const GroupState();
  }
}
