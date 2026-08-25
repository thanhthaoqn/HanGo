import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'presentation/pages/learner/learner_shell_page.dart';
import 'presentation/pages/course_manager/course_manager_shell_page.dart';
import 'presentation/pages/admin/admin_dashboard_page.dart';
import 'presentation/pages/trainer/trainer_shell_page.dart';
import 'data/services/trainer_onboarding_service.dart';
import 'services/secure_session_store.dart';
import 'utils/web_session_helper.dart'
    show isSessionActive, setSessionActive, isRememberMeEnabled;
import 'utils/trainer_onboarding_flow_utils.dart';
import 'services/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'HanGo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF28B79B)),
          useMaterial3: true,
        ),
        home: Consumer<AppState>(
          builder: (context, appState, child) {
            if (appState.isBooting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF28B79B),
                    ),
                  ),
                ),
              );
            }

            // Check roles and navigate accordingly on startup/reload
            if (appState.isAuthenticated) {
              final role = appState.session?.role;
              if (role == 'ADMIN') {
                return const AdminDashboardPage();
              } else if (role == 'COURSE_MANAGER') {
                return const CourseManagerShellPage();
              } else if (role == 'TRAINER') {
                return const TrainerRouteGate();
              }
            }

            return const LearnerShellPage();
          },
        ),
      ),
    );
  }
}

class TrainerRouteGate extends StatefulWidget {
  const TrainerRouteGate({super.key});

  @override
  State<TrainerRouteGate> createState() => _TrainerRouteGateState();
}

class _TrainerRouteGateState extends State<TrainerRouteGate> {
  late Future<Widget> _destinationFuture;

  @override
  void initState() {
    super.initState();
    _destinationFuture = _resolveDestination();
  }

  Future<Widget> _resolveDestination() async {
    final onboardingService = TrainerOnboardingService();
    final result = await onboardingService.getTrainerProfile();

    if (result['success'] != true) {
      debugPrint(
        '[TrainerRouteGate] Failed to load profile: ${result['message']}',
      );
      throw StateError('Unable to load trainer profile.');
    }

    final profile = Map<String, dynamic>.from(result['data'] ?? const {});
    final stage = resolveTrainerOnboardingStage(profile);
    return stage == TrainerOnboardingStage.complete
        ? const TrainerShellPage()
        : buildTrainerOnboardingStagePage(profile);
  }

  void _retry() {
    setState(() {
      _destinationFuture = _resolveDestination();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Widget>(
      future: _destinationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData) {
          return snapshot.data!;
        }

        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Color(0xFFEF4444),
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Không thể tải hồ sơ Trainer.',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Vui lòng kiểm tra kết nối và thử lại.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF64748B)),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _retry,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return const Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF28B79B)),
            ),
          ),
        );
      },
    );
  }
}
