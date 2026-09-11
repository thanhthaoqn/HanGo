import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'services/secure_session_store.dart';
import 'utils/web_session_helper.dart'
    show isSessionActive, setSessionActive, isRememberMeEnabled;
import 'services/app_state.dart';
import 'routes/app_router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();
  GoRouter.optionURLReflectsImperativeAPIs = true;

  // Clear persistent session only on a cold run or new tab (not on F5 refresh),
  // unless the user checked "Remember me" at login -- then keep it across restarts.
  if (!isSessionActive() && !isRememberMeEnabled()) {
    final sessionStore = SecureSessionStore();
    await sessionStore.clearSession();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_roles');
    await prefs.remove('user_email');
    await prefs.remove('user_fullname');
    await prefs.remove('user_id');

    setSessionActive();
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  GoRouter? _router;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, appState, child) {
          _router ??= AppRouter.createRouter(appState);
          return MaterialApp.router(
            title: 'HanGo',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF28B79B)),
              useMaterial3: true,
            ),
            routerConfig: _router!,
          );
        },
      ),
    );
  }
}
