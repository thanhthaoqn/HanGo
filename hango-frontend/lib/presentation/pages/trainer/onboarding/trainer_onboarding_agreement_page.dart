import 'package:flutter/material.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/language_manager.dart';
import '../../../widgets/shared_header.dart';
import '../../../widgets/shared_footer.dart';
import 'trainer_onboarding_status_page.dart';
import 'trainer_onboarding_details_page.dart';
import 'trainer_payout_details_page.dart';
import 'trainer_onboarding_shell_page.dart';
import '../../learner/learner_home_page.dart';
import '../../login_page.dart';

class TrainerOnboardingAgreementPage extends StatefulWidget {
  final Map<String, dynamic> profilePayload;
  final String trainerType;
  final bool isEmbedded;

  const TrainerOnboardingAgreementPage({
    super.key,
    required this.profilePayload,
    required this.trainerType,
    this.isEmbedded = false,
  });

  @override
  State<TrainerOnboardingAgreementPage> createState() => _TrainerOnboardingAgreementPageState();
}

class _TrainerOnboardingAgreementPageState extends State<TrainerOnboardingAgreementPage> {
  final _onboardingService = TrainerOnboardingService();
  final ScrollController _termsScrollController = ScrollController();
  bool _hasScrolledToBottom = false;
  bool _agreementSigned = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadTrainerHeaderInfo();
    _termsScrollController.addListener(_onTermsScroll);
  }

  @override
  void dispose() {
    _termsScrollController.removeListener(_onTermsScroll);
    _termsScrollController.dispose();
    super.dispose();
  }

  void _onTermsScroll() {
    if (_termsScrollController.hasClients) {
      final maxScroll = _termsScrollController.position.maxScrollExtent;
      final currentScroll = _termsScrollController.position.pixels;
      if (currentScroll >= maxScroll - 30) {
        if (!_hasScrolledToBottom) {
          setState(() {
            _hasScrolledToBottom = true;
          });
        }
      }
    }
  }

  void _handleSubmit() async {
    setState(() {
      _isSubmitting = true;
    });

    final finalPayload = Map<String, dynamic>.from(widget.profilePayload);
    finalPayload['agreementSigned'] = true;

    final result = await _onboardingService.saveProfileDraft(finalPayload);

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        final nextPage = TrainerOnboardingDetailsPage(
          initialProfile: result['data'] ?? finalPayload,
          isEmbedded: true,
        );

        final shellState = TrainerOnboardingShellPage.of(context);
        if (shellState != null) {
          shellState.updateBody(nextPage);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TrainerOnboardingShellPage(initialBody: nextPage),
            ),
          );
        }
      } else {
        ToastHelper.showError(context, result['message'] ?? 'Error proceeding.');
      }
    }
  }

  final _authService = AuthService();
  String _trainerName = '';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  Future<void> _loadTrainerHeaderInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? '';
    final avatarUrl = prefs.getString('user_avatar_url') ?? '';
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    setState(() {
      _trainerName = fullName;
      _trainerInitials = initials;
      _trainerAvatarUrl = avatarUrl;
    });
  }

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEmbedded) {
      return TrainerOnboardingShellPage(
        initialBody: TrainerOnboardingAgreementPage(
          profilePayload: widget.profilePayload,
          trainerType: widget.trainerType,
          isEmbedded: true,
        ),
      );
    }

    final isVi = LanguageManager.isVi;
    final isPro = widget.trainerType == 'PROFESSIONAL';
    final roleName = isPro ? 'Teacher' : 'Tutor';
    final roleNameLower = isPro ? 'teacher' : 'tutor';

    final splitText = isVi
        ? (isPro ? '70% doanh thu dành cho Giáo viên (30% phí nền tảng HanGo)' : '60% doanh thu dành cho Gia sư (40% phí nền tảng HanGo)')
        : (isPro ? '70% revenue share for Teacher (30% HanGo platform fee)' : '60% revenue share for Tutor (40% HanGo platform fee)');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'System Rules & Policies',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please review the platform rules regarding revenue share, introductory course requirements, and content policies for $roleName Applications.',
                style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 32),
              // Agreement Terms Box
              Container(
                height: 380,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Scrollbar(
                  controller: _termsScrollController,
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    controller: _termsScrollController,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTermTitle('ARTICLE 1: REVENUE SHARE & SETTLEMENT'),
                          _buildTermText(
                            'Based on selected profile: ${isPro ? "Professional Teacher (70/30 split)" : "Peer Tutor (60/40 split)"}.\n- Contracted Revenue Split Ratio: $splitText.\n- Consolidated payouts are processed monthly to the configured bank account after deducting a mandatory 10% Personal Income Tax as per tax regulations.',
                          ),
                          const SizedBox(height: 16),
                          _buildTermTitle('ARTICLE 2: FIRST COURSE FREE POLICY'),
                          _buildTermText(
                            'To establish initial teaching credentials and contribute to the HanGo community ecosystem, all newly onboarded ${roleName}s agree to publish their very first course for free (0 VND).',
                          ),
                          const SizedBox(height: 16),
                          _buildTermTitle('ARTICLE 3: CONTENT COPYRIGHTS & COMPLIANCE'),
                          _buildTermText(
                            '${roleName}s guarantee original ownership of syllabus, exams, and quizzes. No unlicensed duplication of third-party assets is permitted. The $roleNameLower assumes full legal responsibility for any copyrights violations.',
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (!_hasScrolledToBottom)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isVi
                              ? 'Vui lòng cuộn xuống dưới cùng của khung điều khoản để xác nhận đã đọc xong.'
                              : 'Please scroll all the way to the bottom of the terms container to unlock the button.',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF92400E), fontFamily: 'Outfit'),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 24),
              // Submit action
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: (_hasScrolledToBottom && !_isSubmitting) ? _handleSubmit : null,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(isVi ? 'Tiếp tục hoàn thiện hồ sơ' : 'Continue to Profile'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28B79B),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFF28B79B).withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    final isVi = LanguageManager.isVi;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
              children: [

                Image.network(

                  'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',

                  height: 36,

                  fit: BoxFit.contain,

                  errorBuilder: (context, error, stackTrace) {

                    return Row(

                      children: [

                        Container(

                          width: 32,

                          height: 32,

                          decoration: const BoxDecoration(

                            color: Color(0xFFE6FFFA),

                            shape: BoxShape.circle,

                          ),

                          child: const Icon(

                            Icons.school,

                            size: 18,

                            color: Color(0xFF20B486),

                          ),

                        ),

                        const SizedBox(width: 8),

                        const Text(

                          'HanGo',

                          style: TextStyle(

                            fontSize: 20,

                            fontWeight: FontWeight.bold,

                            color: Color(0xFF1F2937),

                            fontFamily: 'Outfit',

                          ),

                        ),

                      ],

                    );

                  },

                ),

              ],
            ),
          ),
          const SizedBox(height: 40),
          _buildSidebarItem(Icons.dashboard_outlined, isVi ? 'Bảng điều khiển' : 'Dashboard', isActive: true),
          _buildSidebarItem(Icons.book_outlined, isVi ? 'Khóa học' : 'Courses', isEnabled: false),
          _buildSidebarItem(Icons.assignment_outlined, isVi ? 'Đề thi' : 'Exam', isEnabled: false),
          _buildSidebarItem(Icons.people_outline, isVi ? 'Học sinh' : 'Learner', isEnabled: false),
          _buildSidebarItem(Icons.question_answer_outlined, isVi ? 'Ngân hàng câu hỏi' : 'Question Bank', isEnabled: false),
          const Spacer(),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _buildSidebarItem(Icons.logout, isVi ? 'Đăng xuất' : 'Logout', color: Colors.redAccent, isEnabled: true, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, {bool isActive = false, bool isEnabled = true, Color? color, VoidCallback? onTap}) {
    final activeColor = const Color(0xFF20B486);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: isEnabled ? (onTap ?? () {}) : () {
          ToastHelper.show(context, LanguageManager.isVi ? 'Tài khoản của bạn đang chờ phê duyệt' : 'Your account is awaiting approval');
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isActive ? Colors.white : (isEnabled ? (color ?? const Color(0xFF4B5563)) : Colors.grey.shade400),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : (isEnabled ? (color ?? const Color(0xFF1F2937)) : Colors.grey.shade400),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _unusedLegacyHeader(bool showMenuButton) {
    return Container(
      color: Colors.white,
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          Row(
            children: const [
              Icon(Icons.chevron_right, size: 16, color: Color(0xFF20B486)),
              SizedBox(width: 4),
              Text(
                'Verification / Cooperation Agreement',
                style: TextStyle(
                  color: Color(0xFF20B486),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const Spacer(),
          Row(
            children: [
              Text(
                _trainerName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2F9F3),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: _trainerAvatarUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _trainerAvatarUrl,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Text(
                            _trainerInitials,
                            style: const TextStyle(
                              color: Color(0xFF20B486),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      )
                    : Text(
                        _trainerInitials,
                        style: const TextStyle(
                          color: Color(0xFF20B486),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          fontFamily: 'Outfit',
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTermTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _buildTermText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF475569),
          height: 1.6,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}
