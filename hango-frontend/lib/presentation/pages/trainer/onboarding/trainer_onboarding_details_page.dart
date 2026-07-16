import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/language_manager.dart';
import '../../../../utils/file_picker_helper.dart';
import '../../../widgets/shared_header.dart';
import '../../../widgets/shared_footer.dart';
import 'trainer_onboarding_status_page.dart';
import '../../login_page.dart';

class TrainerOnboardingDetailsPage extends StatefulWidget {
  final Map<String, dynamic> initialProfile;

  const TrainerOnboardingDetailsPage({super.key, required this.initialProfile});

  @override
  State<TrainerOnboardingDetailsPage> createState() => _TrainerOnboardingDetailsPageState();
}

class _TrainerOnboardingDetailsPageState extends State<TrainerOnboardingDetailsPage> {
  final _onboardingService = TrainerOnboardingService();
  final _authService = AuthService();

  bool _isLoading = false;
  bool _isSavingDraft = false;
  String _saveDraftText = '';
  Timer? _debounceTimer;

  // Form Fields
  final _bioController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  String _userEmail = '';
  String _userFullName = '';

  // Credentials Proofs
  String? _degreeUrl;
  String? _ieltsUrl;
  String? _scoreReportUrl;

  bool _isUploadingDegree = false;
  bool _isUploadingIelts = false;
  bool _isUploadingScoreReport = false;

  // Validation States
  bool _bioError = false;
  bool _phoneNumberError = false;

  // Avatar & Gender Onboarding Fields
  String? _avatarUrl;
  String? _gender;
  bool _isUploadingAvatar = false;

  // Header Info
  String _trainerName = '';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  @override
  void initState() {
    super.initState();
    _populateFields(widget.initialProfile);
    _loadUserAccountInfo();
    _loadTrainerHeaderInfo();
  }

  void _populateFields(Map<String, dynamic> p) {
    _bioController.text = p['bio'] ?? '';
    _degreeUrl = p['degreeUrl'];
    _ieltsUrl = p['ieltsUrl'];
    _scoreReportUrl = p['scoreReportUrl'];
    _avatarUrl = p['avatarUrl'];
    _gender = p['gender'];
  }

