import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/language_manager.dart';
import '../../../../utils/file_picker_helper.dart';
import '../../../../utils/trainer_document_utils.dart';
import '../../../../utils/trainer_revision_notes.dart';
import '../../../../utils/trainer_onboarding_validation_utils.dart';
import '../../../widgets/shared_header.dart';
import '../../../widgets/shared_footer.dart';
import 'trainer_onboarding_agreement_page.dart';
import 'trainer_onboarding_status_page.dart';
import 'trainer_payout_details_page.dart';
import 'trainer_onboarding_shell_page.dart';
import 'package:hango/presentation/widgets/document_preview_dialog.dart';
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
  State<TrainerOnboardingDetailsPage> createState() =>
      _TrainerOnboardingDetailsPageState();
}

class _TrainerOnboardingDetailsPageState
    extends State<TrainerOnboardingDetailsPage> {
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
  String _initialBio = '';
  String _initialCertJson = '';

  // Validation States & Inline Error Messages
  bool _bioError = false;
  bool _phoneNumberError = false;
  String? _phoneNumberErrorText;
  String? _bioErrorText;
  String? _genderErrorText;
  String? _avatarErrorText;
  String? _certificatesErrorText;

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
    _avatarUrl = p['avatarUrl'];
    final g = p['gender']?.toString();
    _gender = (g == 'MALE' || g == 'FEMALE') ? g : null;

    final rawPhone = p['phoneNumber']?.toString();
    if (isValidVietnamesePhoneNumber(rawPhone)) {
      _phoneNumberController.text = rawPhone!.trim();
    } else {
      _phoneNumberController.clear();
    }

    _certificates = decodeTrainerDocuments(
      certificates: p['certificates'],
      scoreReportUrl: p['scoreReportUrl'],
      pedagogicalDegreeUrl: p['pedagogicalDegreeUrl'],
      cvUrl: p['cvUrl'],
      degreeUrl: p['degreeUrl'],
      ieltsUrl: p['ieltsUrl'],
    );

    _initialBio = _bioController.text.trim();
    _initialCertJson = jsonEncode(_certificates);
  }

  Future<void> _loadUserAccountInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_fullname') ?? '';
      final email = prefs.getString('user_email') ?? '';
      final phone = prefs.getString('user_phone') ?? '';
      final gender = prefs.getString('user_gender');
      final avatar = prefs.getString('user_avatar_url') ?? '';
      if (!isValidVietnamesePhoneNumber(phone)) {
        await prefs.remove('user_phone');
      }
      setState(() {
        _userFullName = name;
        _userEmail = email;
        if (_phoneNumberController.text.isEmpty &&
            isValidVietnamesePhoneNumber(phone)) {
          _phoneNumberController.text = phone.trim();
        }
        if (_gender == null || (_gender != 'MALE' && _gender != 'FEMALE')) {
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
    if (isValidVietnamesePhoneNumber(phone)) {
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
      _saveDraftText = LanguageManager.isVi
          ? 'Đang lưu bản nháp...'
          : 'Saving draft...';
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
            _saveDraftText = LanguageManager.isVi
                ? '✓ Đã tự động lưu nháp'
                : '✓ Draft auto-saved';
            _syncSharedPreferences();
          } else {
            _saveDraftText = LanguageManager.isVi
                ? 'Lưu nháp thất bại'
                : 'Save draft failed';
          }
        });
      }
    });
  }

  Map<String, dynamic> _buildPayload() {
    final documentPayload = buildTrainerDocumentPayload(_certificates);

    return {
      'trainerType': widget.initialProfile['trainerType'] ?? 'PROFESSIONAL',
      'bio': _bioController.text.trim(),
      'phoneNumber': _phoneNumberController.text.trim(),
      ...documentPayload,
      'gender': (_gender == 'MALE' || _gender == 'FEMALE') ? _gender : null,
      'avatarUrl': _avatarUrl ?? '',
    };
  }

  Future<Map<String, dynamic>?> _uploadFileToCloudinaryWithDetails({
    required bool allowPdf,
    required int maxSizeBytes,
    required Function(String errorMsg) onError,
  }) async {
    try {
      final picked = allowPdf ? await pickImageOrPdf() : await pickImage();
      if (picked == null || picked.bytes.isEmpty) return null;

      final validationError = validateTrainerUploadFile(
        fileName: picked.name,
        fileSizeBytes: picked.bytes.length,
        maxSizeBytes: maxSizeBytes,
        allowPdf: allowPdf,
        isVi: LanguageManager.isVi,
      );
      if (validationError != null) {
        onError(validationError);
        return null;
      }

      final result = allowPdf
          ? await _onboardingService.uploadTrainerDocument(
              bytes: picked.bytes,
              fileName: picked.name,
            )
          : await _onboardingService.uploadTrainerAvatar(
              bytes: picked.bytes,
              fileName: picked.name,
            );
      if (result['success'] == true) {
        return {
          'url': result['data']['url'].toString(),
          'fileName': picked.name,
        };
      }
      onError(result['message'] ?? 'File upload failed. Please try again.');
    } catch (_) {
      onError(
        LanguageManager.isVi
            ? 'Không thể tải file. Vui lòng thử lại.'
            : 'Unable to upload the file. Please try again.',
      );
    }
    return null;
  }

  Future<void> _pickAndUpload(String targetDoc) async {
    try {
      if (targetDoc == 'avatar') {
        setState(() {
          _isUploadingAvatar = true;
          _avatarErrorText = null;
        });
      }
      final res = await _uploadFileToCloudinaryWithDetails(
        allowPdf: false,
        maxSizeBytes: 2 * 1024 * 1024,
        onError: (err) {
          setState(() {
            if (targetDoc == 'avatar') {
              _avatarErrorText = err;
              _isUploadingAvatar = false;
            }
          });
        },
      );
      if (res != null && res['url'] != null) {
        setState(() {
          if (targetDoc == 'avatar') {
            _avatarUrl = res['url'];
            _avatarErrorText = null;
            _isUploadingAvatar = false;
            _updateLocalAvatar(res['url']!);
          }
        });
        _triggerAutoSave();
        if (mounted) {
          ToastHelper.showSuccess(
            context,
            LanguageManager.isVi
                ? 'Tải lên avatar thành công!'
                : 'Avatar uploaded successfully!',
          );
        }
      } else {
        setState(() {
          _isUploadingAvatar = false;
        });
      }
    } catch (e) {
      setState(() {
        _isUploadingAvatar = false;
      });
    }
  }

  void _showAddCertificateModal(bool isVi) {
    final nameController = TextEditingController();
    String? tempUrl;
    bool isUploading = false;
    String selectedDocType = trainerDocTypeOther;
    String? modalCertNameErrorText;
    String? modalFileErrorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
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
                          isVi
                              ? 'Thêm chứng chỉ, bằng cấp'
                              : 'Add Degree & Certificate',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isVi
                          ? 'Tên chứng chỉ / Bằng cấp *'
                          : 'Certificate / Degree Name *',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: nameController,
                      onChanged: (val) {
                        if (val.trim().isNotEmpty &&
                            modalCertNameErrorText != null) {
                          setModalState(() => modalCertNameErrorText = null);
                        }
                      },
                      decoration: InputDecoration(
                        errorText: modalCertNameErrorText,
                        hintText: isVi
                            ? 'Ví dụ: Bachelor of English Pedagogy, IELTS Academic'
                            : 'E.g.: Bachelor of English Pedagogy, IELTS Academic',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          [
                            trainerDocTypePedagogicalDegree,
                            trainerDocTypeCv,
                            trainerDocTypeTeachingCertificate,
                            trainerDocTypeLanguageProficiency,
                            trainerDocTypeAcademicTranscript,
                          ].map((chipType) {
                            final chipTitle = canonicalTrainerDocumentTitle(
                              chipType,
                            );
                            final isSelected = selectedDocType == chipType;
                            return InkWell(
                              onTap: () {
                                setModalState(() {
                                  selectedDocType = chipType;
                                  nameController.text = chipTitle;
                                  modalCertNameErrorText = null;
                                  nameController.selection =
                                      TextSelection.collapsed(
                                        offset: nameController.text.length,
                                      );
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFE6FDF9)
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF28B79B)
                                        : const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Text(
                                  chipTitle,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected
                                        ? const Color(0xFF14B8A6)
                                        : const Color(0xFF475569),
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.w500,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isVi
                              ? 'Ảnh / File chứng chỉ (Tối đa 5MB) *'
                              : 'Certificate Image / Document (Max 5MB) *',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF334155),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        Text(
                          isVi ? 'JPG, PNG, WEBP, PDF' : 'JPG, PNG, WEBP, PDF',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: isUploading
                          ? null
                          : () async {
                              setModalState(() {
                                isUploading = true;
                                modalFileErrorText = null;
                              });
                              final uploaded =
                                  await _uploadFileToCloudinaryWithDetails(
                                    allowPdf: true,
                                    maxSizeBytes: 5 * 1024 * 1024,
                                    onError: (err) {
                                      setModalState(() {
                                        modalFileErrorText = err;
                                        isUploading = false;
                                      });
                                    },
                                  );
                              if (uploaded != null && uploaded['url'] != null) {
                                setModalState(() {
                                  tempUrl = uploaded['url'];
                                  modalFileErrorText = null;
                                  isUploading = false;
                                });
                              } else {
                                setModalState(() => isUploading = false);
                              }
                            },
                      child: Container(
                        height: 220,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: modalFileErrorText != null
                                ? Colors.redAccent
                                : const Color(0xFFCBD5E1),
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: isUploading
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const CircularProgressIndicator(
                                    color: Color(0xFF28B79B),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    isVi
                                        ? 'Đang tải tài liệu...'
                                        : 'Uploading document...',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF28B79B),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              )
                            : (tempUrl != null
                                  ? Stack(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          child: Image.network(
                                            tempUrl!,
                                            width: double.infinity,
                                            height: 220,
                                            fit: BoxFit.contain,
                                            errorBuilder: (ctx, err, st) =>
                                                Center(
                                                  child: Column(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      const Icon(
                                                        Icons.picture_as_pdf,
                                                        size: 48,
                                                        color: Color(
                                                          0xFF28B79B,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Text(
                                                        tempUrl!
                                                            .split('/')
                                                            .last,
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                          ),
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
                                                  selectedDocType =
                                                      trainerDocTypeOther;
                                                  nameController.clear();
                                                }),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    6,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Colors.redAccent,
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close_rounded,
                                                    color: Colors.white,
                                                    size: 16,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: const Color(
                                                    0xFF28B79B,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(20),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.refresh_rounded,
                                                      color: Colors.white,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isVi
                                                          ? 'Đổi file khác'
                                                          : 'Change File',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        const Icon(
                                          Icons.cloud_upload_outlined,
                                          color: Color(0xFF28B79B),
                                          size: 32,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          isVi
                                              ? 'Nhấp để tải lên chứng chỉ (JPG, PNG, WEBP, PDF)'
                                              : 'Click to upload document (JPG, PNG, WEBP, PDF)',
                                          style: const TextStyle(
                                            color: Color(0xFF28B79B),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          isVi
                                              ? 'Dung lượng tối đa: 5MB'
                                              : 'Maximum file size: 5MB',
                                          style: const TextStyle(
                                            color: Color(0xFF64748B),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    )),
                      ),
                    ),
                    if (modalFileErrorText != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        modalFileErrorText!,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
                          onPressed: () {
                            bool hasErr = false;
                            if (nameController.text.trim().isEmpty) {
                              setModalState(
                                () => modalCertNameErrorText = isVi
                                    ? 'Vui lòng nhập tên chứng chỉ'
                                    : 'Please enter certificate name',
                              );
                              hasErr = true;
                            }
                            if (tempUrl == null) {
                              setModalState(
                                () => modalFileErrorText = isVi
                                    ? 'Vui lòng tải lên tài liệu chứng chỉ (tối đa 5MB)'
                                    : 'Please upload document file (max 5MB)',
                              );
                              hasErr = true;
                            }
                            if (hasErr) return;

                            setState(() {
                              _certificates = normalizeTrainerDocuments([
                                ..._certificates,
                                {
                                  'type': selectedDocType,
                                  'name': nameController.text.trim(),
                                  'url': tempUrl!,
                                  'source': 'trainer_onboarding_manual',
                                },
                              ]);
                              _certificatesErrorText = null;
                            });
                            _triggerAutoSave();
                            Navigator.pop(context);
                            ToastHelper.showSuccess(
                              context,
                              isVi
                                  ? 'Đã thêm chứng chỉ!'
                                  : 'Certificate added!',
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            foregroundColor: Colors.white,
                          ),
                          child: Text(
                            isVi ? 'Thêm chứng chỉ' : 'Add Certificate',
                          ),
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
        ? (isVi
              ? 'Hồ sơ minh chứng yêu cầu đối với Giáo viên:'
              : 'Required Document Credentials for Teachers:')
        : (isVi
              ? 'Hồ sơ minh chứng yêu cầu đối với Gia sư / Sinh viên:'
              : 'Required Document Credentials for Tutors / Students:');

    final bulletPoints = isTeacher
        ? [
            isVi
                ? 'Bằng cử nhân sư phạm tiếng Anh hoặc chứng chỉ bồi dưỡng nghiệp vụ sư phạm'
                : 'Degree in English Pedagogy or Teaching Certification',
            isVi
                ? 'Chứng chỉ tiếng Anh quốc tế (IELTS / TOEFL / TOEIC / Cambridge...)'
                : 'International English Certificate (IELTS / TOEFL / TOEIC / Cambridge)',
            isVi
                ? 'Các văn bằng, chứng chỉ giảng dạy liên quan khác (nếu có)'
                : 'Other related teaching credentials & diplomas (optional)',
          ]
        : [
            isVi
                ? 'Bảng điểm 3 năm Cấp 3 (THPT) hoặc Học bạ THPT'
                : 'High school transcripts (Grades 10, 11, 12 / 3 years)',
            isVi
                ? 'Chứng chỉ tiếng Anh quốc tế (IELTS / TOEFL...)'
                : 'International English Certificate (IELTS / TOEFL / Cambridge)',
            isVi
                ? 'Chứng chỉ liên quan đến phương pháp & giảng dạy tiếng Anh'
                : 'Certificates related to English teaching methodology',
            isVi
                ? 'Bằng khen / Giải thưởng HSG Tiếng Anh cấp Tỉnh, Thành phố (nếu có)'
                : 'Provincial / City-level English Competition awards (optional)',
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
              const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF2563EB),
                size: 20,
              ),
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
          ...bulletPoints.map(
            (item) => Padding(
              padding: const EdgeInsets.only(left: 28, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '• ',
                    style: TextStyle(
                      color: Color(0xFF1D4ED8),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E3A8A),
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

  Widget _buildUnifiedUploadBox(bool isVi) {
    return Column(
      children: [
        _buildCertificateRequirementsNoteCard(isVi),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.info_outline,
                size: 18,
                color: Color(0xFF475569),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isVi
                      ? 'Định dạng hỗ trợ: JPG, PNG, WEBP, PDF • Dung lượng tối đa: 5MB/tài liệu'
                      : 'Supported formats: JPG, PNG, WEBP, PDF • Max file size: 5MB per document',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _certificatesErrorText != null
                  ? Colors.redAccent
                  : const Color(0xFFCBD5E1),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isVi
                        ? 'Danh sách tài liệu đã tải lên'
                        : 'Uploaded Documents',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF334155),
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '${_certificates.length} ${isVi ? 'tài liệu' : 'documents'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_certificates.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      isVi
                          ? 'Chưa có tài liệu nào được tải lên.'
                          : 'No documents uploaded yet.',
                      style: const TextStyle(
                        color: Color(0xFF64748B),
                        fontStyle: FontStyle.italic,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              else
                Column(
                  children: _certificates.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final item = entry.value;
                    final certName =
                        item['name'] ??
                        (isVi
                            ? 'Chứng chỉ ${idx + 1}'
                            : 'Certificate ${idx + 1}');
                    final url = (item['url'] ?? '').trim();
                    final isPdf =
                        url.toLowerCase().endsWith('.pdf') ||
                        url.toLowerCase().contains('.pdf?') ||
                        url.toLowerCase().contains('/pdf/');

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
                            child: isPdf
                                ? Container(
                                    width: 50,
                                    height: 50,
                                    color: const Color(0xFFEFF6FF),
                                    child: const Center(
                                      child: Icon(
                                        Icons.picture_as_pdf_rounded,
                                        color: Color(0xFFDC2626),
                                        size: 26,
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    url,
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.insert_drive_file_outlined,
                                              color: Color(0xFF94A3B8),
                                            ),
                                  ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  certName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  url.split('/').last,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.visibility_outlined,
                              color: Color(0xFF2563EB),
                              size: 20,
                            ),
                            tooltip: isVi ? 'Xem tài liệu' : 'Preview Document',
                            onPressed: () => showDocumentPreviewDialog(
                              context,
                              certName,
                              url,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            tooltip: isVi ? 'Xóa tài liệu' : 'Delete Document',
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
                    border: Border.all(
                      color: const Color(0xFFCBD5E1),
                      style: BorderStyle.solid,
                    ),
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Color(0xFF28B79B),
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isVi
                              ? 'Thêm chứng chỉ, bằng cấp'
                              : 'Add Degree & Certificate',
                          style: const TextStyle(
                            color: Color(0xFF28B79B),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_certificatesErrorText != null) ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFCA5A5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.redAccent,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _certificatesErrorText!,
                    style: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  bool _validateFields() {
    final isVi = LanguageManager.isVi;
    final bio = _bioController.text.trim();
    final phoneNumber = _phoneNumberController.text.trim();

    final vnPhoneRegex = RegExp(r'^(03|05|07|08|09)\d{8}$');
    final isDummyNumber =
        RegExp(r'^(\d)\1{9}$').hasMatch(phoneNumber) ||
        phoneNumber == '1234567890';

    String? phoneErr;
    if (phoneNumber.isEmpty) {
      phoneErr = isVi
          ? 'Vui lòng nhập số điện thoại liên hệ.'
          : 'Please enter contact phone number.';
    } else if (!vnPhoneRegex.hasMatch(phoneNumber) || isDummyNumber) {
      phoneErr = isVi
          ? 'Số điện thoại không hợp lệ (bắt đầu bằng 03/05/07/08/09, đủ 10 số).'
          : 'Invalid phone number (must be 10 digits starting with 03/05/07/08/09).';
    }

    String? bioErr;
    if (bio.isEmpty) {
      bioErr = isVi
          ? 'Vui lòng nhập phần giới thiệu bản thân.'
          : 'Please enter your bio.';
    } else if (bio.length < 50) {
      bioErr = isVi
          ? 'Giới thiệu bản thân cần tối thiểu 50 ký tự (hiện tại: ${bio.length}/50).'
          : 'Bio must be at least 50 characters long (currently: ${bio.length}/50).';
    }

    String? genderErr;
    if (_gender == null || (_gender != 'MALE' && _gender != 'FEMALE')) {
      genderErr = isVi
          ? 'Vui lòng chọn giới tính.'
          : 'Please select your gender.';
    }

    String? avatarErr;
    if (_avatarUrl == null || _avatarUrl!.isEmpty) {
      avatarErr = isVi
          ? 'Vui lòng tải lên ảnh đại diện.'
          : 'Please upload an avatar image.';
    }

    String? certErr;
    final trainerType = widget.initialProfile['trainerType'] ?? 'PROFESSIONAL';
    final isTeacher = trainerType == 'PROFESSIONAL';
    final normalizedCertificates = normalizeTrainerDocuments(_certificates);

    if (normalizedCertificates.isEmpty) {
      certErr = isVi
          ? 'Vui lòng tải lên ít nhất một chứng chỉ/bằng cấp hoặc CV.'
          : 'Please upload at least one degree, CV, or qualification credential proof.';
    } else if (isTeacher &&
        !normalizedCertificates.any(
          (doc) => isPedagogicalTrainerDocument(doc['type']),
        )) {
      certErr = isVi
          ? 'Hồ sơ Giáo viên yêu cầu bắt buộc có Bằng cử nhân Sư phạm hoặc Chứng chỉ nghiệp vụ sư phạm.'
          : 'A teaching/pedagogical degree or certificate is mandatory for Teacher applications.';
    }

    setState(() {
      _phoneNumberErrorText = phoneErr;
      _phoneNumberError = phoneErr != null;
      _bioErrorText = bioErr;
      _bioError = bioErr != null;
      _genderErrorText = genderErr;
      _avatarErrorText = avatarErr;
      _certificatesErrorText = certErr;
    });

    if (phoneErr != null ||
        bioErr != null ||
        genderErr != null ||
        avatarErr != null ||
        certErr != null) {
      return false;
    }

    final adminNotes = widget.initialProfile['adminNotes'];
    if (adminNotes != null && adminNotes.toString().trim().isNotEmpty) {
      final currentBio = _bioController.text.trim();
      final currentCertJson = jsonEncode(_certificates);
      final bioChanged = currentBio != _initialBio;
      final certsChanged = currentCertJson != _initialCertJson;

      if (!bioChanged && !certsChanged) {
        ToastHelper.showError(
          context,
          isVi
              ? 'Vui lòng cập nhật Bio hoặc Chứng chỉ theo yêu cầu từ Ban quản trị trước khi nộp lại.'
              : 'Please update your Bio or upload/change your Certificates according to the admin feedback before re-submitting.',
        );
        return false;
      }
    }

    return true;
  }

  void _handleSubmit() async {
    if (!_validateFields()) return;

    setState(() {
      _isLoading = true;
    });

    final payload = _buildPayload();
    final result = await _onboardingService.submitProfileForReview(payload);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        _syncSharedPreferences();
        ToastHelper.showSuccess(
          context,
          LanguageManager.isVi
              ? 'Đã nộp hồ sơ xét duyệt thành công!'
              : 'Application submitted for review successfully!',
        );

        final nextPage = TrainerOnboardingStatusPage(
          initialProfile: result['data'] ?? payload,
          isEmbedded: true,
        );

        final shellState = TrainerOnboardingShellPage.of(context);
        if (shellState != null) {
          shellState.updateBody(nextPage);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  TrainerOnboardingShellPage(initialBody: nextPage),
            ),
          );
        }
      } else {
        ToastHelper.showError(
          context,
          result['message'] ?? 'Failed to submit application.',
        );
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
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(0xFF0F172A),
                    ),
                    tooltip: 'Back to Terms & Agreement',
                    onPressed: () {
                      final payload = _buildPayload();
                      _onboardingService.saveProfileDraft(payload);
                      final trainerType =
                          payload['trainerType'] ?? 'PROFESSIONAL';
                      final agreementPage = TrainerOnboardingAgreementPage(
                        profilePayload: payload,
                        trainerType: trainerType,
                        isEmbedded: true,
                      );
                      final shellState = TrainerOnboardingShellPage.of(context);
                      if (shellState != null) {
                        shellState.updateBody(agreementPage);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Complete Teaching Profile & Application',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
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
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(
                      isVi
                          ? 'Nộp hồ sơ xét duyệt'
                          : 'Submit Application for Review',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28B79B),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 18,
                      ),
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
    final revisionNotes = parseTrainerRevisionNotes(
      widget.initialProfile['adminNotes']?.toString(),
    );
    final bioAdminNote = revisionNotes.bio;
    final certAdminNote = revisionNotes.certificates;
    final requestedSections = <String>[
      if (bioAdminNote != null) 'Bio',
      if (certAdminNote != null) isVi ? 'Chứng chỉ' : 'Certificates',
    ].join(isVi ? ' và ' : ' and ');
    final revisionInstruction = revisionNotes.general != null
        ? (isVi
              ? 'Phản hồi từ Ban quản trị: ${revisionNotes.general}\n👉 Vui lòng cập nhật thông tin được yêu cầu rồi nộp lại hồ sơ.'
              : 'Feedback from Administrator: ${revisionNotes.general}\n👉 Please update the requested information and submit your application again.')
        : (isVi
              ? '👉 Vui lòng cập nhật $requestedSections theo yêu cầu bên dưới rồi nhấn "Nộp hồ sơ xét duyệt" lại.'
              : '👉 Please update $requestedSections as requested below, then click "Submit Application for Review" again.');
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
          if (revisionNotes.hasAny) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Text(
                revisionInstruction,
                style: const TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFFB91C1C),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          // Avatar Upload Circle Selector
          Center(
            child: Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _avatarErrorText != null
                              ? Colors.redAccent
                              : const Color(0xFF28B79B),
                          width: 2,
                        ),
                        color: const Color(0xFFF1F5F9),
                      ),
                      child: ClipOval(
                        child: _isUploadingAvatar
                            ? const Center(
                                child: CircularProgressIndicator(
                                  color: Color(0xFF28B79B),
                                ),
                              )
                            : (_avatarUrl != null && _avatarUrl!.isNotEmpty
                                  ? Image.network(
                                      _avatarUrl!,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(
                                      Icons.person_rounded,
                                      size: 64,
                                      color: Color(0xFF94A3B8),
                                    )),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _isUploadingAvatar
                            ? null
                            : () => _pickAndUpload('avatar'),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF28B79B),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_avatarErrorText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _avatarErrorText!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Section 1: Personal Info
          _buildSectionHeader(
            Icons.person_outline_rounded,
            isVi ? '1. Thông tin cá nhân' : '1. Personal Information',
          ),
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
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            dropdownColor: Colors.white,
            value: (_gender == 'MALE' || _gender == 'FEMALE') ? _gender : null,
            decoration: InputDecoration(
              errorText: _genderErrorText,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
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
                borderSide: const BorderSide(
                  color: Color(0xFF28B79B),
                  width: 2,
                ),
              ),
            ),
            hint: Text(isVi ? 'Chọn giới tính' : 'Select gender'),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: Color(0xFF0F172A),
            ),
            items: [
              DropdownMenuItem(
                value: 'MALE',
                child: Text(isVi ? 'Nam' : 'Male'),
              ),
              DropdownMenuItem(
                value: 'FEMALE',
                child: Text(isVi ? 'Nữ' : 'Female'),
              ),
            ],
            onChanged: (val) {
              setState(() {
                _gender = val;
                _genderErrorText = null;
              });
              _triggerAutoSave();
            },
          ),
          const SizedBox(height: 16),

          _buildTextField(
            label: isVi ? 'Số điện thoại liên hệ *' : 'Contact Phone Number *',
            controller: _phoneNumberController,
            errorText:
                _phoneNumberErrorText ??
                (_phoneNumberError
                    ? (isVi
                          ? 'Số điện thoại phải có đúng 10 số'
                          : 'Phone number must be 10 digits')
                    : null),
            hintText: '0912345678',
            keyboardType: TextInputType.phone,
            onChanged: (_) {
              setState(() {
                _phoneNumberErrorText = null;
                _phoneNumberError = false;
              });
            },
          ),
          const SizedBox(height: 24),

          // Section 2: Bio
          _buildSectionHeader(
            Icons.work_outline_rounded,
            isVi ? '2. Giới thiệu bản thân *' : '2. Bio *',
          ),
          const SizedBox(height: 20),
          _buildTextField(
            controller: _bioController,
            errorText:
                _bioErrorText ??
                (_bioError
                    ? (isVi
                          ? 'Giới thiệu cần tối thiểu 50 ký tự'
                          : 'Bio must be at least 50 characters')
                    : null),
            hintText: isVi
                ? 'Mô tả bản thân, phương pháp dạy và các thành tích của bạn...'
                : 'Describe yourself, your teaching style, and credentials...',
            maxLines: 5,
            onChanged: (_) {
              setState(() {
                _bioErrorText = null;
                _bioError = false;
              });
            },
          ),
          if (bioAdminNote != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isVi
                          ? 'Lưu ý về Giới thiệu (Bio): $bioAdminNote'
                          : 'Feedback on Bio: $bioAdminNote',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF991B1B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),

          // Section 3: Credentials Proofs
          _buildSectionHeader(
            Icons.verified_outlined,
            isVi
                ? '3. Bằng cấp & Chứng chỉ năng lực'
                : '3. Degrees & Certificates *',
          ),
          const SizedBox(height: 8),
          Text(
            isVi
                ? 'Tải lên ít nhất một tài liệu chứng minh năng lực để được xét duyệt.'
                : 'Upload at least one credentials proof to unlock review.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 24),
          _buildUnifiedUploadBox(isVi),
          if (certAdminNote != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFFFCA5A5)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: Colors.redAccent,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isVi
                          ? 'Lưu ý về Bằng cấp / Chứng chỉ: $certAdminNote'
                          : 'Feedback on Credentials: $certAdminNote',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF991B1B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
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
    String? label,
    required TextEditingController controller,
    String? errorText,
    required String hintText,
    TextInputType? keyboardType,
    int maxLines = 1,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null && label.trim().isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onChanged: (val) {
            _triggerAutoSave();
            if (onChanged != null) onChanged(val);
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
