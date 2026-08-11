import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../utils/language_manager.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../data/services/auth_service.dart';
import '../../login_page.dart';
import '../../learner/learner_home_page.dart';
import 'trainer_onboarding_details_page.dart';
import 'trainer_onboarding_agreement_page.dart';
import 'trainer_payout_details_page.dart';
import 'trainer_onboarding_shell_page.dart';
import '../trainer_dashboard_page.dart';

class TrainerOnboardingStatusPage extends StatefulWidget {
  final Map<String, dynamic> initialProfile;
  final bool isEmbedded;

  const TrainerOnboardingStatusPage({
    super.key,
    required this.initialProfile,
    this.isEmbedded = false,
  });

  @override
  State<TrainerOnboardingStatusPage> createState() => _TrainerOnboardingStatusPageState();
}

class _TrainerOnboardingStatusPageState extends State<TrainerOnboardingStatusPage> {
  final _authService = AuthService();
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

  void _showMyApplicationDialog(BuildContext context, bool isVi) {
    final fullName = widget.initialProfile['fullName'] ?? _trainerName;
    final email = widget.initialProfile['email'] ?? '';
    final phone = widget.initialProfile['phoneNumber'] ?? widget.initialProfile['phone'] ?? '';
    final bio = widget.initialProfile['bio'] ?? '';
    final type = widget.initialProfile['trainerType'] ?? 'PROFESSIONAL';

    final score = widget.initialProfile['scoreReportUrl'];
    final avatarUrl = widget.initialProfile['avatarUrl'] ?? _trainerAvatarUrl;

    List<Map<String, String>> certList = [];
    final rawCerts = widget.initialProfile['certificates'];
    if (rawCerts != null && rawCerts is List && rawCerts.isNotEmpty) {
      certList = (rawCerts as List).map((c) => Map<String, String>.from(c as Map)).toList();
    } else if (score != null && score.toString().isNotEmpty) {
      final sStr = score.toString();
      if (sStr.startsWith('[')) {
        try {
          final List parsed = jsonDecode(sStr);
          certList = parsed.map((c) => Map<String, String>.from(c as Map)).toList();
        } catch (_) {}
      } else {
        certList.add({'name': isVi ? 'Minh chứng khác' : 'Score Report / Credential', 'url': sStr});
      }
    }


    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'Đơn đăng ký của tôi' : 'My Application',
                style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              )
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: const Color(0xFFE2E8F0),
                        backgroundImage: (avatarUrl != null && avatarUrl.toString().isNotEmpty)
                            ? NetworkImage(avatarUrl.toString())
                            : null,
                        child: (avatarUrl == null || avatarUrl.toString().isEmpty)
                            ? Text(
                                _trainerInitials,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                              )
                            : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              type == 'PROFESSIONAL'
                                  ? (isVi ? 'Giáo viên' : 'Teacher')
                                  : (isVi ? 'Gia sư' : 'Tutor'),
                              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  _buildDetailRow(isVi ? 'Email' : 'Email', email),
                  _buildDetailRow(isVi ? 'Số điện thoại' : 'Phone', phone),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    isVi ? 'Kinh nghiệm giảng dạy & Bio' : 'Experience & Bio',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      bio,
                      style: const TextStyle(color: Color(0xFF475569), height: 1.4, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Text(
                    isVi ? 'Tài liệu minh chứng' : 'Uploaded Credentials',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: certList.isEmpty
                        ? [
                            Text(
                              isVi ? 'Chưa tải lên minh chứng.' : 'No credentials uploaded.',
                              style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                            )
                          ]
                        : certList.map((item) {
                            final label = item['name'] ?? (isVi ? 'Minh chứng' : 'Credential');
                            final url = item['url'] ?? '';
                            return _buildFileThumbnail(context, label, url);
                          }).toList(),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          Text(value.isNotEmpty ? value : '...', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildFileThumbnail(BuildContext context, String label, String url) {
    return InkWell(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 700, maxHeight: 600),
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => Center(
                          child: SelectableText(url),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                url,
                width: 80,
                height: 60,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.insert_drive_file, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEmbedded) {
      return TrainerOnboardingShellPage(
        initialBody: TrainerOnboardingStatusPage(
          initialProfile: widget.initialProfile,
          isEmbedded: true,
        ),
      );
    }

    final isVi = LanguageManager.isVi;

    final status = widget.initialProfile['status'] ?? 'PENDING_VERIFICATION';
    final adminNotes = widget.initialProfile['adminNotes'];

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildStatusIcon(status),
                const SizedBox(height: 28),
                Text(
                  _getStatusTitle(status, isVi),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _getStatusDescription(status, isVi),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    height: 1.5,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 24),

                // If rejected/revision needed, show admin feedback
                if (adminNotes != null && adminNotes.toString().isNotEmpty) ...[

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFDE68A)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.feedback_rounded, color: Color(0xFFD97706), size: 16),
                            const SizedBox(width: 8),
                            Text(
                              isVi ? 'Phản hồi từ Ban quản trị:' : 'Feedback from Administrator:',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF92400E),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          adminNotes.toString(),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFB45309),
                            height: 1.4,
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],

                // Action Buttons
                _buildActionButtons(context, status, isVi),
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
          // Logo
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
          // Sidebar menu items (Disabled during awaiting review except Logout)
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
                'Verification',
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
          InkWell(
            onTap: () {
              final isVi = LanguageManager.isVi;
              _showMyApplicationDialog(context, isVi);
            },
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(String status) {
    IconData icon;
    Color color;
    Color bgColor;

    if (status == 'AWAITING_APPROVAL') {
      icon = Icons.hourglass_empty_rounded;
      color = const Color(0xFFD97706);
      bgColor = const Color(0xFFFEF3C7);
    } else if (status == 'SUSPENDED') {
      icon = Icons.gavel_rounded;
      color = Colors.red;
      bgColor = const Color(0xFFFEE2E2);
    } else if (status == 'VERIFIED') {
      icon = Icons.check_circle_rounded;
      color = const Color(0xFF28B79B);
      bgColor = const Color(0xFFE6FDF9);
    } else {
      icon = Icons.edit_note_rounded;
      color = const Color(0xFF28B79B);
      bgColor = const Color(0xFFE6FDF9);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 48,
        color: color,
      ),
    );
  }

  String _getStatusTitle(String status, bool isVi) {
    final adminNotes = widget.initialProfile['adminNotes'];
    final hasEditsRequested = adminNotes != null && adminNotes.toString().trim().isNotEmpty;

    if (status == 'AWAITING_APPROVAL') {
      return isVi ? 'Hồ sơ đang được thẩm định' : 'Application Under Review';
    } else if (status == 'SUSPENDED') {
      return isVi ? 'Tài khoản bị tạm khóa' : 'Account Suspended';
    } else if (status == 'VERIFIED') {
      return isVi ? 'Hồ sơ đã được phê duyệt!' : 'Application Approved!';
    } else if (hasEditsRequested) {
      return isVi ? 'Hồ sơ cần cập nhật & bổ sung' : 'Application Revisions Requested';
    } else {
      return isVi ? 'Chưa hoàn thiện hồ sơ' : 'Incomplete Registration';
    }
  }

  String _getStatusDescription(String status, bool isVi) {
    final adminNotes = widget.initialProfile['adminNotes'];
    final hasEditsRequested = adminNotes != null && adminNotes.toString().trim().isNotEmpty;

    if (status == 'AWAITING_APPROVAL') {
      return isVi
          ? 'Hồ sơ của bạn đang được Ban quản trị thẩm định trong vòng 24h. Hệ thống đã tạm thời khóa sửa đổi thông tin để đối soát.'
          : 'Your application is currently under review by our admin team (usually takes up to 24h). Profile edits are temporarily locked.';
    } else if (status == 'SUSPENDED') {
      return isVi
          ? 'Tài khoản giảng dạy của bạn đã bị khóa do vi phạm các chính sách dịch vụ. Vui lòng liên hệ hỗ trợ: support@hango.edu.vn.'
          : 'Your trainer account has been suspended due to policy violations. Contact support@hango.edu.vn for assistance.';
    } else if (status == 'VERIFIED') {
      return isVi
          ? 'Chúc mừng! Hồ sơ giảng dạy của bạn đã được phê duyệt thành công. Vui lòng tiếp tục ký thỏa thuận hợp tác và thiết lập tài khoản thanh toán.'
          : 'Congratulations! Your application has been approved. Please proceed to sign the agreement and configure your payout details.';
    } else if (hasEditsRequested) {
      return isVi
          ? 'Đơn đăng ký của bạn đã bị từ chối phê duyệt và cần chỉnh sửa bổ sung. Vui lòng xem phản hồi từ Ban quản trị, cập nhật lại thông tin và nộp duyệt lại.'
          : 'Your trainer application was rejected and requires edits. Please review the feedback below, update your profile, and resubmit for review.';
    } else {
      return isVi
          ? 'Hồ sơ giáo viên của bạn chưa hoàn thiện. Hãy chỉnh sửa và cập nhật lại thông tin để gửi duyệt.'
          : 'Your profile is incomplete. Please edit and submit for review.';
    }
  }

  Widget _buildActionButtons(BuildContext context, String status, bool isVi) {
    final viewApplicationButton = OutlinedButton.icon(
      onPressed: () => _showMyApplicationDialog(context, isVi),
      icon: const Icon(Icons.description_outlined, size: 16),
      label: Text(isVi ? 'Xem đơn của tôi' : 'View My Application'),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0xFFCBD5E1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );

    final shellState = TrainerOnboardingShellPage.of(context);

    if (status == 'VERIFIED') {
      final agreementSigned = widget.initialProfile['agreementSigned'] ?? false;
      final bankAccount = widget.initialProfile['bankAccount'] ?? '';
      final trainerType = widget.initialProfile['trainerType'] ?? 'PROFESSIONAL';

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          viewApplicationButton,
          if (!agreementSigned)
            ElevatedButton.icon(
              onPressed: () {
                final nextPage = TrainerOnboardingAgreementPage(
                  profilePayload: widget.initialProfile,
                  trainerType: trainerType,
                  isEmbedded: true,
                );
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
              },
              icon: const Icon(Icons.draw_rounded, size: 16),
              label: Text(isVi ? 'Ký thỏa thuận' : 'Sign Agreement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            )
          else if (bankAccount.toString().trim().isEmpty)
            ElevatedButton.icon(
              onPressed: () {
                final nextPage = TrainerPayoutDetailsPage(
                  initialProfile: widget.initialProfile,
                  isEmbedded: true,
                );
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
              },
              icon: const Icon(Icons.account_balance_wallet_rounded, size: 16),
              label: Text(isVi ? 'Liên kết thanh toán' : 'Setup Payout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const TrainerDashboardPage()),
                );
              },
              icon: const Icon(Icons.dashboard_rounded, size: 16),
              label: Text(isVi ? 'Bảng điều khiển' : 'Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
        ],
      );
    }

    if (status == 'PENDING_VERIFICATION') {
      final agreementSigned = widget.initialProfile['agreementSigned'] ?? false;
      final trainerType = widget.initialProfile['trainerType'] ?? 'PROFESSIONAL';

      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          viewApplicationButton,
          ElevatedButton.icon(
            onPressed: () {
              final nextPage = (!agreementSigned)
                  ? TrainerOnboardingAgreementPage(
                      profilePayload: widget.initialProfile,
                      trainerType: trainerType,
                      isEmbedded: true,
                    )
                  : TrainerOnboardingDetailsPage(
                      initialProfile: widget.initialProfile,
                      isEmbedded: true,
                    );
              if (shellState != null) {
                shellState.updateBody(nextPage);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TrainerOnboardingShellPage(initialBody: nextPage),
                  ),
                );
              }
            },
            icon: Icon(!agreementSigned ? Icons.draw_rounded : Icons.edit_rounded, size: 16),
            label: Text(!agreementSigned
                ? (isVi ? 'Ký thỏa thuận' : 'Sign Agreement')
                : (isVi ? 'Chỉnh sửa hồ sơ' : 'Edit profile')),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28B79B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      child: viewApplicationButton,
    );
  }
}
