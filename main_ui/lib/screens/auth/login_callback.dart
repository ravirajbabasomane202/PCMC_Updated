import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';

class LoginCallbackScreen extends ConsumerStatefulWidget {
  const LoginCallbackScreen({super.key});

  @override
  ConsumerState<LoginCallbackScreen> createState() => _LoginCallbackScreenState();
}

class _LoginCallbackScreenState extends ConsumerState<LoginCallbackScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleCallback();
    });
  }

  Future<void> _handleCallback() async {
  try {
    final uri = Uri.base;
    final token = uri.queryParameters['access_token'];

    if (token == null) {
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    await ref.read(authProvider.notifier).processNewToken(token);

    final user = ref.read(authProvider);

    if (!mounted) return;

    if (user != null && user.role != null) {
      Navigator.pushReplacementNamed(
        context,
        '/${user.role!.toLowerCase()}/home',
      );
    } else {
      await ref.read(authProvider.notifier).logout();

      Navigator.pushReplacementNamed(context, '/login');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)?.authenticationFailed
                ?? 'Login failed: invalid user data',
          ),
        ),
      );
    }
  } catch (e) {
    if (!mounted) return;

    Navigator.pushReplacementNamed(context, '/login');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)?.error
              ?? 'An unexpected error occurred',
        ),
      ),
    );
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)?.loading ?? 'Processing login...',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}