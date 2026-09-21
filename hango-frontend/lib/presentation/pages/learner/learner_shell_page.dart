import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_drawer.dart';
import 'learner_home_page.dart';
import '../course/list_courses_page.dart';
import '../exam/list_exams_page.dart';
import 'learning_pathway_page.dart';
import 'my_learning_page.dart';
import 'my_information_page.dart';
import '../course/cart_page.dart';
import '../course/course_detail_page.dart';
import '../../../utils/toast_helper.dart';
import '../../../utils/cart_manager.dart';
import '../../../utils/web_session_helper.dart';
import '../../../data/repositories/payment_repository.dart';

class LearnerShellPage extends StatefulWidget {
  final int initialIndex;
  final int initialSubTab;
  final StatefulNavigationShell? navigationShell;

  const LearnerShellPage({
    super.key,
    this.initialIndex = 0,
    this.initialSubTab = 0,
    this.navigationShell,
  });

  static LearnerShellPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<LearnerShellPageState>();
  }

  @override
  State<LearnerShellPage> createState() => LearnerShellPageState();
}

class LearnerShellPageState extends State<LearnerShellPage> {
  late int _currentIndex;
  late int _informationSubTab;
  bool _isRedirecting = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _informationSubTab = widget.initialSubTab;
    _checkRedirectState();
    _handlePayOSRedirect();
  }

  void _checkRedirectState() {
    final currentUri = Uri.base.toString();
    final fragment = Uri.base.fragment;
    final fullUrl = '$currentUri#$fragment';

    final isSuccess = fullUrl.contains('payment-success') ||
        fullUrl.contains('paymentStatus=success') ||
        (fullUrl.contains('status=PAID') && (fullUrl.contains('code=00') || fullUrl.contains('cancel=false')));
    final isFailed = fullUrl.contains('payment-failed') ||
        fullUrl.contains('paymentStatus=failed') ||
        fullUrl.contains('cancel=true');

    if (isSuccess || isFailed) {
      _isRedirecting = true;
    }
  }

  void _handlePayOSRedirect() {
    final currentUri = Uri.base.toString();
    final fragment = Uri.base.fragment;
    final fullUrl = '$currentUri#$fragment';

    final isSuccess = fullUrl.contains('payment-success') ||
        fullUrl.contains('paymentStatus=success') ||
        (fullUrl.contains('status=PAID') && (fullUrl.contains('code=00') || fullUrl.contains('cancel=false')));
    final isFailed = fullUrl.contains('payment-failed') ||
        fullUrl.contains('paymentStatus=failed') ||
        fullUrl.contains('cancel=true');

    if (!isSuccess && !isFailed) return;

    String? courseIdentifier;
    final match = RegExp(r'[?&](?:courseId|courseUuid)=([a-zA-Z0-9\-]+)').firstMatch(fullUrl);
    if (match != null) {
      courseIdentifier = match.group(1);
    }

    String? txnRef;
    final orderCodeMatch = RegExp(r'[?&]orderCode=(\d+)').firstMatch(fullUrl);
    if (orderCodeMatch != null) {
      txnRef = orderCodeMatch.group(1);
    } else {
      final txnMatch = RegExp(r'[?&]txnRef=(\d+)').firstMatch(fullUrl);
      if (txnMatch != null) {
        txnRef = txnMatch.group(1);
      }
    }

    clearPaymentUrlFromAddressBar();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (isSuccess) {
        if (txnRef != null && txnRef.isNotEmpty) {
          try {
            await PaymentRepository().checkPaymentStatus(txnRef);
          } catch (e) {
            debugPrint('Error syncing payment status for txnRef=$txnRef: $e');
          }
        }

        if (courseIdentifier != null) {
          await CartManager.removeByIdentifier(courseIdentifier);
        } else {
          await CartManager.clearCart();
        }
        if (mounted) {
          ToastHelper.showSuccess(
            context,
            'Payment successful! ${courseIdentifier != null ? "Course unlocked." : "Courses unlocked."}',
          );
        }
      } else {
        ToastHelper.showError(
          context,
          'Course payment cancelled.',
        );
      }

      if (mounted) {
        setState(() {
          _isRedirecting = false;
        });
      }

      if (courseIdentifier != null && mounted) {
        try {
          context.go('/courses/$courseIdentifier');
        } catch (_) {
          try {
            context.push('/courses/$courseIdentifier');
          } catch (_) {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (context) => CourseDetailPage(courseId: courseIdentifier!),
              ),
            );
          }
        }
      } else if (mounted) {
        selectTab(6); // Return directly to Shopping Cart tab
      }
    });
  }

  int get currentIndex => widget.navigationShell?.currentIndex ?? _currentIndex;

  void selectTab(int index, {int subTab = 0}) {
    if (widget.navigationShell != null) {
      widget.navigationShell!.goBranch(
        index,
        initialLocation: index == widget.navigationShell!.currentIndex,
      );
      if (index == 5) {
        setState(() {
          _informationSubTab = subTab;
        });
      }
    } else {
      setState(() {
        _currentIndex = index;
        if (index == 5) {
          _informationSubTab = subTab;
        }
      });
    }
  }

  String _getActiveTabName() {
    switch (currentIndex) {
      case 0:
        return '';
      case 1:
        return 'Courses';
      case 2:
        return 'Exams';
      case 3:
        return 'Learning Pathway';
      case 4:
        return 'Learning';
      case 5:
        return 'Profile';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isRedirecting) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF28B79B)),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 992;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(
        isDesktop: isDesktop,
        activeTab: _getActiveTabName(),
      ),
      drawer: isDesktop ? null : SharedDrawer(activeTab: _getActiveTabName()),
      body: widget.navigationShell ??
          IndexedStack(
            index: _currentIndex,
            children: [
              const LearnerHomePage(isEmbedded: true),
              const ListCoursesPage(isEmbedded: true),
              const ListExamsPage(isEmbedded: true),
              const LearningPathwayPage(isEmbedded: true),
              const MyLearningPage(isEmbedded: true),
              MyInformationPage(isEmbedded: true, initialTab: _informationSubTab),
              const CartPage(isEmbedded: true),
            ],
          ),
    );
  }
}
