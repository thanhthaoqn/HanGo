import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/language_manager.dart';
import '../../../../data/services/auth_service.dart';
import '../../login_page.dart';
import 'trainer_onboarding_details_page.dart';

class TrainerTypeSelectionPage extends StatefulWidget {
  const TrainerTypeSelectionPage({super.key});

  @override
  State<TrainerTypeSelectionPage> createState() => _TrainerTypeSelectionPageState();
}

class _TrainerTypeSelectionPageState extends State<TrainerTypeSelectionPage> {
  final _onboardingService = TrainerOnboardingService();
  final _authService = AuthService();
  String? _selectedType;
  bool _isSubmitting = false;

  String _trainerName = '';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
  }

  Future<void> _loadTrainerInfo() async {
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

  void _handleProceed() async {
    if (_selectedType == null) {
      ToastHelper.showError(
        context,
        LanguageManager.isVi
            ? 'Vui lòng chọn một loại tài khoản giảng dạy để tiếp tục.'
            : 'Please select a teaching account type to proceed.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result = await _onboardingService.becomeTrainer(_selectedType!);

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        ToastHelper.showSuccess(
          context,
          LanguageManager.isVi
              ? 'Đã khởi tạo vai trò giáo viên thành công!'
              : 'Instructor role initialized successfully!',
        );
        final Map<String, dynamic> initialProfile = {};
        if (result['data'] != null && result['data']['profile'] != null) {
          initialProfile.addAll(Map<String, dynamic>.from(result['data']['profile']));
        }
        initialProfile['trainerType'] = _selectedType;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TrainerOnboardingDetailsPage(
              initialProfile: initialProfile,
            ),
          ),
        );
      } else {
        ToastHelper.showError(context, result['message'] ?? 'Lỗi không xác định');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isVi = LanguageManager.isVi;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 240, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              isVi ? 'Đăng ký giảng dạy trên HanGo' : 'Teach on HanGo',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isVi
                                  ? 'Chọn hình thức giảng dạy phù hợp nhất với chuyên môn của bạn để bắt đầu xây dựng khóa học.'
                                  : 'Choose the teaching option that best fits your credentials to start building courses.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF64748B),
                                fontFamily: 'Outfit',
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 48),
                            // Selection Cards Grid/Row
                            size.width > 768
                                ? Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildSelectionCard('PROFESSIONAL', isVi)),
                                      const SizedBox(width: 24),
                                      Expanded(child: _buildSelectionCard('PEER_TUTOR', isVi)),
                                    ],
                                  )
                                : Column(
                                    children: [
                                      _buildSelectionCard('PROFESSIONAL', isVi),
                                      const SizedBox(height: 24),
                                      _buildSelectionCard('PEER_TUTOR', isVi),
                                    ],
                                  ),
                            const SizedBox(height: 48),
                            // Action buttons
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: ElevatedButton(
                                onPressed: _isSubmitting ? null : _handleProceed,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF28B79B),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(0xFF28B79B).withOpacity(0.5),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  elevation: _selectedType == null ? 0 : 4,
                                  shadowColor: const Color(0xFF28B79B).withOpacity(0.3),
                                ),
                                child: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          color: Colors.white,
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            isVi ? 'Tiếp tục hoàn thiện hồ sơ' : 'Proceed with profile',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          const Icon(Icons.arrow_forward_rounded, size: 18),
                                        ],
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
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

  Widget _buildSelectionCard(String type, bool isVi) {
    final isSelected = _selectedType == type;
    final isPro = type == 'PROFESSIONAL';

    final title = isPro
        ? (isVi ? 'Giáo viên Chuyên nghiệp' : 'Professional Trainer')
        : (isVi ? 'Gia sư / Trợ giảng' : 'Peer Tutor');

    final desc = isPro
        ? (isVi
            ? 'Dành cho giáo viên trường THPT, giáo viên đại học hoặc giáo viên trung tâm luyện thi lâu năm có bằng cấp học thuật.'
            : 'For school teachers, university professors, or center lecturers with formal educational degrees.')
        : (isVi
            ? 'Dành cho sinh viên, trợ giảng hoặc cá nhân có điểm thi THPT QG 9+ hoặc chứng chỉ IELTS đạt thành tích xuất sắc.'
            : 'For students, teaching assistants, or peers with 9+ THPT QG scores or stellar IELTS levels.');

    final icon = isPro ? Icons.workspace_premium_rounded : Icons.school_rounded;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedType = type;
          });
        },
        child: AnimatedScale(
          scale: isSelected ? 1.02 : 1.0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? const Color(0xFF28B79B) : const Color(0xFFE2E8F0),
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: const Color(0xFF28B79B).withOpacity(0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  )
                else
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isSelected
                          ? [const Color(0xFFE6FDF9), const Color(0xFFC7F9EE)]
                          : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isSelected ? const Color(0xFF28B79B) : const Color(0xFF64748B),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF334155),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
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

  Widget _buildHeader(BuildContext context, bool showMenuButton) {
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
                'Verification / Account Type',
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
}
