import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/language_manager.dart';
import '../../../../utils/file_picker_helper.dart';
import '../../widgets/trainer/trainer_sidebar.dart';

class TrainerProfilePage extends StatefulWidget {
  final bool isEmbedded;
  const TrainerProfilePage({super.key, this.isEmbedded = false});

  @override
  State<TrainerProfilePage> createState() => _TrainerProfilePageState();
}

class _TrainerProfilePageState extends State<TrainerProfilePage> {
  final _onboardingService = TrainerOnboardingService();

  int _activeTab = 0; // 0: Personal Info, 1: CV & Experience, 2: Bank Account, 3: Security
  bool _isLoading = true;
  bool _isSaving = false;

  String _maskAccountNumber(String acc) {
    if (acc.isEmpty) return '•••• •••• ••••';
    if (acc.length <= 4) return acc;
    final last4 = acc.substring(acc.length - 4);
    return '•••• •••• $last4';
  }
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

  // Degrees & Certificates (Dynamic unlimited list)
  List<Map<String, String>> _certificates = [];

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
        _avatarUrl = p['avatarUrl'] ?? avatarUrl;
        _gender = (p['gender'] == 'MALE' || p['gender'] == 'FEMALE') ? p['gender'] : null;
        _trainerType = p['trainerType'] ?? 'PROFESSIONAL';
        _selectedBank = p['bankName'];
        _bankAccountController.text = p['bankAccount'] ?? '';
        _bankAccountNameController.text = p['bankAccountName'] ?? '';
        _citizenIdController.text = p['citizenId'] ?? '';

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
    final degree = _certificates.isNotEmpty ? _certificates.first['url'] ?? '' : '';
    final ielts = _certificates.length > 1 ? _certificates[1]['url'] ?? '' : '';
    final score = _certificates.length > 2 ? jsonEncode(_certificates) : (_certificates.isNotEmpty ? _certificates.last['url'] ?? '' : '');
    payload['degreeUrl'] = degree;
    payload['ieltsUrl'] = ielts;
    payload['scoreReportUrl'] = score;
    payload['certificates'] = _certificates;
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

