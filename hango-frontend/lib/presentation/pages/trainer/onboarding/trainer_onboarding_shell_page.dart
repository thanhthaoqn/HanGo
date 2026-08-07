import 'package:flutter/material.dart';
import '../../../widgets/internal_app_header.dart';
import '../../../widgets/trainer/trainer_sidebar.dart';

class TrainerOnboardingShellPage extends StatefulWidget {
  final Widget initialBody;

  const TrainerOnboardingShellPage({
    super.key,
    required this.initialBody,
  });

  static TrainerOnboardingShellPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<TrainerOnboardingShellPageState>();
  }

  @override
  State<TrainerOnboardingShellPage> createState() => TrainerOnboardingShellPageState();
}

class TrainerOnboardingShellPageState extends State<TrainerOnboardingShellPage> {
  late Widget _currentBody;

  @override
  void initState() {
    super.initState();
    _currentBody = widget.initialBody;
  }

  void updateBody(Widget newBody) {
    if (mounted) {
      setState(() {
        _currentBody = newBody;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop
          ? Drawer(
              child: TrainerSidebar(
                activeIndex: 5, // My Profile highlighted
                disabledIndices: const [0, 1, 2, 3, 4, 5, 6],
              ),
            )
          : null,
      body: Row(
        children: [
          if (isDesktop)
            SizedBox(
              width: 240,
              child: TrainerSidebar(
                activeIndex: 5, // My Profile highlighted in green
                disabledIndices: const [0, 1, 2, 3, 4, 5, 6],
              ),
            ),
          Expanded(
            child: Column(
              children: [
                InternalAppHeader(
                  isMobile: !isDesktop,
                  showLogo: false, // Avoid duplicate logo with desktop sidebar
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: KeyedSubtree(
                      key: ValueKey(_currentBody.runtimeType),
                      child: _currentBody,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
