import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/language_manager.dart';
import '../../../widgets/shared_header.dart';
import '../../../widgets/shared_footer.dart';
import 'trainer_onboarding_status_page.dart';
import 'trainer_payout_details_page.dart';
import '../../login_page.dart';

class TrainerOnboardingAgreementPage extends StatefulWidget {
  final Map<String, dynamic> profilePayload;
  final String trainerType;

  const TrainerOnboardingAgreementPage({
    super.key,
    required this.profilePayload,
    required this.trainerType,
  });

  @override
  State<TrainerOnboardingAgreementPage> createState() => _TrainerOnboardingAgreementPageState();
}

class _TrainerOnboardingAgreementPageState extends State<TrainerOnboardingAgreementPage> {
  final _onboardingService = TrainerOnboardingService();
  bool _agreementSigned = false;
  bool _isSubmitting = false;

  void _handleSubmit() async {
    if (!_agreementSigned) {
      ToastHelper.showError(
        context,
        LanguageManager.isVi
            ? 'Bạn phải xác nhận đồng ý với điều khoản để tiếp tục.'
            : 'You must check the agreement box to proceed.',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Add agreement check to payload
    final finalPayload = Map<String, dynamic>.from(widget.profilePayload);
    finalPayload['agreementSigned'] = true;

    final result = await _onboardingService.saveProfileDraft(finalPayload);

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        ToastHelper.showSuccess(
          context,
          LanguageManager.isVi
              ? 'Ký thỏa thuận thành công!'
              : 'Agreement signed successfully!',
        );
        
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TrainerPayoutDetailsPage(initialProfile: result['data'] ?? finalPayload),
          ),
        );
      } else {
        ToastHelper.showError(context, result['message'] ?? 'Lỗi lưu thỏa thuận.');
      }
    }
  }

  final _authService = AuthService();
  String _trainerName = '';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _loadTrainerHeaderInfo();
  }

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
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isVi = LanguageManager.isVi;
    final isPro = widget.trainerType == 'PROFESSIONAL';

    final splitText = isVi
        ? 'Nhận chia sẻ doanh thu hấp dẫn theo chính sách của HanGo'
        : 'Trainer receives attractive revenue share according to HanGo policies';

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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 800),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isVi ? 'Bản thỏa thuận hợp tác điện tử' : 'E-Cooperation Agreement',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isVi
                                  ? 'Vui lòng đọc kỹ các điều khoản chia sẻ doanh thu và quy định trước khi nộp hồ sơ giảng dạy.'
                                  : 'Please read the revenue split terms and compliance guidelines before signing.',
                              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                            ),
                            const SizedBox(height: 32),
                      // Agreement Terms Box
                      Container(
                        height: 350,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTermTitle(isVi ? 'ĐIỀU 1: PHÂN CHIA DOANH THU' : 'ARTICLE 1: REVENUE SHARE'),
                                  _buildTermText(
                                    isVi
                                        ? 'Dựa trên phân loại tài khoản: ${isPro ? "Giáo viên chuyên nghiệp" : "Gia sư đồng học"}.\n- Tỷ lệ thỏa thuận chia sẻ: $splitText.\n- Hệ thống sẽ tự động đối soát thanh toán và kết chuyển phần tiền tương ứng vào Tài khoản Ngân hàng đã liên kết của Giáo viên sau khi khấu trừ 10% thuế TNCN theo quy định pháp luật.'
                                        : 'Based on selected profile: ${isPro ? "Professional" : "Peer Tutor"}.\n- Split Ratio: $splitText.\n- Payments are automatically consolidated and transferred to the configured bank account after deducting a mandatory 10% personal income tax.',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTermTitle(isVi ? 'ĐIỀU 2: BẢO MẬT & BẢN QUYỀN NỘI DUNG' : 'ARTICLE 2: CONTENT COPYRIGHTS'),
                                  _buildTermText(
                                    isVi
                                        ? 'Giáo viên cam kết tự biên soạn nội dung bài giảng, đề thi và câu hỏi. Không sao chép hay sử dụng các nội dung của bên thứ ba chưa được cấp phép. Mọi tranh chấp liên quan đến bản quyền nội dung, giáo viên sẽ chịu trách nhiệm hoàn toàn trước pháp luật.'
                                        : 'Instructors guarantee original ownership of syllabus, exams, and quizzes. No unlicensed duplication of third-party assets is permitted. The instructor assumes full legal responsibility for any copyrights violations.',
                                  ),
                                  const SizedBox(height: 16),
                                  _buildTermTitle(isVi ? 'ĐIỀU 3: CHÍNH SÁCH HOÀN TIỀN' : 'ARTICLE 3: REFUNDS POLICY'),
                                  _buildTermText(
                                    isVi
                                        ? 'Nhằm bảo vệ trải nghiệm của Học viên, HanGo áp dụng chính sách hoàn trả học phí trong vòng 7 ngày đầu kể từ lúc đăng ký nếu nội dung giảng dạy không đúng mô tả hoặc gặp lỗi hệ thống do chất lượng video bài học.'
                                        : 'To protect learners, HanGo enforces a 7-day refund warranty. If course contents violate descriptions or video streaming fails, students are entitled to a full refund.',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Agreement checkbox
                      CheckboxListTile(
                        title: Text(
                          isVi
                              ? 'Tôi cam đoan thông tin bằng cấp là thật và đồng ý với Bản thỏa thuận hợp tác này.'
                              : 'I certify that my credentials are true and agree to this contract.',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF334155), fontFamily: 'Outfit'),
                        ),
                        value: _agreementSigned,
                        activeColor: const Color(0xFF28B79B),
                        onChanged: (val) {
                          setState(() {
                            _agreementSigned = val ?? false;
                          });
                        },
                      ),
                      const SizedBox(height: 32),
                      // Submit action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isSubmitting ? null : _handleSubmit,
                            icon: const Icon(Icons.draw_rounded, size: 16),
                            label: _isSubmitting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(isVi ? 'Ký thỏa thuận & Gửi duyệt' : 'Sign & Submit Application'),
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
                  ),
                ),
              ],
            ),
          ),
        ],
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