  Future<void> _loadUserAccountInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_fullname') ?? '';
      final email = prefs.getString('user_email') ?? '';
      final phone = prefs.getString('user_phone') ?? '';
      final gender = prefs.getString('user_gender');
      final avatar = prefs.getString('user_avatar_url') ?? '';
      setState(() {
        _userFullName = name;
        _userEmail = email;
        if (_phoneNumberController.text.isEmpty) {
          _phoneNumberController.text = phone;
        }
        if (_gender == null) {
          _gender = (gender == 'MALE' || gender == 'FEMALE') ? gender : null;
        }
        if (_avatarUrl == null || _avatarUrl!.isEmpty) {
          _avatarUrl = avatar;
        }
      });
    } catch (e) {
      debugPrint('Error loading user account info: $e');
    }
  }

  void _syncSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (_phoneNumberController.text.trim().isNotEmpty) {
      await prefs.setString('user_phone', _phoneNumberController.text.trim());
    }
    if (_gender != null) {
      await prefs.setString('user_gender', _gender!);
    }
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      await prefs.setString('user_avatar_url', _avatarUrl!);
    }
  }

  void _updateLocalAvatar(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_avatar_url', url);
    _loadTrainerHeaderInfo();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _bioController.dispose();
    _phoneNumberController.dispose();
    super.dispose();
  }

  void _triggerAutoSave() {
    setState(() {
      _saveDraftText = LanguageManager.isVi ? 'Đang lưu bản nháp...' : 'Saving draft...';
      _isSavingDraft = true;
    });

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 1000), () async {
      final draft = _buildPayload();
      final result = await _onboardingService.saveProfileDraft(draft);
      if (mounted) {
        setState(() {
          _isSavingDraft = false;
          if (result['success'] == true) {
            _saveDraftText = LanguageManager.isVi ? '✓ Đã tự động lưu nháp' : '✓ Draft auto-saved';
            _syncSharedPreferences();
          } else {
            _saveDraftText = LanguageManager.isVi ? 'Lưu nháp thất bại' : 'Save draft failed';
          }
        });
      }
    });
  }

  Map<String, dynamic> _buildPayload() {
    return {
      'trainerType': widget.initialProfile['trainerType'] ?? 'PROFESSIONAL',
      'bio': _bioController.text.trim(),
      'phoneNumber': _phoneNumberController.text.trim(),
      'degreeUrl': _degreeUrl ?? '',
      'ieltsUrl': _ieltsUrl ?? '',
      'scoreReportUrl': _scoreReportUrl ?? '',
      'gender': _gender ?? '',
      'avatarUrl': _avatarUrl ?? '',
    };
  }

  Future<void> _pickAndUpload(String targetDoc) async {
    try {
      final picked = await pickImage();
      if (picked == null) return;

      setState(() {
        if (targetDoc == 'degree') _isUploadingDegree = true;
        if (targetDoc == 'ielts') _isUploadingIelts = true;
        if (targetDoc == 'score') _isUploadingScoreReport = true;
        if (targetDoc == 'avatar') _isUploadingAvatar = true;
      });

      final url = Uri.parse('https://api.cloudinary.com/v1_1/diqekap4o/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'hango_preset'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          picked.bytes,
          filename: picked.name,
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        final uploadedUrl = data['secure_url'] ?? data['url'];

        setState(() {
          if (targetDoc == 'degree') {
            _degreeUrl = uploadedUrl;
            _isUploadingDegree = false;
          }
          if (targetDoc == 'ielts') {
            _ieltsUrl = uploadedUrl;
            _isUploadingIelts = false;
          }
          if (targetDoc == 'score') {
            _scoreReportUrl = uploadedUrl;
            _isUploadingScoreReport = false;
          }
          if (targetDoc == 'avatar') {
            _avatarUrl = uploadedUrl;
            _isUploadingAvatar = false;
            _updateLocalAvatar(uploadedUrl);
          }
        });
        _triggerAutoSave();
        if (mounted) {
          ToastHelper.showSuccess(context, 'Tải lên thành công!');
        }
      } else {
        throw Exception('Cloudinary returned status code ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isUploadingDegree = false;
        _isUploadingIelts = false;
        _isUploadingScoreReport = false;
        _isUploadingAvatar = false;
      });
      if (mounted) {
        ToastHelper.showError(context, 'Tải ảnh lên thất bại: $e');
      }
    }
  }

  bool _validateFields() {
    final isVi = LanguageManager.isVi;
    final bio = _bioController.text.trim();
    final phoneNumber = _phoneNumberController.text.trim();

    final numRegex = RegExp(r'^\d+$');

    setState(() {
      _bioError = bio.isEmpty || bio.length < 50;
      _phoneNumberError = phoneNumber.isEmpty || phoneNumber.length != 10 || !numRegex.hasMatch(phoneNumber);
    });

    if (_bioError) {
      ToastHelper.showError(
        context,
        isVi
            ? 'Thông tin kinh nghiệm giảng dạy (Bio) cần tối thiểu 50 ký tự.'
            : 'Biography/Experience must be at least 50 characters long.',
      );
      return false;
    }
    if (_phoneNumberError) {
      ToastHelper.showError(
        context,
        isVi ? 'Số điện thoại liên hệ phải có đúng 10 chữ số.' : 'Phone number must be exactly 10 digits.',
      );
      return false;
    }

    if (_gender == null) {
      ToastHelper.showError(
        context,
        isVi ? 'Vui lòng chọn giới tính.' : 'Please select your gender.',
      );
      return false;
    }

    if (_avatarUrl == null || _avatarUrl!.isEmpty) {
      ToastHelper.showError(
        context,
        isVi ? 'Vui lòng tải lên ảnh đại diện.' : 'Please upload an avatar image.',
      );
      return false;
    }

    final hasProof = (_degreeUrl != null && _degreeUrl!.isNotEmpty) ||
        (_ieltsUrl != null && _ieltsUrl!.isNotEmpty) ||
        (_scoreReportUrl != null && _scoreReportUrl!.isNotEmpty);

    if (!hasProof) {
      ToastHelper.showError(
        context,
        isVi
            ? 'Vui lòng tải lên ít nhất một bằng cấp hoặc chứng chỉ năng lực.'
            : 'Please upload at least one credentials proof.',
      );
      return false;
    }

    return true;
  }

  void _handleSubmit() async {
    if (!_validateFields()) return;

    setState(() {
      _isLoading = true;
    });

    final payload = _buildPayload();
    await _onboardingService.saveProfileDraft(payload);
    final result = await _onboardingService.submitProfile(payload);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        _syncSharedPreferences();
        ToastHelper.showSuccess(
          context,
          LanguageManager.isVi
              ? 'Hồ sơ đã được gửi duyệt thành công!'
              : 'Application submitted successfully!',
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (context) => TrainerOnboardingStatusPage(initialProfile: result['data']),
          ),
          (route) => false,
        );
      } else {
        ToastHelper.showError(context, result['message'] ?? 'Lỗi gửi duyệt hồ sơ.');
      }
    }
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
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  isVi ? 'Hoàn thiện hồ sơ giảng dạy' : 'Complete Teaching Profile',
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                if (_isSavingDraft)
                                  Text(
                                    _saveDraftText,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF28B79B), fontStyle: FontStyle.italic),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            _buildFormBody(isVi),
                            const SizedBox(height: 40),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _isLoading ? null : _handleSubmit,
                                  icon: _isLoading
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : const Icon(Icons.send_rounded, size: 16),
                                  label: Text(isVi ? 'Gửi duyệt hồ sơ' : 'Submit Profile'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF28B79B),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
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
                'Verification / Application Details',
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
          PopupMenuButton<String>(
            tooltip: 'Profile Menu',
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            offset: const Offset(0, 48),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
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
            itemBuilder: (BuildContext context) {
              final isVi = LanguageManager.isVi;
              return [
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, size: 18, color: Colors.redAccent),
                      const SizedBox(width: 8),
                      Text(isVi ? 'Đăng xuất' : 'Logout', style: const TextStyle(color: Colors.redAccent)),
                    ],
                  ),
                ),
              ];
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFormBody(bool isVi) {
    final adminNotes = widget.initialProfile['adminNotes'];
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (adminNotes != null && adminNotes.toString().trim().isNotEmpty) ...[
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
                      const Icon(Icons.feedback_rounded, color: Color(0xFFD97706), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        isVi ? 'Phản hồi sửa đổi từ Ban quản trị:' : 'Feedback from Administrator:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
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
            const SizedBox(height: 24),
          ],
          // Avatar Upload Circle Selector
          Center(
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF28B79B), width: 2),
                    color: const Color(0xFFF1F5F9),
                  ),
                  child: ClipOval(
                    child: _isUploadingAvatar
                        ? const Center(child: CircularProgressIndicator(color: Color(0xFF28B79B)))
                        : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                            ? Image.network(_avatarUrl!, fit: BoxFit.cover)
                            : const Icon(Icons.person_rounded, size: 64, color: Color(0xFF94A3B8))),
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: InkWell(
                    onTap: _isUploadingAvatar ? null : () => _pickAndUpload('avatar'),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFF28B79B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Section 1: Personal Info
          _buildSectionHeader(Icons.person_outline_rounded, isVi ? '1. Thông tin cá nhân' : '1. Personal Information'),
          const SizedBox(height: 20),
          _buildReadOnlyField(isVi ? 'Họ và tên' : 'Full Name', _userFullName),
          const SizedBox(height: 16),
          _buildReadOnlyField(isVi ? 'Email' : 'Email Address', _userEmail),
          const SizedBox(height: 16),

          // Gender selection
          Text(
            isVi ? 'Giới tính *' : 'Gender *',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF334155),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _gender,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              fillColor: const Color(0xFFF8FAFC),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF28B79B), width: 2),
              ),
            ),
            hint: Text(isVi ? 'Chọn giới tính' : 'Select gender'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
            items: [
              DropdownMenuItem(value: 'MALE', child: Text(isVi ? 'Nam' : 'Male')),
              DropdownMenuItem(value: 'FEMALE', child: Text(isVi ? 'Nữ' : 'Female')),
            ],
            onChanged: (val) {
              setState(() {
                _gender = val;
              });
              _triggerAutoSave();
            },
          ),
          const SizedBox(height: 16),

          _buildTextField(
            label: isVi ? 'Số điện thoại liên hệ *' : 'Contact Phone Number *',
            controller: _phoneNumberController,
            errorText: _phoneNumberError ? (isVi ? 'Số điện thoại phải có đúng 10 số' : 'Phone number must be 10 digits') : null,
            hintText: '0912345678',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 24),

          // Section 2: Experience & Bio
          _buildSectionHeader(Icons.work_outline_rounded, isVi ? '2. Kinh nghiệm giảng dạy' : '2. Experience & Bio'),
          const SizedBox(height: 20),
          _buildTextField(
            label: isVi ? 'Kinh nghiệm giảng dạy & Giới thiệu bản thân (Bio) *' : 'Teaching Experience & Bio *',
            controller: _bioController,
            errorText: _bioError ? (isVi ? 'Giới thiệu cần tối thiểu 50 ký tự' : 'Bio must be at least 50 characters') : null,
            hintText: isVi ? 'Mô tả kinh nghiệm, phương pháp dạy và các thành tích của bạn...' : 'Describe your teaching style, history, credentials...',
            maxLines: 5,
          ),
          const SizedBox(height: 24),

          // Section 3: Credentials Proofs
          _buildSectionHeader(Icons.verified_outlined, isVi ? '3. Bằng cấp & Chứng chỉ năng lực' : '3. Degrees & Certificates'),
          const SizedBox(height: 8),
          Text(
            isVi ? 'Tải lên ít nhất một tài liệu chứng minh năng lực để được xét duyệt.' : 'Upload at least one credentials proof to unlock review.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          _buildUnifiedUploadBox(isVi),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF28B79B), size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            value.isNotEmpty ? value : '...',
            style: const TextStyle(fontSize: 14, color: Color(0xFF475569)),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? errorText,
    required String hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: (_) {
            _triggerAutoSave();
          },
          decoration: InputDecoration(
            errorText: errorText,
            hintText: hintText,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUnifiedUploadBox(bool isVi) {
    final list = <Map<String, String>>[];
    if (_degreeUrl != null && _degreeUrl!.isNotEmpty) {
      list.add({'type': 'degree', 'url': _degreeUrl!, 'label': isVi ? 'Tài liệu minh chứng 1' : 'Credential 1'});
    }
    if (_ieltsUrl != null && _ieltsUrl!.isNotEmpty) {
      list.add({'type': 'ielts', 'url': _ieltsUrl!, 'label': isVi ? 'Tài liệu minh chứng 2' : 'Credential 2'});
    }
    if (_scoreReportUrl != null && _scoreReportUrl!.isNotEmpty) {
      list.add({'type': 'score', 'url': _scoreReportUrl!, 'label': isVi ? 'Tài liệu minh chứng 3' : 'Credential 3'});
    }

    final isFull = list.length >= 3;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVi ? 'Danh sách tài liệu đã tải lên' : 'Uploaded Documents',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 13),
          ),
          const SizedBox(height: 12),
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  isVi ? 'Chưa có tài liệu nào được tải lên.' : 'No documents uploaded yet.',
                  style: const TextStyle(color: Color(0xFF64748B), fontStyle: FontStyle.italic, fontSize: 12),
                ),
              ),
            )
          else
            Column(
              children: list.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          item['url']!,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF94A3B8)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item['label']!,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item['url']!.split('/').last,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                        onPressed: () {
                          setState(() {
                            if (item['type'] == 'degree') _degreeUrl = null;
                            if (item['type'] == 'ielts') _ieltsUrl = null;
                            if (item['type'] == 'score') _scoreReportUrl = null;
                          });
                          _triggerAutoSave();
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          if (!isFull) ...[
            const SizedBox(height: 12),
            InkWell(
              onTap: (_isUploadingDegree || _isUploadingIelts || _isUploadingScoreReport)
                  ? null
                  : () {
                      if (_degreeUrl == null || _degreeUrl!.isEmpty) {
                        _pickAndUpload('degree');
                      } else if (_ieltsUrl == null || _ieltsUrl!.isEmpty) {
                        _pickAndUpload('ielts');
                      } else if (_scoreReportUrl == null || _scoreReportUrl!.isEmpty) {
                        _pickAndUpload('score');
                      }
                    },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                height: 80,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                ),
                child: Center(
                  child: (_isUploadingDegree || _isUploadingIelts || _isUploadingScoreReport)
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF28B79B)),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_outlined, color: Color(0xFF28B79B), size: 24),
                            const SizedBox(width: 12),
                            Text(
                              isVi ? 'Nhấp để tải lên tài liệu minh chứng' : 'Click to upload credential',
                              style: const TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
