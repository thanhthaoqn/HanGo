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
import '../../../../utils/trainer_document_utils.dart';
import '../../widgets/trainer/trainer_sidebar.dart';

class TrainerProfilePage extends StatefulWidget {
  final bool isEmbedded;
  const TrainerProfilePage({super.key, this.isEmbedded = false});

  @override
  State<TrainerProfilePage> createState() => _TrainerProfilePageState();
}

class _TrainerProfilePageState extends State<TrainerProfilePage> {
  final _onboardingService = TrainerOnboardingService();

  int _activeTab =
      0; // 0: Personal Info, 1: CV & Experience, 2: Bank Account, 3: Security
  bool _isLoading = true;
  bool _isSaving = false;

  String _maskAccountNumber(String acc) {
    if (acc.isEmpty) return 'â€¢â€¢â€¢â€¢ â€¢â€¢â€¢â€¢ â€¢â€¢â€¢â€¢';
    if (acc.length <= 4) return acc;
    final last4 = acc.substring(acc.length - 4);
    return 'â€¢â€¢â€¢â€¢ â€¢â€¢â€¢â€¢ $last4';
  }

  Map<String, dynamic> _profileData = {};

  // Controllers & Form fields
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _dobController = TextEditingController();
  final _addressController = TextEditingController();
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
    _usernameController.dispose();
    _dobController.dispose();
    _addressController.dispose();
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
    if (!mounted) return;
    setState(() {
      _trainerName = fullName;
      _trainerInitials = initials;
      _trainerAvatarUrl = avatarUrl;
    });

