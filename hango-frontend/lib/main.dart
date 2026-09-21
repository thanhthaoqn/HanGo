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
import 'routes/app_routes.dart';

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

  // Prevent Red Screen of Death in UI and provide a clean fallback
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return Material(
      color: const Color(0xFFF8FAFC),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.refresh_rounded, size: 48, color: Color(0xFF28B79B)),
              const SizedBox(height: 16),
              const Text(
                'Something went wrong',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'A temporary rendering or navigation synchronization issue occurred.',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28B79B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onPressed: () {
                  final ctx = AppRouter.rootNavigatorKey.currentContext;
                  if (ctx != null) {
                    ctx.go(AppRoutes.home);
                  }
                },
                child: const Text('Back to Home'),
              ),
            ],
          ),
        ),
      ),
    );
  };

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
