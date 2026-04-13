import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'l10n/app_localizations.dart';
import 'routes.dart';
import 'utils/theme.dart';
import 'screens/auth/login_callback.dart';
import 'screens/auth/splash_screen.dart';
import 'providers/locale_provider.dart';
import 'services/auth_service.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AuthService.initialize();
  await ApiService.init();
  await NotificationService.initialize();
  usePathUrlStrategy();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeNotifierProvider);

    return MaterialApp(
      title: 'Grievance System',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: ThemeMode.system,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('mr'),
        Locale('hi'),
      ],
      home: const SplashScreen(),
      routes: appRoutes,
      onGenerateRoute: (settings) {
        if (settings.name?.startsWith('/login/callback') ?? false) {
          return MaterialPageRoute(
            builder: (context) => LoginCallbackScreen(),
            settings: settings,
          );
        }
        return null;
      },
    );
  }
}