    final result = await _onboardingService.getTrainerProfile();
    if (result['success'] == true) {
      final p = result['data'] ?? {};
      if (!mounted) return;
      setState(() {
        _profileData = p;
        _fullNameController.text = p['fullName'] ?? fullName;
        _usernameController.text = p['username'] ?? '';
        _dobController.text = p['dateOfBirth'] ?? '';
        _addressController.text = p['address'] ?? '';
        _userEmail = p['email'] ?? '';
        _phoneNumberController.text = p['phoneNumber'] ?? '';
        _bioController.text = p['bio'] ?? '';
        _workplaceController.text = p['workplace'] ?? '';
        _avatarUrl = p['avatarUrl'] ?? avatarUrl;
        _gender = (p['gender'] == 'MALE' || p['gender'] == 'FEMALE')
            ? p['gender']
            : null;
        _trainerType = p['trainerType'] ?? 'PROFESSIONAL';
        _selectedBank = p['bankName'];
        _bankAccountController.text = p['bankAccount'] ?? '';
        _bankAccountNameController.text = p['bankAccountName'] ?? '';
        _citizenIdController.text = p['citizenId'] ?? '';

        _certificates = decodeTrainerDocuments(
          certificates: p['certificates'],
          scoreReportUrl: p['scoreReportUrl'],
          pedagogicalDegreeUrl: p['pedagogicalDegreeUrl'],
          cvUrl: p['cvUrl'],
          degreeUrl: p['degreeUrl'],
          ieltsUrl: p['ieltsUrl'],
        );
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ToastHelper.showError(
          context,
          result['message'] ?? 'KhÃ´ng thá»ƒ táº£i thÃ´ng tin há»“ sÆ¡.',
        );
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

      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/diqekap4o/image/upload',
      );
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'hango_preset'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            picked.bytes,
            filename: picked.name,
          ),
        );

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
          ToastHelper.showSuccess(
            context,
            'Táº£i lÃªn áº£nh Ä‘áº¡i diá»‡n thÃ nh cÃ´ng!',
          );
        }
      } else {
        throw Exception('Cloudinary error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isUploadingAvatar = false;
      });
      if (mounted) {
        ToastHelper.showError(context, 'Lá»—i táº£i áº£nh: $e');
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
      _phoneNumberError =
          phoneNumber.isEmpty ||
          phoneNumber.length != 10 ||
          !numRegex.hasMatch(phoneNumber);
      _bioError = bio.isEmpty || bio.length < 50;
      _bankAccountError =
          bankAccount.isNotEmpty && !numRegex.hasMatch(bankAccount);
      _bankAccountNameError =
          bankAccountName.isNotEmpty && !nameRegex.hasMatch(bankAccountName);
      _citizenIdError =
          citizenId.isNotEmpty &&
          (citizenId.length != 12 || !numRegex.hasMatch(citizenId));
    });

    if (_fullNameError) {
      ToastHelper.showError(
        context,
        isVi ? 'Vui lÃ²ng nháº­p há» vÃ  tÃªn.' : 'Please enter full name.',
      );
      return false;
    }
    if (_phoneNumberError) {
      ToastHelper.showError(
        context,
        isVi
            ? 'Sá»‘ Ä‘iá»‡n thoáº¡i khÃ´ng há»£p lá»‡ (10 chá»¯ sá»‘).'
            : 'Invalid phone number (10 digits).',
      );
      return false;
    }
    if (_bioError) {
      ToastHelper.showError(
        context,
        isVi
            ? 'Giá»›i thiá»‡u báº£n thÃ¢n cáº§n tá»‘i thiá»ƒu 50 kÃ½ tá»±.'
            : 'Bio must be at least 50 characters.',
      );
      return false;
    }
    if (_gender == null) {
      ToastHelper.showError(
        context,
        isVi ? 'Vui lÃ²ng chá»n giá»›i tÃ­nh.' : 'Please select gender.',
      );
      return false;
    }
    if (_bankAccountError) {
      ToastHelper.showError(
        context,
        isVi
            ? 'Sá»‘ tÃ i khoáº£n ngÃ¢n hÃ ng chá»‰ Ä‘Æ°á»£c phÃ©p chá»©a kÃ½ tá»± sá»‘.'
            : 'Bank account digits only.',
      );
      return false;
    }
    if (_bankAccountNameError) {
      ToastHelper.showError(
        context,
        isVi
            ? 'TÃªn chá»§ tÃ i khoáº£n viáº¿t hoa khÃ´ng dáº¥u.'
            : 'Owner name must be UPPERCASE.',
      );
      return false;
    }
    if (_citizenIdError) {
      ToastHelper.showError(
        context,
        isVi
            ? 'Sá»‘ CCCD pháº£i gá»“m Ä‘Ãºng 12 chá»¯ sá»‘.'
            : 'Citizen ID must be 12 digits.',
      );
      return false;
    }

    final normalizedCertificates = normalizeTrainerDocuments(_certificates);
    final hasProof = normalizedCertificates.isNotEmpty;

    if (!hasProof) {
      ToastHelper.showError(
        context,
        isVi
            ? 'Vui lÃ²ng táº£i lÃªn Ã­t nháº¥t má»™t báº±ng cáº¥p hoáº·c chá»©ng chá»‰ nÄƒng lá»±c.'
            : 'Please upload at least one credentials proof.',
      );
      return false;
    }

    if (_trainerType == 'PROFESSIONAL' &&
        !normalizedCertificates.any(
          (doc) => isPedagogicalTrainerDocument(doc['type']),
        )) {
      ToastHelper.showError(
        context,
        isVi
            ? 'Giáº£ng viÃªn chuyÃªn mÃ´n cáº§n cÃ³ Ã­t nháº¥t má»™t minh chá»©ng sÆ° pháº¡m, chá»©ng chá»‰ giáº£ng dáº¡y hoáº·c CV giáº£ng dáº¡y.'
            : 'Professional trainers must provide at least one pedagogical proof, teaching certificate, or teaching CV.',
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
    payload['username'] = _usernameController.text.trim();
    payload['address'] = _addressController.text.trim();
    if (_dobController.text.trim().isNotEmpty) {
      final parts = _dobController.text.split('/');
      if (parts.length == 3) {
        payload['dateOfBirth'] = '${parts[2]}-${parts[1]}-${parts[0]}';
      }
    }
    payload['bankName'] = _selectedBank ?? '';
    payload['bankAccount'] = _bankAccountController.text.trim();
    payload['bankAccountName'] = _bankAccountNameController.text
        .trim()
        .toUpperCase();
    payload.addAll(buildTrainerDocumentPayload(_certificates));
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
            LanguageManager.isVi
                ? 'Cáº­p nháº­t há»“ sÆ¡ thÃ nh cÃ´ng!'
                : 'Profile updated successfully!',
          );
        }
      } else if (mounted) {
        ToastHelper.showError(
          context,
          result['message'] ?? 'Cáº­p nháº­t tháº¥t báº¡i.',
        );
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
      drawer: !isDesktop
          ? const Drawer(child: TrainerSidebar(activeIndex: 5))
          : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(width: 260, child: TrainerSidebar(activeIndex: 5)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InternalAppHeader(isMobile: !isDesktop, showLogo: !isDesktop),
                Expanded(child: _buildBodyContent(isVi)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(bool isVi) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF20B486)),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isVi ? 'Há»“ sÆ¡ cá»§a tÃ´i' : 'My Profile',
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
                    Expanded(child: _buildFormFields(isVi)),
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
        'title': isVi ? 'ThÃ´ng tin cÃ¡ nhÃ¢n' : 'Personal Info',
        'subtitle': isVi ? 'Há» tÃªn, email & bio' : 'Name, contact & bio',
        'icon': Icons.person_outline_rounded,
        'activeColor': const Color(0xFF28B79B),
      },
      {
        'index': 1,
        'title': isVi ? 'CV & Báº±ng cáº¥p' : 'CV & Degrees',
        'subtitle': isVi
            ? 'Kinh nghiá»‡m & chá»©ng chá»‰'
            : 'Experience & certificates',
        'icon': Icons.badge_outlined,
        'activeColor': const Color(0xFF0284C7),
      },
      {
        'index': 2,
        'title': isVi ? 'TÃ i khoáº£n NgÃ¢n hÃ ng' : 'Bank Account',
        'subtitle': isVi ? 'Nháº­n tiá»n doanh thu' : 'Payout & Tax ID',
        'icon': Icons.account_balance_outlined,
        'activeColor': const Color(0xFF8B5CF6),
      },
      {
        'index': 3,
        'title': isVi ? 'Äá»•i máº­t kháº©u' : 'Security',
        'subtitle': isVi ? 'Máº­t kháº©u & báº£o máº­t' : 'Password & security',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withOpacity(0.08)
                      : Colors.white,
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
                          ),
                        ]
                      : [
                          const BoxShadow(
                            color: Color(0x05000000),
                            blurRadius: 4,
                            offset: Offset(0, 2),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF64748B),
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
                              color: isSelected
                                  ? activeColor
                                  : const Color(0xFF0F172A),
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
        'title': isVi ? 'ThÃ´ng tin cÃ¡ nhÃ¢n' : 'Personal Info',
        'subtitle': isVi ? 'Há» tÃªn, email & bio' : 'Name, contact & bio',
        'icon': Icons.person_outline_rounded,
        'activeColor': const Color(0xFF28B79B),
      },
      {
        'index': 1,
        'title': isVi ? 'CV & Báº±ng cáº¥p' : 'CV & Degrees',
        'subtitle': isVi
            ? 'Kinh nghiá»‡m & chá»©ng chá»‰'
            : 'Experience & certificates',
        'icon': Icons.badge_outlined,
        'activeColor': const Color(0xFF0284C7),
      },
      {
        'index': 2,
        'title': isVi ? 'TÃ i khoáº£n NgÃ¢n hÃ ng' : 'Bank Account',
        'subtitle': isVi ? 'Nháº­n tiá»n doanh thu' : 'Payout & Tax ID',
        'icon': Icons.account_balance_outlined,
        'activeColor': const Color(0xFF8B5CF6),
      },
      {
        'index': 3,
        'title': isVi ? 'Äá»•i máº­t kháº©u' : 'Security',
        'subtitle': isVi ? 'Máº­t kháº©u & báº£o máº­t' : 'Password & security',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withOpacity(0.08)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? activeColor.withOpacity(0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? activeColor
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF64748B),
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
                              color: isSelected
                                  ? activeColor
                                  : const Color(0xFF0F172A),
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
                      Icon(
                        Icons.chevron_right_rounded,
                        color: activeColor,
                        size: 20,
                      ),
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
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF20B486),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          _trainerInitials,
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF20B486),
                            fontFamily: 'Outfit',
                          ),
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
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 14,
                          ),
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
                  _fullNameController.text.isNotEmpty
                      ? _fullNameController.text
                      : _trainerName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _userEmail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _trainerType == 'PROFESSIONAL'
                        ? (isVi
                              ? 'GiÃ¡o viÃªn ChuyÃªn nghiá»‡p'
                              : 'Professional')
                        : (isVi ? 'Gia sÆ°' : 'Tutor'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF20B486),
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

  // Box 1: ThÃ´ng tin cÃ¡ nhÃ¢n
    Widget _buildBox0PersonalInfo(bool isVi) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4F1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: Color(0xFF28B79B),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isVi ? '1. Thông tin cá nhân' : '1. Personal Information',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
            OutlinedButton.icon(
              onPressed: _showUpdatePersonalInfoModal,
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: Text(isVi ? 'Cập nhật' : 'Update'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF28B79B),
                side: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth > 550) {
              return Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          isVi ? 'Họ và tên' : 'Full Name',
                          _fullNameController.text,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildReadOnlyField(
                          isVi ? 'Tên đăng nhập' : 'Name account',
                          _usernameController.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          isVi ? 'Số điện thoại' : 'Phone Number',
                          _phoneNumberController.text,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildReadOnlyField(
                          isVi ? 'Ngày sinh' : 'Date of birth',
                          _dobController.text,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _buildReadOnlyField(
                          isVi ? 'Địa chỉ' : 'Address',
                          _addressController.text,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: _buildReadOnlyField(
                          isVi ? 'Giới tính' : 'Gender',
                          _gender == 'MALE' ? (isVi ? 'Nam' : 'Male') : (_gender == 'FEMALE' ? (isVi ? 'Nữ' : 'Female') : ''),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            }
            return Column(
              children: [
                _buildReadOnlyField(isVi ? 'Họ và tên' : 'Full Name', _fullNameController.text),
                const SizedBox(height: 16),
                _buildReadOnlyField(isVi ? 'Tên đăng nhập' : 'Name account', _usernameController.text),
                const SizedBox(height: 16),
                _buildReadOnlyField(isVi ? 'Số điện thoại' : 'Phone Number', _phoneNumberController.text),
                const SizedBox(height: 16),
                _buildReadOnlyField(isVi ? 'Ngày sinh' : 'Date of birth', _dobController.text),
                const SizedBox(height: 16),
                _buildReadOnlyField(isVi ? 'Địa chỉ' : 'Address', _addressController.text),
                const SizedBox(height: 16),
                _buildReadOnlyField(isVi ? 'Giới tính' : 'Gender', _gender == 'MALE' ? (isVi ? 'Nam' : 'Male') : (_gender == 'FEMALE' ? (isVi ? 'Nữ' : 'Female') : '')),
              ],
            );
          },
        ),
      ],
    );
  }

  void _showUpdatePersonalInfoModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: _UpdateTrainerProfileModal(
              initialFullName: _fullNameController.text,
              initialUsername: _usernameController.text,
              initialDob: _dobController.text,
              initialPhone: _phoneNumberController.text,
              initialAddress: _addressController.text,
              initialGender: _gender ?? '',
              initialAvatarUrl: _avatarUrl ?? '',
              onSave: (Map<String, dynamic> data) {
                setState(() {
                  _fullNameController.text = data['fullName'];
                  _usernameController.text = data['username'];
                  _dobController.text = data['dob'];
                  _addressController.text = data['address'];
                  _phoneNumberController.text = data['phone'];
                  _gender = data['gender'];
                  if (data['avatarUrl'] != null && data['avatarUrl'].isNotEmpty) {
                    _avatarUrl = data['avatarUrl'];
                  }
                });
                _handleSave(); // Trigger the API save
              },
            ),
          ),
        );
      },
    );
  }

  // Box 2: CV, Kinh nghiá»‡m & Báº±ng cáº¥p
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
              child: const Icon(
                Icons.badge_outlined,
                color: Color(0xFF0284C7),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isVi
                  ? '2. CV & Kinh nghiá»‡m giáº£ng dáº¡y'
                  : '2. CV & Teaching Experience',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildInputField(
          isVi
              ? 'NÆ¡i lÃ m viá»‡c / TrÆ°á»ng Ä‘Ã o táº¡o'
              : 'Workplace / Organization',
          _workplaceController,
        ),
        const SizedBox(height: 16),
        _buildInputField(
          isVi
              ? 'Giá»›i thiá»‡u báº£n thÃ¢n & Kinh nghiá»‡m *'
              : 'Bio & Experience *',
          _bioController,
          maxLines: 5,
          errorText: _bioError
              ? (isVi
                    ? 'Giá»›i thiá»‡u cáº§n tá»« 50 kÃ½ tá»±'
                    : 'Bio must be >= 50 characters')
              : null,
        ),
        const SizedBox(height: 24),
        Text(
          isVi
              ? 'Báº±ng cáº¥p & Chá»©ng chá»‰ nÄƒng lá»±c'
              : 'Degrees & Certificates',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          isVi
              ? 'Táº£i lÃªn Ã­t nháº¥t má»™t tÃ i liá»‡u chá»©ng minh nÄƒng lá»±c Ä‘á»ƒ hoÃ n táº¥t há»“ sÆ¡.'
              : 'Upload at least one credentials proof to complete your profile.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        _buildUnifiedUploadBox(isVi),
        const SizedBox(height: 24),
        _buildSaveButtonRow(isVi),
      ],
    );
  }

  // Box 3: TÃ i khoáº£n NgÃ¢n hÃ ng
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
              child: const Icon(
                Icons.account_balance_outlined,
                color: Color(0xFF8B5CF6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              isVi
                  ? '3. Cáº¥u hÃ¬nh TÃ i khoáº£n thá»¥ hÆ°á»Ÿng'
                  : '3. Bank Account & Payout',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
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
                      const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFF28B79B),
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isVi
                            ? 'TÃ€I KHOáº¢N THá»¤ HÆ¯á»žNG Báº¢O Máº¬T'
                            : 'SECURED PAYOUT ACCOUNT',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF28B79B),
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _selectedBank ?? (isVi ? 'NGÃ‚N HÃ€NG' : 'BANK'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white70,
                      fontSize: 12,
                    ),
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
                        isVi ? 'CHá»¦ TÃ€I KHOáº¢N' : 'ACCOUNT OWNER',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _bankAccountNameController.text.isNotEmpty
                            ? _bankAccountNameController.text.toUpperCase()
                            : (isVi ? 'CHÆ¯A Cáº¬P NHáº¬T' : 'NOT UPDATED'),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        isVi ? 'MÃƒ Sá» THUáº¾' : 'TAX ID',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _citizenIdController.text.isNotEmpty
                            ? _citizenIdController.text
                            : '---',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
          isVi ? 'NgÃ¢n hÃ ng thá»¥ hÆ°á»Ÿng' : 'Beneficiary Bank',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF334155),
            fontFamily: 'Outfit',
          ),
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
              hint: Text(isVi ? 'Chá»n ngÃ¢n hÃ ng' : 'Select bank'),
              items: _bankSuggestions.map((String b) {
                return DropdownMenuItem<String>(value: b, child: Text(b));
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
          isVi ? 'Sá»‘ tÃ i khoáº£n ngÃ¢n hÃ ng' : 'Bank Account Number',
          _bankAccountController,
          keyboardType: TextInputType.number,
          errorText: _bankAccountError
              ? (isVi ? 'Chá»‰ nháº­p sá»‘' : 'Digits only')
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        _buildInputField(
          isVi
              ? 'TÃªn chá»§ tÃ i khoáº£n (viáº¿t hoa khÃ´ng dáº¥u)'
              : 'Account Owner Name',
          _bankAccountNameController,
          errorText: _bankAccountNameError
              ? (isVi ? 'Viáº¿t hoa khÃ´ng dáº¥u' : 'UPPERCASE only')
              : null,
          onChanged: (val) {
            _bankAccountNameController.value = _bankAccountNameController.value
                .copyWith(
                  text: val.toUpperCase(),
                  selection: TextSelection.collapsed(offset: val.length),
                );
            setState(() {});
          },
        ),
        const SizedBox(height: 16),
        _buildInputField(
          isVi
              ? 'MÃ£ sá»‘ thuáº¿ (Tax ID)'
              : 'Tax Identification Number (Tax ID)',
          _citizenIdController,
          keyboardType: TextInputType.number,
          maxLength: 13,
          errorText: _citizenIdError
              ? (isVi ? 'MÃ£ sá»‘ thuáº¿ khÃ´ng há»£p lá»‡' : 'Invalid Tax ID')
              : null,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 24),
        _buildSaveButtonRow(isVi),
      ],
    );
  }

  // Box 4: Thay Ä‘á»•i máº­t kháº©u
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
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Icon(Icons.save_rounded, size: 18),
          label: Text(isVi ? 'LÆ°u thay Ä‘á»•i' : 'Save Changes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF20B486),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
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
          isVi ? '4. Äá»•i máº­t kháº©u' : '4. Security & Change Password',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          isVi
              ? 'Cáº­p nháº­t máº­t kháº©u Ä‘Äƒng nháº­p tÃ i khoáº£n cá»§a báº¡n.'
              : 'Update your account login password.',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        _buildInputField(
          isVi ? 'Máº­t kháº©u hiá»‡n táº¡i *' : 'Current Password *',
          currentPwdController,
          isPassword: true,
        ),
        const SizedBox(height: 12),
        _buildInputField(
          isVi ? 'Máº­t kháº©u má»›i *' : 'New Password *',
          newPwdController,
          isPassword: true,
        ),
        const SizedBox(height: 12),
        _buildInputField(
          isVi ? 'XÃ¡c nháº­n máº­t kháº©u má»›i *' : 'Confirm New Password *',
          confirmPwdController,
          isPassword: true,
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: () async {
              final cur = currentPwdController.text.trim();
              final newP = newPwdController.text.trim();
              final confP = confirmPwdController.text.trim();

              if (cur.isEmpty || newP.isEmpty || confP.isEmpty) {
                ToastHelper.showError(
                  context,
                  isVi
                      ? 'Vui lÃ²ng nháº­p Ä‘áº§y Ä‘á»§ thÃ´ng tin máº­t kháº©u.'
                      : 'Please fill out all password fields.',
                );
                return;
              }
              if (newP.length < 6) {
                ToastHelper.showError(
                  context,
                  isVi
                      ? 'Máº­t kháº©u má»›i pháº£i cÃ³ tá»‘i thiá»ƒu 6 kÃ½ tá»±.'
                      : 'New password must be at least 6 characters.',
                );
                return;
              }
              if (newP != confP) {
                ToastHelper.showError(
                  context,
                  isVi
                      ? 'Máº­t kháº©u xÃ¡c nháº­n khÃ´ng khá»›p.'
                      : 'Confirm password does not match.',
                );
                return;
              }

              final authService = AuthService();
              final res = await authService.changePassword(cur, newP);
              if (context.mounted) {
                if (res['success'] == true) {
                  ToastHelper.showSuccess(
                    context,
                    isVi
                        ? 'Äá»•i máº­t kháº©u thÃ nh cÃ´ng!'
                        : 'Password changed successfully!',
                  );
                  currentPwdController.clear();
                  newPwdController.clear();
                  confirmPwdController.clear();
                } else {
                  ToastHelper.showError(
                    context,
                    res['message'] ??
                        (isVi
                            ? 'Äá»•i máº­t kháº©u tháº¥t báº¡i.'
                            : 'Failed to change password.'),
                  );
                }
              }
            },
            icon: const Icon(
              Icons.lock_reset_rounded,
              color: Color(0xFF28B79B),
              size: 18,
            ),
            label: Text(
              isVi ? 'Cáº­p nháº­t máº­t kháº©u' : 'Update Password',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF28B79B),
                fontFamily: 'Outfit',
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF28B79B)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputField(
    String label,
    TextEditingController controller, {
    TextInputType? keyboardType,
    int maxLines = 1,
    int? maxLength,
    String? errorText,
    bool isPassword = false,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF334155),
            fontFamily: 'Outfit',
          ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
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
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF334155),
            fontFamily: 'Outfit',
          ),
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
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ],
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

  Future<Map<String, String>?> _uploadFileToCloudinaryWithDetails() async {
    try {
      final picked = await pickImage();
      if (picked == null || picked.bytes == null) return null;

      final url = Uri.parse(
        'https://api.cloudinary.com/v1_1/diqekap4o/image/upload',
      );
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'hango_preset'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            picked.bytes!,
            filename: picked.name,
          ),
        );

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

  Future<String?> _uploadFileToCloudinary() async {
    final res = await _uploadFileToCloudinaryWithDetails();
    return res?['url'];
  }

  void _showAddCertificateModal(bool isVi) {
    final nameController = TextEditingController();
    String? tempUrl;
    bool isUploading = false;
    String selectedDocType = trainerDocTypeOther;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
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
                          isVi
                              ? 'Thêm chứng chỉ / Bằng cấp'
                              : 'Add Degree & Certificate',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
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
                      decoration: InputDecoration(
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
                    Text(
                      isVi ? 'Loại tài liệu *' : 'Document Type *',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: Color(0xFF475569),
                        fontFamily: 'Outfit',
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
                    Text(
                      isVi
                          ? 'Ảnh chứng chỉ / Bằng cấp *'
                          : 'Certificate / Degree Image *',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: isUploading
                          ? null
                          : () async {
                              setModalState(() => isUploading = true);
                              final uploaded =
                                  await _uploadFileToCloudinaryWithDetails();
                              if (uploaded != null && uploaded['url'] != null) {
                                setModalState(() {
                                  tempUrl = uploaded['url'];
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
                            color: const Color(0xFFCBD5E1),
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
                                        ? 'Đang tải ảnh...'
                                        : 'Uploading image...',
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
                                                          ? 'Đổi ảnh khác'
                                                          : 'Change Image',
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
                                              ? 'Nhấp để tải lên ảnh mới (JPG, PNG, PDF)'
                                              : 'Click to upload document image (JPG, PNG, PDF)',
                                          style: const TextStyle(
                                            color: Color(0xFF28B79B),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
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
                          onPressed:
                              (tempUrl != null &&
                                  nameController.text.trim().isNotEmpty &&
                                  selectedDocType != trainerDocTypeOther)
                              ? () {
                                  setState(() {
                                    _certificates = normalizeTrainerDocuments([
                                      ..._certificates,
                                      {
                                        'type': selectedDocType,
                                        'name': nameController.text.trim(),
                                        'url': tempUrl!,
                                        'source': 'trainer_profile_manual',
                                      },
                                    ]);
                                  });
                                  Navigator.pop(context);
                                  ToastHelper.showSuccess(
                                    context,
                                    isVi
                                        ? 'Đã thêm chứng chỉ!'
                                        : 'Certificate added!',
                                  );
                                }
                              : null,
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
                isVi
                    ? 'Danh sÃ¡ch tÃ i liá»‡u Ä‘Ã£ táº£i lÃªn'
                    : 'Uploaded Documents',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF334155),
                  fontSize: 13,
                ),
              ),
              Text(
                '${_certificates.length} ${isVi ? 'tÃ i liá»‡u' : 'documents'}',
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
                  isVi
                      ? 'ChÆ°a cÃ³ tÃ i liá»‡u nÃ o Ä‘Æ°á»£c táº£i lÃªn.'
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
                        ? 'Chá»©ng chá»‰ ${idx + 1}'
                        : 'Certificate ${idx + 1}');
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
                                  constraints: const BoxConstraints(
                                    maxWidth: 800,
                                    maxHeight: 600,
                                  ),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                  ),
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
                                const Icon(
                                  Icons.insert_drive_file_outlined,
                                  color: Color(0xFF94A3B8),
                                ),
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
                            InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => Dialog(
                                    child: Container(
                                      constraints: const BoxConstraints(
                                        maxWidth: 800,
                                        maxHeight: 600,
                                      ),
                                      child: Image.network(
                                        url,
                                        fit: BoxFit.contain,
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: Text(
                                isVi
                                    ? 'Xem áº£nh chá»©ng chá»‰'
                                    : 'View certificate image',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF20B486),
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.redAccent,
                          size: 20,
                        ),
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
                          ? 'ThÃªm chá»©ng chá»‰, báº±ng cáº¥p'
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
    );
  }
}

// ------------------------------------------------------------------------
// MODAL DIALOG STATEFUL WIDGET FOR TRAINER PROFILE
// ------------------------------------------------------------------------
class _UpdateTrainerProfileModal extends StatefulWidget {
  final String initialFullName;
  final String initialUsername;
  final String initialDob;
  final String initialPhone;
  final String initialAddress;
  final String initialGender;
  final String initialAvatarUrl;
  final Function(Map<String, dynamic>) onSave;

  const _UpdateTrainerProfileModal({
    super.key,
    required this.initialFullName,
    required this.initialUsername,
    required this.initialDob,
    required this.initialPhone,
    required this.initialAddress,
    required this.initialGender,
    required this.initialAvatarUrl,
    required this.onSave,
  });

  @override
  State<_UpdateTrainerProfileModal> createState() => _UpdateTrainerProfileModalState();
}

class _UpdateTrainerProfileModalState extends State<_UpdateTrainerProfileModal> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _usernameController;
  late TextEditingController _dobController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late String _gender;
  late String _avatarUrl;
  bool _isUploadingAvatar = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialFullName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _dobController = TextEditingController(text: widget.initialDob);
    _phoneController = TextEditingController(text: widget.initialPhone);
    _addressController = TextEditingController(text: widget.initialAddress);
    _gender = widget.initialGender;
    _avatarUrl = widget.initialAvatarUrl;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _dobController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final pickedFile = await pickImage();
    if (pickedFile != null) {
      setState(() => _isUploadingAvatar = true);
      try {
        final res = await AuthService().uploadAvatar(pickedFile);
        if (res['success'] == true && mounted) {
          setState(() {
            _avatarUrl = res['data']['avatarUrl'];
            _isUploadingAvatar = false;
          });
        } else {
          throw Exception('Upload failed');
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingAvatar = false);
          ToastHelper.showError(context, 'Lỗi khi tải ảnh lên.');
        }
      }
    }
  }

  Widget _buildFieldsRow(List<Widget> children) {
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth > 550) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: children[0]),
              const SizedBox(width: 20),
              Expanded(child: children[1]),
            ],
          );
        }
        return Column(
          children: [
            children[0],
            const SizedBox(height: 20),
            children[1],
          ],
        );
      },
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    String? hint,
    Widget? suffixIcon,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly,
          onTap: onTap,
          style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
          decoration: InputDecoration(
            errorMaxLines: 3,
            hintText: hint,
            suffixIcon: suffixIcon,
            hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFEF4444)),
            ),
            filled: true,
            fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildGenderOption(
    String label,
    IconData icon,
    String selected,
    ValueChanged<String> onChanged,
  ) {
    final isSelected = selected == (label == 'Male' ? 'MALE' : 'FEMALE');
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(label == 'Male' ? 'MALE' : 'FEMALE'),
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? const Color(0xFF28B79B) : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontFamily: 'Outfit',
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenderSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              _buildGenderOption('Male', Icons.male_rounded, _gender, (val) => setState(() => _gender = val)),
              _buildGenderOption('Female', Icons.female_rounded, _gender, (val) => setState(() => _gender = val)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 16,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Update Profile',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      // Avatar
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFFE2E8F0),
                                border: Border.all(color: const Color(0xFFCBD5E1), width: 2),
                              ),
                              child: ClipOval(
                                child: _avatarUrl.isNotEmpty
                                    ? Image.network(
                                        _avatarUrl,
                                        fit: BoxFit.cover,
                                      )
                                    : Container(
                                        color: const Color(0xFFE6FFFA),
                                        child: Center(
                                          child: Text(
                                            'T',
                                            style: const TextStyle(
                                              color: Color(0xFF28B79B),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 32,
                                              fontFamily: 'Outfit',
                                            ),
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            if (_isUploadingAvatar)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.4),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: InkWell(
                                onTap: _isUploadingAvatar ? null : _pickAvatar,
                                customBorder: const CircleBorder(),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF28B79B),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.camera_alt_rounded,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 30),
                      
                      // Input Fields Row 1
                      _buildFieldsRow([
                        _buildInputField(
                          label: 'Full name*',
                          controller: _nameController,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter your full name' : null,
                        ),
                        _buildInputField(
                          label: 'Name account*',
                          controller: _usernameController,
                          validator: (v) => v == null || v.trim().isEmpty ? 'Please enter a username' : null,
                        ),
                      ]),
                      const SizedBox(height: 20),
                      
                      // Input Fields Row 2
                      _buildFieldsRow([
                        _buildInputField(
                          label: 'Phone number*',
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please enter your phone number';
                            if (!RegExp(r'^(0[3|5|7|8|9])+([0-9]{8})$').hasMatch(v)) {
                              return 'Please enter a valid 10-digit Vietnamese phone number (e.g. 0912345678)';
                            }
                            return null;
                          },
                        ),
                        _buildInputField(
                          label: 'date of birth*',
                          controller: _dobController,
                          hint: 'DD/MM/YYYY',
                          readOnly: true,
                          suffixIcon: const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF64748B)),
                          onTap: () async {
                            DateTime initialDate = DateTime.now().subtract(const Duration(days: 365 * 18));
                            if (_dobController.text.isNotEmpty) {
                              final parts = _dobController.text.split('/');
                              if (parts.length == 3) {
                                final parsed = DateTime.tryParse('${parts[2]}-${parts[1]}-${parts[0]}');
                                if (parsed != null) {
                                  initialDate = parsed;
                                }
                              }
                            }
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: initialDate,
                              firstDate: DateTime(1900),
                              lastDate: DateTime.now(),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: const ColorScheme.light(
                                      primary: Color(0xFF28B79B),
                                      onPrimary: Colors.white,
                                      onSurface: Color(0xFF1E293B),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              final day = picked.day.toString().padLeft(2, '0');
                              final month = picked.month.toString().padLeft(2, '0');
                              final year = picked.year.toString();
                              _dobController.text = '$day/$month/$year';
                            }
                          },
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please select your date of birth';
                            final parts = v.split('/');
                            if (parts.length != 3) return 'Please enter date in DD/MM/YYYY format';
                            return null;
                          },
                        ),
                      ]),
                      const SizedBox(height: 20),
                      
                      // Input Fields Row 3
                      _buildFieldsRow([
                        _buildInputField(
                          label: 'Address',
                          controller: _addressController,
                        ),
                        _buildGenderSelector(),
                      ]),
                      
                      const SizedBox(height: 30),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              widget.onSave({
                                'fullName': _nameController.text.trim(),
                                'username': _usernameController.text.trim(),
                                'dob': _dobController.text.trim(),
                                'phone': _phoneController.text.trim(),
                                'address': _addressController.text.trim(),
                                'gender': _gender,
                                'avatarUrl': _avatarUrl,
                              });
                              Navigator.of(context).pop();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Update',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
