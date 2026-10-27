import 'package:defyx_vpn/modules/premium/presentation/widgets/premium_login.dart';
import 'package:defyx_vpn/modules/premium/presentation/widgets/premium_logged_in.dart';
import 'package:defyx_vpn/modules/premium/presentation/widgets/premium_login_by_code.dart';
import 'package:defyx_vpn/modules/settings/providers/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AccountScreenState { login, loginByCode }

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  AccountScreenState state = AccountScreenState.login;

  void _navigateTo(AccountScreenState newState) {
    setState(() {
      state = newState;
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return authState.when(
      data: (user) {
        if (user.isLoggedIn) {
          return _buildLoggedInView(user.email);
        } else {
          if (state == AccountScreenState.login) {
            return _buildLoginView();
          }
          return _buildLoginByCodeView();
        }
      },
      loading: () =>
          const Center(child: CircularProgressIndicator(color: Colors.white)),
      error: (error, stack) => Center(
        child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
      ),
    );
  }

  Widget _buildLoginView() {
    return PremiumLogin(
      ref: ref,
      navigateToLoginByCode: () => _navigateTo(AccountScreenState.loginByCode),
    );
  }

  Widget _buildLoginByCodeView() {
    return PremiumLoginByCode(
      navigateToLogin: () => _navigateTo(AccountScreenState.login),
    );
  }

  Widget _buildLoggedInView(String email) {
    return PremiumLoggedIn(ref: ref, email: email);
  }
}
