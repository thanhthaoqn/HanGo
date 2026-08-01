import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'presentation/pages/learner/learner_home_page.dart';
import 'presentation/pages/learner/learner_shell_page.dart';
import 'presentation/pages/course_manager/course_manager_dashboard_page.dart';
import 'presentation/pages/admin/admin_dashboard_page.dart';
import 'presentation/pages/trainer/trainer_dashboard_page.dart';
import 'presentation/pages/trainer/trainer_shell_page.dart';
import 'presentation/pages/trainer/onboarding/trainer_type_selection_page.dart';
import 'presentation/pages/trainer/onboarding/trainer_onboarding_status_page.dart';
import 'presentation/pages/trainer/onboarding/trainer_onboarding_details_page.dart';
import 'presentation/pages/trainer/onboarding/trainer_onboarding_agreement_page.dart';
import 'presentation/pages/trainer/onboarding/trainer_payout_details_page.dart';
import 'data/services/trainer_onboarding_service.dart';
import 'services/secure_session_store.dart';
import 'utils/web_session_helper.dart';
import 'utils/toast_helper.dart';
import 'services/app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Clear persistent session only on a cold run or new tab (not on F5 refresh)
  if (!isSessionActive()) {
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
                return const CourseManagerDashboardPage();
              } else if (role == 'COURSE_MANAGER') {
                return const CourseManagerDashboardPage();
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
  @override
  void initState() {
    super.initState();
    _checkStatusAndRoute();
  }

  void _checkStatusAndRoute() async {
    try {
      final onboardingService = TrainerOnboardingService();
      final result = await onboardingService.getTrainerProfile();

      if (!mounted) return;

      if (result['success'] == true) {
        final profile = result['data'];
        final status = profile['status'] ?? 'PENDING_VERIFICATION';
        final trainerType = profile['trainerType'];
        final agreementSigned = profile['agreementSigned'] ?? false;
        final bankAccount = profile['bankAccount'] ?? '';

        if (status == 'VERIFIED') {
          if (!agreementSigned) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TrainerOnboardingAgreementPage(
                  profilePayload: profile,
                  trainerType: trainerType ?? 'PROFESSIONAL',
                ),
              ),
            );
          } else if (bankAccount.toString().trim().isEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TrainerPayoutDetailsPage(initialProfile: profile),
              ),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerShellPage()),
            );
          }
        } else if (status == 'AWAITING_APPROVAL' ||
            status == 'SUSPENDED' ||
            (status == 'PENDING_VERIFICATION' &&
                profile['adminNotes'] != null &&
                profile['adminNotes'].toString().trim().isNotEmpty)) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TrainerOnboardingStatusPage(initialProfile: profile),
            ),
          );
        } else {
          // PENDING_VERIFICATION (Draft)
          if (trainerType == null) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerTypeSelectionPage()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TrainerOnboardingDetailsPage(initialProfile: profile),
              ),
            );
          }
        }
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const TrainerTypeSelectionPage()),
        );
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi kết nối máy chủ');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LearnerHomePage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF28B79B)),
        ),
      ),
    );
  }
}

