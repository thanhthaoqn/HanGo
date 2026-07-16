import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/language_manager.dart';
import '../../../../utils/file_picker_helper.dart';
import '../login_page.dart';
import 'trainer_courses_page.dart';
import 'trainer_dashboard_page.dart';
import 'question_bank/trainer_question_bank_page.dart';

class TrainerProfilePage extends StatefulWidget {
  const TrainerProfilePage({super.key});

  @override
  State<TrainerProfilePage> createState() => _TrainerProfilePageState();
}

class _TrainerProfilePageState extends State<TrainerProfilePage> {
  final _onboardingService = TrainerOnboardingService();
  final _authService = AuthService();

  bool _isLoading = true;
  bool _isSaving = false;
  Map<String, dynamic> _profileData = {};

  // Controllers & Form fields
  final _fullNameController = TextEditingController();
  final _phoneNumberController = TextEditingController();
  final _bioController = TextEditingController();
  final _workplaceController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  final _citizenIdController = TextEditingController();

  String _userEmail = '';
  String? _gender;
  String? _avatarUrl;
  String? _selectedBank;
  String _trainerType = 'PROFESSIONAL';

  String _trainerName = '';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  bool _isUploadingAvatar = false;

  // Degrees & Certificates
  String? _degreeUrl;
  String? _ieltsUrl;
  String? _scoreReportUrl;

  bool _isUploadingDegree = false;
  bool _isUploadingIelts = false;
  bool _isUploadingScoreReport = false;

  bool _fullNameError = false;
  bool _phoneNumberError = false;
  bool _bioError = false;
  bool _bankAccountError = false;
  bool _bankAccountNameError = false;
  bool _citizenIdError = false;

  final List<String> _bankSuggestions = [
    'Vietcombank (VCB)',
    'Techcombank (TCB)',
    'MB Bank (MB)',
    'VietinBank (CTG)',
    'BIDV (BID)',
    'Agribank (VBA)',
    'Sacombank (STB)',
    'TPBank (TPB)',
    'ACB (ACB)',
  ];

  @override
  void initState() {
    super.initState();
    _loadProfileAndHeader();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneNumberController.dispose();
    _bioController.dispose();
    _workplaceController.dispose();
    _bankAccountController.dispose();
    _bankAccountNameController.dispose();
    _citizenIdController.dispose();
    super.dispose();
  }

