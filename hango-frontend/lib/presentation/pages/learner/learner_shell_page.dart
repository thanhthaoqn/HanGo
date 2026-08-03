import 'package:flutter/material.dart';
import '../../widgets/shared_header.dart';
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

class LearnerShellPage extends StatefulWidget {
  final int initialIndex;
  final int initialSubTab;

  const LearnerShellPage({
    super.key,
    this.initialIndex = 0,
    this.initialSubTab = 0,
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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _informationSubTab = widget.initialSubTab;
    _handlePayOSRedirect();
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

    int? courseId;
    final match = RegExp(r'[?&]courseId=(\d+)').firstMatch(fullUrl);
    if (match != null) {
      courseId = int.tryParse(match.group(1)!);
    }

    clearPaymentUrlFromAddressBar();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (isSuccess) {
        if (courseId != null) {
          await CartManager.removeFromCart(courseId);
        } else {
          await CartManager.updateCount();
        }
        if (mounted) {
          ToastHelper.showSuccess(
            context,
            'Payment successful! Course unlocked.',
          );
        }
      } else {
        ToastHelper.showError(
          context,
          'Course payment cancelled.',
        );
      }

      if (courseId != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CourseDetailPage(courseId: courseId!),
          ),
        );
      }
    });
  }

  void selectTab(int index, {int subTab = 0}) {
    setState(() {
      _currentIndex = index;
      if (index == 5) {
        _informationSubTab = subTab;
      }
    });
  }

  String _getActiveTabName() {
    switch (_currentIndex) {
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
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 992;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(
        isDesktop: isDesktop,
        activeTab: _getActiveTabName(),
      ),
      body: IndexedStack(
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
