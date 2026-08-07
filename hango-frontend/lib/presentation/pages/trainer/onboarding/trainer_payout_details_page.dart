import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../data/services/auth_service.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/language_manager.dart';
import 'trainer_onboarding_shell_page.dart';
import '../trainer_dashboard_page.dart';
import '../../login_page.dart';

class TrainerPayoutDetailsPage extends StatefulWidget {
  final Map<String, dynamic> initialProfile;
  final bool isEmbedded;

  const TrainerPayoutDetailsPage({
    super.key,
    required this.initialProfile,
    this.isEmbedded = false,
  });

  @override
  State<TrainerPayoutDetailsPage> createState() => _TrainerPayoutDetailsPageState();
}

class _TrainerPayoutDetailsPageState extends State<TrainerPayoutDetailsPage> {
  final _onboardingService = TrainerOnboardingService();
  final _authService = AuthService();
  bool _isSubmitting = false;

  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  final _taxCodeController = TextEditingController();

  String _userProfileFullName = '';
  String _trainerName = '';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  bool _bankNameError = false;
  bool _bankAccountError = false;
  bool _bankAccountNameError = false;
  bool _taxCodeError = false;

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
    _populateFields(widget.initialProfile);
    _loadUserProfileName();
    _loadTrainerHeaderInfo();
    _bankAccountController.addListener(_onBankAccountChanged);
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

  void _populateFields(Map<String, dynamic> p) {
    _bankNameController.text = p['bankName'] ?? '';
    _bankAccountController.text = p['bankAccount'] ?? '';
    _bankAccountNameController.text = p['bankAccountName'] ?? '';
    _taxCodeController.text = p['taxCode']?.toString().isNotEmpty == true
        ? p['taxCode']
        : (p['citizenId'] ?? '');
  }

  void _onBankAccountChanged() {
    // Keep empty until user types
  }