  Future<void> _loadProfileAndHeader() async {
    setState(() {
      _isLoading = true;
    });

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

    final result = await _onboardingService.getTrainerProfile();
    if (result['success'] == true) {
      final p = result['data'] ?? {};
      setState(() {
        _profileData = p;
        _fullNameController.text = p['fullName'] ?? fullName;
        _userEmail = p['email'] ?? '';
        _phoneNumberController.text = p['phoneNumber'] ?? '';
        _bioController.text = p['bio'] ?? '';
        _workplaceController.text = p['workplace'] ?? '';
        _degreeUrl = p['degreeUrl'];
        _ieltsUrl = p['ieltsUrl'];
        _scoreReportUrl = p['scoreReportUrl'];
        _avatarUrl = p['avatarUrl'] ?? avatarUrl;
        _gender = (p['gender'] == 'MALE' || p['gender'] == 'FEMALE') ? p['gender'] : null;
        _trainerType = p['trainerType'] ?? 'PROFESSIONAL';
        _selectedBank = p['bankName'];
        _bankAccountController.text = p['bankAccount'] ?? '';
        _bankAccountNameController.text = p['bankAccountName'] ?? '';
        _citizenIdController.text = p['citizenId'] ?? '';
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ToastHelper.showError(context, result['message'] ?? 'Không thể tải thông tin hồ sơ.');
      }
    }
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

  void _pickAndUploadAvatar() async {
    try {
      final picked = await pickImage();
      if (picked == null) return;

      setState(() {
        _isUploadingAvatar = true;
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
          _avatarUrl = uploadedUrl;
          _isUploadingAvatar = false;
          _trainerAvatarUrl = uploadedUrl;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_avatar_url', uploadedUrl);

        if (mounted) {
          ToastHelper.showSuccess(context, 'Tải lên ảnh đại diện thành công!');
        }
      } else {
        throw Exception('Cloudinary error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isUploadingAvatar = false;
      });
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi tải ảnh: $e');
      }
    }
  }

  bool _validateFields() {
    final isVi = LanguageManager.isVi;
    final fullName = _fullNameController.text.trim();
    final phoneNumber = _phoneNumberController.text.trim();
    final bio = _bioController.text.trim();
    final bankAccount = _bankAccountController.text.trim();
    final bankAccountName = _bankAccountNameController.text.trim();
    final citizenId = _citizenIdController.text.trim();

    final numRegex = RegExp(r'^\d+$');
    final nameRegex = RegExp(r'^[A-Z ]+$');

    setState(() {
      _fullNameError = fullName.isEmpty;
      _phoneNumberError = phoneNumber.isEmpty || phoneNumber.length != 10 || !numRegex.hasMatch(phoneNumber);
      _bioError = bio.isEmpty || bio.length < 50;
      _bankAccountError = bankAccount.isNotEmpty && !numRegex.hasMatch(bankAccount);
      _bankAccountNameError = bankAccountName.isNotEmpty && !nameRegex.hasMatch(bankAccountName);
      _citizenIdError = citizenId.isNotEmpty && (citizenId.length != 12 || !numRegex.hasMatch(citizenId));
    });

    if (_fullNameError) {
      ToastHelper.showError(context, isVi ? 'Vui lòng nhập họ và tên.' : 'Please enter full name.');
      return false;
    }
    if (_phoneNumberError) {
      ToastHelper.showError(context, isVi ? 'Số điện thoại không hợp lệ (10 chữ số).' : 'Invalid phone number (10 digits).');
      return false;
    }
    if (_bioError) {
      ToastHelper.showError(context, isVi ? 'Giới thiệu bản thân cần tối thiểu 50 ký tự.' : 'Bio must be at least 50 characters.');
      return false;
    }
    if (_gender == null) {
      ToastHelper.showError(context, isVi ? 'Vui lòng chọn giới tính.' : 'Please select gender.');
      return false;
    }
    if (_bankAccountError) {
      ToastHelper.showError(context, isVi ? 'Số tài khoản ngân hàng chỉ được phép chứa ký tự số.' : 'Bank account digits only.');
      return false;
    }
    if (_bankAccountNameError) {
      ToastHelper.showError(context, isVi ? 'Tên chủ tài khoản viết hoa không dấu.' : 'Owner name must be UPPERCASE.');
      return false;
    }
    if (_citizenIdError) {
      ToastHelper.showError(context, isVi ? 'Số CCCD phải gồm đúng 12 chữ số.' : 'Citizen ID must be 12 digits.');
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

  void _handleSave() async {
    if (!_validateFields()) return;

    setState(() {
      _isSaving = true;
    });

    final payload = Map<String, dynamic>.from(_profileData);
    payload['fullName'] = _fullNameController.text.trim();
    payload['phoneNumber'] = _phoneNumberController.text.trim();
    payload['bio'] = _bioController.text.trim();
    payload['workplace'] = _workplaceController.text.trim();
    payload['gender'] = _gender;
    payload['avatarUrl'] = _avatarUrl ?? '';
    payload['bankName'] = _selectedBank ?? '';
    payload['bankAccount'] = _bankAccountController.text.trim();
    payload['bankAccountName'] = _bankAccountNameController.text.trim().toUpperCase();
    payload['degreeUrl'] = _degreeUrl ?? '';
    payload['ieltsUrl'] = _ieltsUrl ?? '';
    payload['scoreReportUrl'] = _scoreReportUrl ?? '';
    payload['citizenId'] = _citizenIdController.text.trim();

    debugPrint('[TrainerProfile] Saving draft payload: $payload');
    final result = await _onboardingService.saveProfileDraft(payload);
    debugPrint('[TrainerProfile] Save result: $result');

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        // Sync shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_fullname', _fullNameController.text.trim());
        if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
          await prefs.setString('user_avatar_url', _avatarUrl!);
        }
        await prefs.setString('user_phone', _phoneNumberController.text.trim());
        if (_gender != null) {
          await prefs.setString('user_gender', _gender!);
        }

        setState(() {
          _trainerName = _fullNameController.text.trim();
          _trainerAvatarUrl = _avatarUrl ?? '';
        });

        ToastHelper.showSuccess(
          context,
          LanguageManager.isVi ? 'Cập nhật hồ sơ thành công!' : 'Profile updated successfully!',
        );
      } else {
        ToastHelper.showError(context, result['message'] ?? 'Cập nhật thất bại.');
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
                  child: _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF20B486)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Center(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isVi ? 'Hồ sơ của tôi' : 'My Profile',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0F172A),
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Avatar Card
                                  _buildAvatarCard(isVi),
                                  const SizedBox(height: 24),

                                  // Form Body
                                  _buildFormFields(isVi),
                                  const SizedBox(height: 32),

                                  // Save Button
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: _isSaving ? null : _handleSave,
                                        icon: _isSaving
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                              )
                                            : const Icon(Icons.save_rounded, size: 18),
                                        label: Text(isVi ? 'Lưu thay đổi' : 'Save Changes'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF20B486),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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

  Widget _buildAvatarCard(bool isVi) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF20B486), width: 2),
                  color: const Color(0xFFF1F5F9),
                ),
                child: ClipOval(
                  child: _isUploadingAvatar
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF20B486)))
                      : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                          ? Image.network(_avatarUrl!, fit: BoxFit.cover)
                          : const Icon(Icons.person_rounded, size: 56, color: Color(0xFF94A3B8))),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _isUploadingAvatar ? null : _pickAndUploadAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF20B486),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _trainerName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 6),
                Text(
                  _userEmail,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6FDF9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _trainerType == 'PROFESSIONAL'
                        ? (isVi ? 'Giáo viên Chuyên nghiệp' : 'Professional')
                        : (isVi ? 'Gia sư / Trợ giảng' : 'Peer Tutor'),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF20B486), fontFamily: 'Outfit'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields(bool isVi) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Part 1: Info
          const Text(
            '1. Thông tin cá nhân & Giảng dạy',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 20),
          _buildInputField(isVi ? 'Họ và tên *' : 'Full Name *', _fullNameController, errorText: _fullNameError ? (isVi ? 'Họ tên không được trống' : 'Name required') : null),
          const SizedBox(height: 16),
          _buildReadOnlyField(isVi ? 'Email liên hệ' : 'Email Address', _userEmail),
          const SizedBox(height: 16),

          // Gender selection
          Text(
            isVi ? 'Giới tính *' : 'Gender *',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155), fontFamily: 'Outfit'),
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
            },
          ),
          const SizedBox(height: 16),

          _buildInputField(isVi ? 'Số điện thoại *' : 'Phone Number *', _phoneNumberController, keyboardType: TextInputType.phone, errorText: _phoneNumberError ? (isVi ? 'Số điện thoại không hợp lệ' : 'Invalid phone') : null),
          const SizedBox(height: 16),
          _buildInputField(isVi ? 'Nơi làm việc' : 'Workplace', _workplaceController),
          const SizedBox(height: 16),
          _buildInputField(
            isVi ? 'Giới thiệu bản thân & Kinh nghiệm *' : 'Bio & Experience *',
            _bioController,
            maxLines: 5,
            errorText: _bioError ? (isVi ? 'Giới thiệu cần từ 50 ký tự' : 'Bio must be >= 50 characters') : null,
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Part 2: Payout Settings
          const Text(
            '2. Cấu hình Tài khoản thụ hưởng',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 20),

          // Bank Selector
          Text(
            isVi ? 'Ngân hàng thụ hưởng' : 'Beneficiary Bank',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155), fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBank,
                isExpanded: true,
                hint: Text(isVi ? 'Chọn ngân hàng' : 'Select bank'),
                items: _bankSuggestions.map((String b) {
                  return DropdownMenuItem<String>(
                    value: b,
                    child: Text(b),
                  );
                }).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedBank = val;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          _buildInputField(isVi ? 'Số tài khoản ngân hàng' : 'Bank Account Number', _bankAccountController, keyboardType: TextInputType.number, errorText: _bankAccountError ? (isVi ? 'Chỉ nhập số' : 'Digits only') : null),
          const SizedBox(height: 16),
          _buildInputField(
            isVi ? 'Tên chủ tài khoản (viết hoa không dấu)' : 'Account Owner Name',
            _bankAccountNameController,
            errorText: _bankAccountNameError ? (isVi ? 'Viết hoa không dấu' : 'UPPERCASE only') : null,
            onChanged: (val) {
              _bankAccountNameController.value = _bankAccountNameController.value.copyWith(
                text: val.toUpperCase(),
                selection: TextSelection.collapsed(offset: val.length),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildInputField(isVi ? 'Số Căn cước công dân (CCCD - 12 chữ số)' : 'Citizen ID (CCCD)', _citizenIdController, keyboardType: TextInputType.number, maxLength: 12, errorText: _citizenIdError ? (isVi ? 'CCCD gồm đúng 12 số' : '12 digits required') : null),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // Part 3: Credentials Proofs
          Text(
            isVi ? '3. Bằng cấp & Chứng chỉ năng lực' : '3. Degrees & Certificates',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 8),
          Text(
            isVi ? 'Tải lên ít nhất một tài liệu chứng minh năng lực để lưu hồ sơ.' : 'Upload at least one credentials proof to save profile.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          _buildUnifiedUploadBox(isVi),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {TextInputType? keyboardType, int maxLines = 1, int? maxLength, String? errorText, ValueChanged<String>? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: onChanged,
          decoration: InputDecoration(
            errorText: errorText,
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            fillColor: const Color(0xFFF8FAFC),
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyField(String label, String val) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Text(
            val,
            style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
          ),
        ),
      ],
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
          _buildSidebarItem(Icons.dashboard_outlined, isVi ? 'Bảng điều khiển' : 'Dashboard', onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerDashboardPage()),
            );
          }),
          _buildSidebarItem(Icons.book_outlined, isVi ? 'Khóa học' : 'Courses', onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerCoursesPage()),
            );
          }),
          _buildSidebarItem(Icons.assignment_outlined, isVi ? 'Đề thi' : 'Exam'),
          _buildSidebarItem(Icons.people_outline, isVi ? 'Học sinh' : 'Learner'),
          _buildSidebarItem(Icons.question_answer_outlined, isVi ? 'Ngân hàng câu hỏi' : 'Question Bank', onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerQuestionBankPage()),
            );
          }),
          _buildSidebarItem(Icons.person_outline, isVi ? 'Hồ sơ của tôi' : 'My Profile', isActive: true),
          const Spacer(),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _buildSidebarItem(Icons.logout, isVi ? 'Đăng xuất' : 'Logout', color: Colors.redAccent, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, {bool isActive = false, Color? color, VoidCallback? onTap}) {
    final activeColor = const Color(0xFF20B486);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap ?? () {},
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
                color: isActive ? Colors.white : (color ?? const Color(0xFF4B5563)),
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : (color ?? const Color(0xFF1F2937)),
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
                'My Profile',
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
          MouseRegion(
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
        ],
      ),
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
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
                                  child: Image.network(item['url']!, fit: BoxFit.contain),
                                ),
                              ),
                            );
                          },
                          child: Image.network(
                            item['url']!,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.insert_drive_file_outlined, color: Color(0xFF94A3B8)),
                          ),
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
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    child: Container(
                                      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
                                      child: Image.network(item['url']!, fit: BoxFit.contain),
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                isVi ? 'Xem ảnh chứng chỉ' : 'View certificate image',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF20B486), decoration: TextDecoration.underline),
                              ),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF20B486)),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.cloud_upload_outlined, color: Color(0xFF20B486), size: 24),
                            const SizedBox(width: 12),
                            Text(
                              isVi ? 'Nhấp để tải lên tài liệu minh chứng' : 'Click to upload credential',
                              style: const TextStyle(color: Color(0xFF20B486), fontWeight: FontWeight.bold, fontSize: 13),
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

  void _pickAndUpload(String targetDoc) async {
    try {
      final picked = await pickImage();
      if (picked == null) return;

      setState(() {
        if (targetDoc == 'degree') _isUploadingDegree = true;
        if (targetDoc == 'ielts') _isUploadingIelts = true;
        if (targetDoc == 'score') _isUploadingScoreReport = true;
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
        });
        if (mounted) {
          ToastHelper.showSuccess(context, 'Tải lên tài liệu thành công!');
        }
      } else {
        throw Exception('Cloudinary error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isUploadingDegree = false;
        _isUploadingIelts = false;
        _isUploadingScoreReport = false;
      });
      if (mounted) {
        ToastHelper.showError(context, 'Tải ảnh lên thất bại: $e');
      }
    }
  }
}
