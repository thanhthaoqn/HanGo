import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
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
import 'trainer_onboarding_shell_page.dart';
import '../../login_page.dart';

class TrainerOnboardingDetailsPage extends StatefulWidget {
  final Map<String, dynamic> initialProfile;
  final bool isEmbedded;

  const TrainerOnboardingDetailsPage({
    super.key,
    required this.initialProfile,
    this.isEmbedded = false,
  });

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

  // Credentials Proofs (Dynamic unlimited list)
  List<Map<String, String>> _certificates = [];

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

  bool _isValidPhoneNumber(String? phone) {
    if (phone == null) return false;
    final trimmed = phone.trim();
    if (trimmed.isEmpty) return false;
    final vnPhoneRegex = RegExp(r'^(03|05|07|08|09)\d{8}$');
    final isDummyNumber = RegExp(r'^(\d)\1{9}$').hasMatch(trimmed) || trimmed == '1234567890';
    return vnPhoneRegex.hasMatch(trimmed) && !isDummyNumber;
  }

  void _populateFields(Map<String, dynamic> p) {
    _bioController.text = p['bio'] ?? '';
    _avatarUrl = p['avatarUrl'];
    _gender = p['gender'];

    final rawPhone = p['phoneNumber']?.toString();
    if (_isValidPhoneNumber(rawPhone)) {
      _phoneNumberController.text = rawPhone!.trim();
    } else {
      _phoneNumberController.clear();
    }

    _certificates.clear();
    if (p['certificates'] != null && p['certificates'] is List) {
      _certificates = (p['certificates'] as List)
          .map((item) => Map<String, String>.from(item as Map))
          .toList();
    } else {
      if (p['degreeUrl'] != null && p['degreeUrl'].toString().isNotEmpty) {
        _certificates.add({'name': 'Degree / Qualification Certificate', 'url': p['degreeUrl'].toString()});
      }
      if (p['ieltsUrl'] != null && p['ieltsUrl'].toString().isNotEmpty) {
        _certificates.add({'name': 'IELTS / Language Proficiency Certificate', 'url': p['ieltsUrl'].toString()});
      }
      if (p['scoreReportUrl'] != null && p['scoreReportUrl'].toString().isNotEmpty) {
        final raw = p['scoreReportUrl'].toString();
        if (raw.startsWith('[')) {
          try {
            final List parsed = jsonDecode(raw);
            _certificates = parsed.map((item) => Map<String, String>.from(item as Map)).toList();
          } catch (_) {
            _certificates.add({'name': 'Score Report / Other Credential', 'url': raw});
          }
        } else {
          _certificates.add({'name': 'Score Report / Other Credential', 'url': raw});
        }
      }
    }
  }