  Future<void> _loadUserProfileName() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('user_fullname') ?? '';
    if (name.isNotEmpty) {
      setState(() {
        _userProfileFullName = name;
      });
    }
  }

  bool _validateFields() {
    final isVi = LanguageManager.isVi;
    final bankName = _bankNameController.text.trim();
    final bankAccount = _bankAccountController.text.trim();
    final bankAccountName = _bankAccountNameController.text.trim();
    final taxCode = _taxCodeController.text.trim();

    final numRegex = RegExp(r'^\d+$');
    final nameRegex = RegExp(r'^[A-Z ]+$');

    setState(() {
      _bankNameError = bankName.isEmpty;
      _bankAccountError = bankAccount.isEmpty || bankAccount.length < 6 || bankAccount.length > 20 || !numRegex.hasMatch(bankAccount);
      _bankAccountNameError = bankAccountName.isEmpty || !nameRegex.hasMatch(bankAccountName);
      _taxCodeError = taxCode.isEmpty || taxCode.length < 10 || taxCode.length > 13 || !numRegex.hasMatch(taxCode);
    });

    if (_bankNameError) {
      ToastHelper.showError(context, isVi ? 'Vui lòng chọn ngân hàng thụ hưởng.' : 'Please select a beneficiary bank.');
      return false;
    }
    if (_bankAccountError) {
      ToastHelper.showError(
        context,
        isVi
            ? 'Số tài khoản ngân hàng không hợp lệ (Phải từ 6-20 chữ số).'
            : 'Bank account number must be 6 to 20 digits.',
      );
      return false;
    }
    if (_bankAccountNameError) {
      ToastHelper.showError(
        context,
        isVi
            ? 'Tên chủ tài khoản phải viết VIẾT HOA KHÔNG DẤU (Ví dụ: NGUYEN VAN A).'
            : 'Account owner name must be UPPERCASE without accents (e.g. NGUYEN VAN A).',
      );
      return false;
    }
    if (_taxCodeError) {
      ToastHelper.showError(
        context,
        isVi
            ? 'Mã số thuế / Số CCCD không hợp lệ (Phải đúng 10 đến 13 chữ số).'
            : 'Tax ID / National ID must be 10 to 13 digits.',
      );
      return false;
    }
    return true;
  }

  void _handleComplete() async {
    if (!_validateFields()) return;

    setState(() {
      _isSubmitting = true;
    });

    final payload = Map<String, dynamic>.from(widget.initialProfile);
    payload['bankName'] = _bankNameController.text.trim();
    payload['bankAccount'] = _bankAccountController.text.trim();
    payload['bankAccountName'] = _bankAccountNameController.text.trim().toUpperCase();
    payload['taxCode'] = _taxCodeController.text.trim();
    payload['citizenId'] = _taxCodeController.text.trim();
    payload['agreementSigned'] = true;

    final result = await _onboardingService.saveProfileDraft(payload);

    setState(() {
      _isSubmitting = false;
    });

    if (mounted) {
      if (result['success'] == true) {
        ToastHelper.showSuccess(
          context,
          LanguageManager.isVi
              ? 'Hoàn thành cấu hình thông tin thanh toán!'
              : 'Payout configuration completed successfully!',
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const TrainerDashboardPage()),
          (route) => false,
        );
      } else {
        ToastHelper.showError(context, result['message'] ?? 'Lỗi lưu thông tin thanh toán.');
      }
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankAccountNameController.dispose();
    _taxCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEmbedded) {
      return TrainerOnboardingShellPage(
        initialBody: TrainerPayoutDetailsPage(
          initialProfile: widget.initialProfile,
          isEmbedded: true,
        ),
      );
    }

    final isVi = LanguageManager.isVi;

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
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
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Color(0xFFE6FDF9),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Color(0xFF28B79B),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isVi ? 'Thông tin thanh toán & CCCD' : 'Payout & Identity Info',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isVi ? 'Nhập tài khoản nhận tiền và mã định danh' : 'Enter payment bank account and identity ID',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF64748B),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 24),

                      // Bank Name
                      Text(
                        isVi ? 'Tên Ngân hàng thụ hưởng *' : 'Beneficiary Bank Name *',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF334155),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _bankSuggestions.contains(_bankNameController.text) ? _bankNameController.text : null,
                        dropdownColor: Colors.white,
                        decoration: InputDecoration(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          fillColor: Colors.white,
                          filled: true,
                          errorText: _bankNameError ? (isVi ? 'Vui lòng chọn ngân hàng' : 'Bank name required') : null,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Color(0xFF28B79B), width: 2),
                          ),
                        ),
                        hint: Text(isVi ? 'Chọn ngân hàng thụ hưởng' : 'Select beneficiary bank'),
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
                        items: _bankSuggestions.map((String b) {
                          return DropdownMenuItem<String>(
                            value: b,
                            child: Text(b),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _bankNameController.text = val;
                              _bankNameError = false;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // Bank Account Number
                      Text(
                        isVi ? 'Số tài khoản ngân hàng *' : 'Bank Account Number *',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF334155),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bankAccountController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          errorText: _bankAccountError ? (isVi ? 'Số tài khoản không hợp lệ' : 'Invalid bank account') : null,
                          hintText: isVi ? 'Chỉ nhập số, ví dụ: 1023928129' : 'Digits only, example: 1023928129',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Bank Account Owner Name
                      Text(
                        isVi ? 'Tên chủ tài khoản (Viết hoa không dấu) *' : 'Account Owner Name (UPPERCASE) *',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF334155),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _bankAccountNameController,
                        onChanged: (val) {
                          _bankAccountNameController.value = _bankAccountNameController.value.copyWith(
                            text: val.toUpperCase(),
                            selection: TextSelection.collapsed(offset: val.length),
                          );
                        },
                        decoration: InputDecoration(
                          errorText: _bankAccountNameError ? (isVi ? 'Tên không hợp lệ' : 'Invalid name') : null,
                          hintText: isVi ? 'Ví dụ: NGUYEN VAN A' : 'Example: NGUYEN VAN A',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Tax Identification Number (Tax ID)
                      Text(
                        isVi ? 'Mã số thuế (Tax ID) *' : 'Tax Identification Number (Tax ID) *',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF334155),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _taxCodeController,
                        keyboardType: TextInputType.number,
                        maxLength: 13,
                        decoration: InputDecoration(
                          errorText: _taxCodeError ? (isVi ? 'Mã số thuế không hợp lệ' : 'Invalid Tax ID number') : null,
                          counterText: '',
                          hintText: '8019283710',
                          fillColor: Colors.white,
                          filled: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _handleComplete,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : Text(
                                  isVi ? 'Hoàn tất cấu hình' : 'Complete Setup',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
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
                'Verification / Payout Configuration',
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
