import 'package:flutter/material.dart';
import '../../../data/services/trainer_onboarding_service.dart';
import '../../../utils/trainer_onboarding_flow_utils.dart';
import 'trainer_shell_page.dart';

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