  Future<void> _loadUserAccountInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_fullname') ?? '';
      final email = prefs.getString('user_email') ?? '';
      final phone = prefs.getString('user_phone') ?? '';
      final gender = prefs.getString('user_gender');
      final avatar = prefs.getString('user_avatar_url') ?? '';
      if (!_isValidPhoneNumber(phone)) {
        await prefs.remove('user_phone');
      }
      setState(() {
        _userFullName = name;
        _userEmail = email;
        if (_phoneNumberController.text.isEmpty && _isValidPhoneNumber(phone)) {
          _phoneNumberController.text = phone.trim();
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
    final phone = _phoneNumberController.text.trim();
    if (_isValidPhoneNumber(phone)) {
      await prefs.setString('user_phone', phone);
    } else {
      await prefs.remove('user_phone');
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
    final score = _certificates.isNotEmpty ? jsonEncode(_certificates) : '';

    return {
      'trainerType': widget.initialProfile['trainerType'] ?? 'PROFESSIONAL',
      'bio': _bioController.text.trim(),
      'phoneNumber': _phoneNumberController.text.trim(),
      'scoreReportUrl': score,
      'certificates': _certificates,
      'gender': _gender ?? '',
      'avatarUrl': _avatarUrl ?? '',
    };
  }

  Future<Map<String, String>?> _uploadFileToCloudinaryWithDetails() async {
    try {
      final picked = await pickImage();
      if (picked == null || picked.bytes == null) return null;

      final url = Uri.parse('https://api.cloudinary.com/v1_1/diqekap4o/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'hango_preset'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          picked.bytes!,
          filename: picked.name,
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        return {
          'url': (data['secure_url'] ?? data['url']).toString(),
          'fileName': picked.name,
        };
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
    }
    return null;
  }

  Future<void> _pickAndUpload(String targetDoc) async {
    try {
      final res = await _uploadFileToCloudinaryWithDetails();
      if (res != null && res['url'] != null) {
        setState(() {
          if (targetDoc == 'avatar') {
            _avatarUrl = res['url'];
            _isUploadingAvatar = false;
            _updateLocalAvatar(res['url']!);
          }
        });
        _triggerAutoSave();
        if (mounted) {
          ToastHelper.showSuccess(context, LanguageManager.isVi ? 'Tải lên avatar thành công!' : 'Avatar uploaded successfully!');
        }
      }
    } catch (e) {
      setState(() {
        _isUploadingAvatar = false;
      });
    }
  }

  String _extractSmartTitle(String filename) {
    final lower = filename.toLowerCase().replaceAll(RegExp(r'[_-]'), ' ');

    if (lower.contains('ielts')) {
      return 'IELTS Academic Certificate';
    } else if (lower.contains('toeic')) {
      return 'TOEIC Official Certificate';
    } else if (lower.contains('toefl')) {
      return 'TOEFL iBT Certificate';
    } else if (lower.contains('tefl')) {
      return 'TEFL International Certification';
    } else if (lower.contains('tesol') || lower.contains('celta')) {
      return 'TESOL / CELTA Teaching Certificate';
    } else if (lower.contains('su pham') || lower.contains('supham') || lower.contains('pedagog')) {
      return 'Bachelor of English Pedagogy Degree';
    } else if (lower.contains('giang day') || lower.contains('giangday') || lower.contains('teaching')) {
      return 'TEFL / TESOL Teaching Certificate';
    } else if (lower.contains('vstep') ||
        lower.contains('proficiency') ||
        lower.contains('ngoai ngu') ||
        lower.contains('ngoaingu') ||
        lower.contains('tieng anh') ||
        lower.contains('tienganh') ||
        lower.contains('aptis') ||
        lower.contains('cambridge') ||
        lower.contains('cefr')) {
      return 'Certificate of English Language Proficiency';
    } else if (lower.contains('hoc ba') || lower.contains('hocba') || lower.contains('transcript')) {
      return 'High School Academic Transcript';
    } else if (lower.contains('bang cap') || lower.contains('bangcap') || lower.contains('degree') || lower.contains('cu nhan') || lower.contains('cunhan') || lower.contains('dai hoc') || lower.contains('daihoc')) {
      return 'Bachelor Degree Certificate';
    }

    return 'Certificate of English Language Proficiency';
  }

  void _showAddCertificateModal(bool isVi) {
    final nameController = TextEditingController();
    String? tempUrl;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              clipBehavior: Clip.antiAlias,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                constraints: const BoxConstraints(maxWidth: 550),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isVi ? 'Thêm chứng chỉ / Bằng cấp' : 'Add Degree & Certificate',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isVi ? 'Tên chứng chỉ / Bằng cấp *' : 'Certificate / Degree Name *',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      onChanged: (_) => setModalState(() {}),
                      decoration: InputDecoration(
                        hintText: isVi ? 'Ví dụ: Bachelor of English Pedagogy, IELTS Academic' : 'E.g.: Bachelor of English Pedagogy, IELTS Academic',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      isVi ? 'Ảnh chứng chỉ / Bằng cấp *' : 'Certificate / Degree Image *',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit'),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: isUploading
                          ? null
                          : () async {
                              setModalState(() => isUploading = true);
                              final uploaded = await _uploadFileToCloudinaryWithDetails();
                              setModalState(() {
                                isUploading = false;
                                if (uploaded != null) {
                                  tempUrl = uploaded['url'];
                                  nameController.text = _extractSmartTitle(uploaded['fileName']!);
                                }
                              });
                            },
                      child: Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                        ),
                        child: isUploading
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(color: Color(0xFF28B79B)),
                                  const SizedBox(height: 12),
                                  Text(
                                    isVi ? 'Đang tải ảnh...' : 'Uploading image...',
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF28B79B), fontWeight: FontWeight.w600),
                                  ),
                                ],
                              )
                            : (tempUrl != null
                                ? Stack(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(tempUrl!, width: double.infinity, height: 220, fit: BoxFit.contain),
                                      ),
                                      Positioned(
                                        right: 8,
                                        top: 8,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            InkWell(
                                              onTap: () => setModalState(() {
                                                tempUrl = null;
                                                nameController.clear();
                                              }),
                                              child: Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                                                child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(color: const Color(0xFF28B79B), borderRadius: BorderRadius.circular(20)),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.refresh_rounded, color: Colors.white, size: 14),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    isVi ? 'Đổi ảnh khác' : 'Change Image',
                                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.cloud_upload_outlined, color: Color(0xFF28B79B), size: 32),
                                      const SizedBox(height: 8),
                                      Text(
                                        isVi ? 'Nhấp để tải lên ảnh mới (JPG, PNG, PDF)' : 'Click to upload document image (JPG, PNG, PDF)',
                                        style: const TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontSize: 13),
                                      ),
                                    ],
                                  )),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(isVi ? 'Hủy' : 'Cancel'),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: (tempUrl != null && nameController.text.trim().isNotEmpty)
                              ? () {
                                  setState(() {
                                    _certificates.add({
                                      'name': nameController.text.trim(),
                                      'url': tempUrl!,
                                    });
                                  });
                                  _triggerAutoSave();
                                  Navigator.pop(context);
                                  ToastHelper.showSuccess(context, isVi ? 'Đã thêm chứng chỉ!' : 'Certificate added!');
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(isVi ? 'Thêm chứng chỉ' : 'Add Certificate'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCertificateRequirementsNoteCard(bool isVi) {
    final trainerType = widget.initialProfile['trainerType'] ?? 'PROFESSIONAL';
    final isTeacher = trainerType == 'PROFESSIONAL';

    final title = isTeacher
        ? (isVi ? 'Hồ sơ minh chứng yêu cầu đối với Giáo viên:' : 'Required Document Credentials for Teachers:')
        : (isVi ? 'Hồ sơ minh chứng yêu cầu đối với Gia sư / Sinh viên:' : 'Required Document Credentials for Tutors / Students:');

    final bulletPoints = isTeacher
        ? [
            isVi ? 'Bằng cử nhân sư phạm tiếng Anh hoặc chứng chỉ bồi dưỡng nghiệp vụ sư phạm' : 'Degree in English Pedagogy or Teaching Certification',
            isVi ? 'Chứng chỉ tiếng Anh quốc tế (IELTS / TOEFL / TOEIC / Cambridge...)' : 'International English Certificate (IELTS / TOEFL / TOEIC / Cambridge)',
            isVi ? 'Các văn bằng, chứng chỉ giảng dạy liên quan khác (nếu có)' : 'Other related teaching credentials & diplomas (optional)',
          ]
        : [
            isVi ? 'Bảng điểm 3 năm Cấp 3 (THPT) hoặc Học bạ THPT' : 'High school transcripts (Grades 10, 11, 12 / 3 years)',
            isVi ? 'Chứng chỉ tiếng Anh quốc tế (IELTS / TOEFL...)' : 'International English Certificate (IELTS / TOEFL / Cambridge)',
            isVi ? 'Chứng chỉ liên quan đến phương pháp & giảng dạy tiếng Anh' : 'Certificates related to English teaching methodology',
            isVi ? 'Bằng khen / Giải thưởng HSG Tiếng Anh cấp Tỉnh, Thành phố (nếu có)' : 'Provincial / City-level English Competition awards (optional)',
          ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user_outlined, color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF1E40AF),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...bulletPoints.map((item) => Padding(
                padding: const EdgeInsets.only(left: 28, bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• ', style: TextStyle(color: Color(0xFF1D4ED8), fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A8A), fontFamily: 'Outfit'),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildUnifiedUploadBox(bool isVi) {
    return Column(
      children: [
        _buildCertificateRequirementsNoteCard(isVi),
        Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'Danh sách tài liệu đã tải lên' : 'Uploaded Documents',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155), fontSize: 13),
              ),
              Text(
                '${_certificates.length} ${isVi ? 'tài liệu' : 'documents'}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_certificates.isEmpty)
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
              children: _certificates.asMap().entries.map((entry) {
                final idx = entry.key;
                final item = entry.value;
                final certName = item['name'] ?? (isVi ? 'Chứng chỉ ${idx + 1}' : 'Certificate ${idx + 1}');
                final url = item['url'] ?? '';

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
                          url,
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
                              certName,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              url.split('/').last,
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
                            _certificates.removeAt(idx);
                          });
                          _triggerAutoSave();
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showAddCertificateModal(isVi),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
                color: Colors.white,
              ),
              child: Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF28B79B), size: 22),
                    const SizedBox(width: 10),
                    Text(
                      isVi ? 'Thêm chứng chỉ, bằng cấp' : 'Add Degree & Certificate',
                      style: const TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ],
);
  }

  bool _validateFields() {
    final isVi = LanguageManager.isVi;
    final bio = _bioController.text.trim();
    final phoneNumber = _phoneNumberController.text.trim();

    final vnPhoneRegex = RegExp(r'^(03|05|07|08|09)\d{8}$');
    final isDummyNumber = RegExp(r'^(\d)\1{9}$').hasMatch(phoneNumber) || phoneNumber == '1234567890';

    setState(() {
      _bioError = bio.isEmpty || bio.length < 50;
      _phoneNumberError = phoneNumber.isEmpty || !vnPhoneRegex.hasMatch(phoneNumber) || isDummyNumber;
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
        isVi
            ? 'Số điện thoại không hợp lệ. Phải bắt đầu bằng 03/05/07/08/09, đủ 10 số và không được nhập số giả trùng lặp (ví dụ: 0000000000).'
            : 'Invalid phone number. Must start with 03/05/07/08/09, be 10 digits, and not a dummy number (e.g. 0000000000).',
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

    final hasProof = _certificates.isNotEmpty;

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

        final nextPage = TrainerOnboardingStatusPage(
          initialProfile: result['data'],
          isEmbedded: true,
        );

        final shellState = TrainerOnboardingShellPage.of(context);
        if (shellState != null) {
          shellState.updateBody(nextPage);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => TrainerOnboardingShellPage(initialBody: nextPage),
            ),
            (route) => false,
          );
        }
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
    if (!widget.isEmbedded) {
      return TrainerOnboardingShellPage(
        initialBody: TrainerOnboardingDetailsPage(
          initialProfile: widget.initialProfile,
          isEmbedded: true,
        ),
      );
    }

    final isVi = LanguageManager.isVi;

    return SingleChildScrollView(
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
            dropdownColor: Colors.white,
            value: _gender,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              fillColor: Colors.white,
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
}