        if (mounted) {
          ToastHelper.showSuccess(
            context,
            LanguageManager.isVi ? 'Cập nhật hồ sơ thành công!' : 'Profile updated successfully!',
          );
        }
      } else if (mounted) {
        ToastHelper.showError(context, result['message'] ?? 'Cập nhật thất bại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isVi = LanguageManager.isVi;

    if (widget.isEmbedded) {
      return _buildBodyContent(isVi);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? const Drawer(child: TrainerSidebar(activeIndex: 5)) : null,
      body: Row(
        children: [
          if (isDesktop) const SizedBox(width: 260, child: TrainerSidebar(activeIndex: 5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(
                  child: _buildBodyContent(isVi),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(bool isVi) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF20B486)));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
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
          const SizedBox(height: 20),

          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 850;

              if (isWide) {
                // 2-Column Split Layout (Full Width Stretched)
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left Side Navigation Column (Avatar Card + 4 Vertical Navigation Buttons)
                    SizedBox(
                      width: 320,
                      child: Column(
                        children: [
                          _buildAvatarCard(isVi),
                          const SizedBox(height: 16),
                          _buildVerticalTabNavigation(isVi),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),

                    // Right Side Main Content Panel (Active Box Form)
                    Expanded(
                      child: _buildFormFields(isVi),
                    ),
                  ],
                );
              }

              // 1-Column Stacked Layout (Mobile / Narrow Screen)
              return Column(
                children: [
                  _buildAvatarCard(isVi),
                  const SizedBox(height: 16),
                  _buildTabNavigation(isVi),
                  const SizedBox(height: 20),
                  _buildFormFields(isVi),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabNavigation(bool isVi) {
    final tabs = [
      {
        'index': 0,
        'title': isVi ? 'Thông tin cá nhân' : 'Personal Info',
        'subtitle': isVi ? 'Họ tên, email & bio' : 'Name, contact & bio',
        'icon': Icons.person_outline_rounded,
        'activeColor': const Color(0xFF28B79B),
      },
      {
        'index': 1,
        'title': isVi ? 'CV & Bằng cấp' : 'CV & Degrees',
        'subtitle': isVi ? 'Kinh nghiệm & chứng chỉ' : 'Experience & certificates',
        'icon': Icons.badge_outlined,
        'activeColor': const Color(0xFF0284C7),
      },
      {
        'index': 2,
        'title': isVi ? 'Tài khoản Ngân hàng' : 'Bank Account',
        'subtitle': isVi ? 'Nhận tiền doanh thu' : 'Payout & Tax ID',
        'icon': Icons.account_balance_outlined,
        'activeColor': const Color(0xFF8B5CF6),
      },
      {
        'index': 3,
        'title': isVi ? 'Đổi mật khẩu' : 'Security',
        'subtitle': isVi ? 'Mật khẩu & bảo mật' : 'Password & security',
        'icon': Icons.lock_reset_rounded,
        'activeColor': const Color(0xFFF59E0B),
      },
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 650;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isWide ? 4 : 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            mainAxisExtent: 76,
          ),
          itemCount: tabs.length,
          itemBuilder: (context, index) {
            final item = tabs[index];
            final idx = item['index'] as int;
            final isSelected = _activeTab == idx;
            final activeColor = item['activeColor'] as Color;

            return InkWell(
              onTap: () {
                setState(() {
                  _activeTab = idx;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withOpacity(0.08) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? activeColor : const Color(0xFFE2E8F0),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: activeColor.withOpacity(0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          )
                        ]
                      : [
                          const BoxShadow(
                            color: Color(0x05000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          )
                        ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? activeColor : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? activeColor : const Color(0xFF0F172A),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['subtitle'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF64748B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
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

  Widget _buildVerticalTabNavigation(bool isVi) {
    final tabs = [
      {
        'index': 0,
        'title': isVi ? 'Thông tin cá nhân' : 'Personal Info',
        'subtitle': isVi ? 'Họ tên, email & bio' : 'Name, contact & bio',
        'icon': Icons.person_outline_rounded,
        'activeColor': const Color(0xFF28B79B),
      },
      {
        'index': 1,
        'title': isVi ? 'CV & Bằng cấp' : 'CV & Degrees',
        'subtitle': isVi ? 'Kinh nghiệm & chứng chỉ' : 'Experience & certificates',
        'icon': Icons.badge_outlined,
        'activeColor': const Color(0xFF0284C7),
      },
      {
        'index': 2,
        'title': isVi ? 'Tài khoản Ngân hàng' : 'Bank Account',
        'subtitle': isVi ? 'Nhận tiền doanh thu' : 'Payout & Tax ID',
        'icon': Icons.account_balance_outlined,
        'activeColor': const Color(0xFF8B5CF6),
      },
      {
        'index': 3,
        'title': isVi ? 'Đổi mật khẩu' : 'Security',
        'subtitle': isVi ? 'Mật khẩu & bảo mật' : 'Password & security',
        'icon': Icons.lock_reset_rounded,
        'activeColor': const Color(0xFFF59E0B),
      },
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: tabs.map((item) {
          final idx = item['index'] as int;
          final isSelected = _activeTab == idx;
          final activeColor = item['activeColor'] as Color;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeTab = idx;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor.withOpacity(0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? activeColor.withOpacity(0.3) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected ? activeColor : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'] as String,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? activeColor : const Color(0xFF0F172A),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['subtitle'] as String,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF64748B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.chevron_right_rounded, color: activeColor, size: 20),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
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
                ),
                child: _avatarUrl != null && _avatarUrl!.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _avatarUrl!,
                          width: 90,
                          height: 90,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              _trainerInitials,
                              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF20B486), fontFamily: 'Outfit'),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _trainerInitials,
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF20B486), fontFamily: 'Outfit'),
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: InkWell(
                  onTap: _isUploadingAvatar
                      ? null
                      : () async {
                          final uploaded = await _uploadFileToCloudinary();
                          if (uploaded != null) {
                            setState(() {
                              _avatarUrl = uploaded;
                            });
                          }
                        },
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF20B486),
                      shape: BoxShape.circle,
                    ),
                    child: _isUploadingAvatar
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fullNameController.text.isNotEmpty ? _fullNameController.text : _trainerName,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(12),
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
    Widget activeWidget;
    switch (_activeTab) {
      case 0:
        activeWidget = _buildBox0PersonalInfo(isVi);
        break;
      case 1:
        activeWidget = _buildBox1CvAndDegrees(isVi);
        break;
      case 2:
        activeWidget = _buildBox2BankAccount(isVi);
        break;
      case 3:
        activeWidget = _buildBox3Security(isVi);
        break;
      default:
        activeWidget = _buildBox0PersonalInfo(isVi);
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: activeWidget,
    );
  }

  // Box 1: Thông tin cá nhân
  Widget _buildBox0PersonalInfo(bool isVi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4F1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.person_outline_rounded, color: Color(0xFF28B79B), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              isVi ? '1. Thông tin cá nhân' : '1. Personal Information',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildInputField(isVi ? 'Họ và tên *' : 'Full Name *', _fullNameController, errorText: _fullNameError ? (isVi ? 'Họ tên không được trống' : 'Name required') : null),
        const SizedBox(height: 16),
        _buildReadOnlyField(isVi ? 'Email liên hệ' : 'Email Address', _userEmail),
        const SizedBox(height: 16),
        Text(
          isVi ? 'Giới tính *' : 'Gender *',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155), fontFamily: 'Outfit'),
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
          },
        ),
        const SizedBox(height: 16),
        _buildInputField(isVi ? 'Số điện thoại *' : 'Phone Number *', _phoneNumberController, keyboardType: TextInputType.phone, errorText: _phoneNumberError ? (isVi ? 'Số điện thoại không hợp lệ' : 'Invalid phone') : null),
        const SizedBox(height: 24),
        _buildSaveButtonRow(isVi),
      ],
    );
  }

  // Box 2: CV, Kinh nghiệm & Bằng cấp
  Widget _buildBox1CvAndDegrees(bool isVi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE0F2FE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.badge_outlined, color: Color(0xFF0284C7), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              isVi ? '2. CV & Kinh nghiệm giảng dạy' : '2. CV & Teaching Experience',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildInputField(isVi ? 'Nơi làm việc / Trường đào tạo' : 'Workplace / Organization', _workplaceController),
        const SizedBox(height: 16),
        _buildInputField(
          isVi ? 'Giới thiệu bản thân & Kinh nghiệm *' : 'Bio & Experience *',
          _bioController,
          maxLines: 5,
          errorText: _bioError ? (isVi ? 'Giới thiệu cần từ 50 ký tự' : 'Bio must be >= 50 characters') : null,
        ),
        const SizedBox(height: 24),
        Text(
          isVi ? 'Bằng cấp & Chứng chỉ năng lực' : 'Degrees & Certificates',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 6),
        Text(
          isVi ? 'Tải lên ít nhất một tài liệu chứng minh năng lực để hoàn tất hồ sơ.' : 'Upload at least one credentials proof to complete your profile.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        _buildUnifiedUploadBox(isVi),
        const SizedBox(height: 24),
        _buildSaveButtonRow(isVi),
      ],
    );
  }

  // Box 3: Tài khoản Ngân hàng
  Widget _buildBox2BankAccount(bool isVi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_outlined, color: Color(0xFF8B5CF6), size: 20),
            ),
            const SizedBox(width: 12),
            Text(
              isVi ? '3. Cấu hình Tài khoản thụ hưởng' : '3. Bank Account & Payout',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Digital Bank Card Preview Widget (Pro Max Design)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F000000),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFF28B79B), size: 18),
                      const SizedBox(width: 6),
                      Text(
                        isVi ? 'TÀI KHOẢN THỤ HƯỞNG BẢO MẬT' : 'SECURED PAYOUT ACCOUNT',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF28B79B), letterSpacing: 1),
                      ),
                    ],
                  ),
                  Text(
                    _selectedBank ?? (isVi ? 'NGÂN HÀNG' : 'BANK'),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                _maskAccountNumber(_bankAccountController.text),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                  fontFamily: 'monospace',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'CHỦ TÀI KHOẢN' : 'ACCOUNT OWNER',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bankAccountNameController.text.isNotEmpty
                            ? _bankAccountNameController.text.toUpperCase()
                            : (isVi ? 'CHƯA CẬP NHẬT' : 'NOT UPDATED'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isVi ? 'MÃ SỐ THUẾ' : 'TAX ID',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _citizenIdController.text.isNotEmpty ? _citizenIdController.text : '---',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Text(
          isVi ? 'Ngân hàng thụ hưởng' : 'Beneficiary Bank',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF334155), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedBank,
              dropdownColor: Colors.white,
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
        _buildInputField(
          isVi ? 'Số tài khoản ngân hàng' : 'Bank Account Number',
          _bankAccountController,
          keyboardType: TextInputType.number,
          errorText: _bankAccountError ? (isVi ? 'Chỉ nhập số' : 'Digits only') : null,
          onChanged: (_) => setState(() {}),
        ),
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
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        _buildInputField(
          isVi ? 'Mã số thuế (Tax ID)' : 'Tax Identification Number (Tax ID)',
          _citizenIdController,
          keyboardType: TextInputType.number,
          maxLength: 13,
          errorText: _citizenIdError ? (isVi ? 'Mã số thuế không hợp lệ' : 'Invalid Tax ID') : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        _buildSaveButtonRow(isVi),
      ],
    );
  }

  // Box 4: Thay đổi mật khẩu
  Widget _buildBox3Security(bool isVi) {
    return _buildChangePasswordSection(isVi);
  }

  Widget _buildSaveButtonRow(bool isVi) {
    return Row(
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
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          ),
        ),
      ],
    );
  }

  Widget _buildChangePasswordSection(bool isVi) {
    final currentPwdController = TextEditingController();
    final newPwdController = TextEditingController();
    final confirmPwdController = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          isVi ? '4. Đổi mật khẩu' : '4. Security & Change Password',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 8),
        Text(
          isVi ? 'Cập nhật mật khẩu đăng nhập tài khoản của bạn.' : 'Update your account login password.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        _buildInputField(isVi ? 'Mật khẩu hiện tại *' : 'Current Password *', currentPwdController, isPassword: true),
        const SizedBox(height: 12),
        _buildInputField(isVi ? 'Mật khẩu mới *' : 'New Password *', newPwdController, isPassword: true),
        const SizedBox(height: 12),
        _buildInputField(isVi ? 'Xác nhận mật khẩu mới *' : 'Confirm New Password *', confirmPwdController, isPassword: true),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final cur = currentPwdController.text.trim();
              final newP = newPwdController.text.trim();
              final confP = confirmPwdController.text.trim();

              if (cur.isEmpty || newP.isEmpty || confP.isEmpty) {
                ToastHelper.showError(context, isVi ? 'Vui lòng nhập đầy đủ thông tin mật khẩu.' : 'Please fill out all password fields.');
                return;
              }
              if (newP.length < 6) {
                ToastHelper.showError(context, isVi ? 'Mật khẩu mới phải có tối thiểu 6 ký tự.' : 'New password must be at least 6 characters.');
                return;
              }
              if (newP != confP) {
                ToastHelper.showError(context, isVi ? 'Mật khẩu xác nhận không khớp.' : 'Confirm password does not match.');
                return;
              }

              final authService = AuthService();
              final res = await authService.changePassword(cur, newP);
              if (context.mounted) {
                if (res['success'] == true) {
                  ToastHelper.showSuccess(context, isVi ? 'Đổi mật khẩu thành công!' : 'Password changed successfully!');
                  currentPwdController.clear();
                  newPwdController.clear();
                  confirmPwdController.clear();
                } else {
                  ToastHelper.showError(context, res['message'] ?? (isVi ? 'Đổi mật khẩu thất bại.' : 'Failed to change password.'));
                }
              }
            },
            icon: const Icon(Icons.lock_reset_rounded, color: Color(0xFF28B79B), size: 18),
            label: Text(
              isVi ? 'Cập nhật mật khẩu' : 'Update Password',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF28B79B), fontFamily: 'Outfit'),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF28B79B)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {TextInputType? keyboardType, int maxLines = 1, int? maxLength, String? errorText, bool isPassword = false, ValueChanged<String>? onChanged}) {
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
          obscureText: isPassword,
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

  Future<String?> _uploadFileToCloudinary() async {
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
        return data['secure_url'] ?? data['url'];
      }
    } catch (e) {
      debugPrint('Cloudinary upload error: $e');
    }
    return null;
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Container(
                color: Colors.white,
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
                        hintText: isVi ? 'Ví dụ: Bằng Cử nhân Sư phạm Anh, IELTS 8.0' : 'E.g.: Bachelor of English Pedagogy, IELTS 8.0',
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
                              final uploaded = await _uploadFileToCloudinary();
                              setModalState(() {
                                isUploading = false;
                                if (uploaded != null) tempUrl = uploaded;
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
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFF28B79B)))
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
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                                          child: const Icon(Icons.check, color: Colors.white, size: 16),
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
                                        isVi ? 'Nhấp để chọn ảnh chứng chỉ' : 'Click to select certificate image',
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

  Widget _buildUnifiedUploadBox(bool isVi) {
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
                        child: InkWell(
                          onTap: () {
                            showDialog(
                              context: context,
                              builder: (context) => Dialog(
                                child: Container(
                                  constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
                                  child: Image.network(url, fit: BoxFit.contain),
                                ),
                              ),
                            );
                          },
                          child: Image.network(
                            url,
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
                              certName,
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
                                      child: Image.network(url, fit: BoxFit.contain),
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
                            _certificates.removeAt(idx);
                          });
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
    );
  }
}
