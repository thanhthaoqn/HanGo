import 'package:flutter/material.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/language_manager.dart';
import 'trainer_onboarding_shell_page.dart';
import '../trainer_dashboard_page.dart';

class TrainerPayoutDetailsPage extends StatefulWidget {
  final Map<String, dynamic> initialProfile;
  final bool isEmbedded;

  const TrainerPayoutDetailsPage({
    super.key,
    required this.initialProfile,
    this.isEmbedded = false,
  });

  @override
  State<TrainerPayoutDetailsPage> createState() =>
      _TrainerPayoutDetailsPageState();
}

class _TrainerPayoutDetailsPageState extends State<TrainerPayoutDetailsPage> {
  final _onboardingService = TrainerOnboardingService();
  bool _isSubmitting = false;

  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  final _taxCodeController = TextEditingController();

  String? _bankNameErrorText;
  String? _bankAccountErrorText;
  String? _bankAccountNameErrorText;
  String? _taxCodeErrorText;

  static const List<String> _bankSuggestions = [
    'Vietcombank (VCB)',
    'Techcombank (TCB)',
    'MBBank (MB)',
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
    _bankAccountController.addListener(_onBankAccountChanged);
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

  bool _isDummyNumber(String input) {
    if (input.isEmpty) return true;
    final allSame = RegExp(r'^(\d)\1+$').hasMatch(input);
    final dummySeq =
        input == '1234567890' ||
        input == '123456789012' ||
        input == '1234567890123' ||
        input == '0123456789';
    return allSame || dummySeq;
  }

  String? _validateBankName(String bankName, bool isVi) {
    if (bankName.isEmpty) {
      return isVi
          ? 'Vui lòng chọn ngân hàng thụ hưởng.'
          : 'Please select a beneficiary bank.';
    }
    return null;
  }

  String? _validateBankAccount(String bankAccount, bool isVi) {
    final numRegex = RegExp(r'^\d+$');

    if (bankAccount.isEmpty) {
      return isVi
          ? 'Vui lòng nhập số tài khoản ngân hàng.'
          : 'Please enter the bank account number.';
    }
    if (!numRegex.hasMatch(bankAccount)) {
      return isVi
          ? 'Số tài khoản ngân hàng chỉ được chứa chữ số.'
          : 'Bank account number must contain digits only.';
    }
    if (bankAccount.length < 6 || bankAccount.length > 20) {
      return isVi
          ? 'Số tài khoản ngân hàng phải có độ dài từ 6 đến 20 chữ số.'
          : 'Bank account number must be between 6 and 20 digits.';
    }
    if (_isDummyNumber(bankAccount)) {
      return isVi
          ? 'Số tài khoản không được là dãy số giả như 0000000000.'
          : 'Bank account cannot be a dummy sequence like 0000000000.';
    }
    return null;
  }

  String? _validateBankAccountName(String bankAccountName, bool isVi) {
    final nameRegex = RegExp(r'^[A-Z ]+$');

    if (bankAccountName.isEmpty) {
      return isVi
          ? 'Vui lòng nhập tên chủ tài khoản.'
          : 'Please enter the account owner name.';
    }
    if (!nameRegex.hasMatch(bankAccountName)) {
      return isVi
          ? 'Tên chủ tài khoản phải viết HOA, không dấu và chỉ gồm chữ cái, ví dụ: NGUYEN VAN A.'
          : 'Account owner name must be UPPERCASE, unaccented, and letters only, for example: NGUYEN VAN A.';
    }
    return null;
  }

  String? _validateTaxCode(String taxCode, bool isVi) {
    final numRegex = RegExp(r'^\d+$');

    if (taxCode.isEmpty) {
      return isVi
          ? 'Vui lòng nhập mã số thuế hoặc số CCCD.'
          : 'Please enter the Tax ID or Citizen ID number.';
    }
    if (!numRegex.hasMatch(taxCode)) {
      return isVi
          ? 'Mã số thuế hoặc CCCD chỉ được chứa chữ số.'
          : 'Tax ID or Citizen ID must contain digits only.';
    }
    if (taxCode.length != 12) {
      return isVi
          ? 'Mã số thuế hoặc CCCD phải có đúng 12 chữ số.'
          : 'Tax ID or Citizen ID must be exactly 12 digits.';
    }
    if (_isDummyNumber(taxCode)) {
      return isVi
          ? 'Mã số thuế hoặc CCCD không được là dãy số giả như 000000000000.'
          : 'Tax ID or Citizen ID cannot be a dummy sequence like 000000000000.';
    }
    return null;
  }

  bool _validateFields() {
    final isVi = LanguageManager.isVi;
    final bankName = _bankNameController.text.trim();
    final bankAccount = _bankAccountController.text.trim();
    final bankAccountName = _bankAccountNameController.text.trim();
    final taxCode = _taxCodeController.text.trim();

    setState(() {
      _bankNameErrorText = _validateBankName(bankName, isVi);
      _bankAccountErrorText = _validateBankAccount(bankAccount, isVi);
      _bankAccountNameErrorText = _validateBankAccountName(
        bankAccountName,
        isVi,
      );
      _taxCodeErrorText = _validateTaxCode(taxCode, isVi);
    });

    return _bankNameErrorText == null &&
        _bankAccountErrorText == null &&
        _bankAccountNameErrorText == null &&
        _taxCodeErrorText == null;
  }

  void _handleComplete() async {
    if (!_validateFields()) return;

    setState(() {
      _isSubmitting = true;
    });

    final payload = Map<String, dynamic>.from(widget.initialProfile);
    payload['bankName'] = _bankNameController.text.trim();
    payload['bankAccount'] = _bankAccountController.text.trim();
    payload['bankAccountName'] = _bankAccountNameController.text
        .trim()
        .toUpperCase();
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
          'Payout details saved successfully! Welcome to your Trainer Dashboard.',
        );

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const TrainerDashboardPage()),
          (route) => false,
        );
      } else {
        ToastHelper.showError(
          context,
          result['message'] ?? 'Failed to save payout details.',
        );
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
                                isVi
                                    ? 'Thông tin thanh toán & CCCD'
                                    : 'Payout & Identity Info',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isVi
                                    ? 'Nhập tài khoản nhận tiền và mã định danh'
                                    : 'Enter payment bank account and identity ID',
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
                      isVi
                          ? 'Tên Ngân hàng thụ hưởng *'
                          : 'Beneficiary Bank Name *',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF334155),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _bankSuggestions.contains(_bankNameController.text)
                          ? _bankNameController.text
                          : null,
                      dropdownColor: Colors.white,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                        errorText: _bankNameErrorText,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF64748B),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF28B79B),
                            width: 2,
                          ),
                        ),
                      ),
                      hint: Text(
                        isVi
                            ? 'Chọn ngân hàng thụ hưởng'
                            : 'Select beneficiary bank',
                      ),
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Color(0xFF64748B),
                      ),
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
                            _bankNameErrorText = _validateBankName(val, isVi);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 24),

                    // Bank Account Number
                    Text(
                      isVi
                          ? 'Số tài khoản ngân hàng *'
                          : 'Bank Account Number *',
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
                      onChanged: (value) {
                        setState(() {
                          _bankAccountErrorText = _validateBankAccount(
                            value.trim(),
                            isVi,
                          );
                        });
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                        errorText: _bankAccountErrorText,
                        hintText: isVi
                            ? 'Chỉ nhập số, ví dụ: 1023928129'
                            : 'Digits only, example: 1023928129',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF64748B),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF28B79B),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Bank Account Owner Name
                    Text(
                      isVi
                          ? 'Tên chủ tài khoản (Viết hoa không dấu) *'
                          : 'Account Owner Name (UPPERCASE) *',
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
                        _bankAccountNameController.value =
                            _bankAccountNameController.value.copyWith(
                              text: val.toUpperCase(),
                              selection: TextSelection.collapsed(
                                offset: val.length,
                              ),
                            );
                        setState(() {
                          _bankAccountNameErrorText = _validateBankAccountName(
                            val.trim().toUpperCase(),
                            isVi,
                          );
                        });
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                        errorText: _bankAccountNameErrorText,
                        hintText: isVi
                            ? 'Ví dụ: NGUYEN VAN A'
                            : 'Example: NGUYEN VAN A',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF64748B),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF28B79B),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Tax Identification Number (Tax ID / Citizen ID)
                    Text(
                      isVi
                          ? 'Mã số thuế / Số CCCD (Tax ID / Citizen ID) *'
                          : 'Tax Identification / Citizen ID Number *',
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
                      maxLength: 12,
                      onChanged: (value) {
                        setState(() {
                          _taxCodeErrorText = _validateTaxCode(
                            value.trim(),
                            isVi,
                          );
                        });
                      },
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        errorText: _taxCodeErrorText,
                        counterText: '',
                        hintText: isVi
                            ? 'Nhập 12 số CCCD / Mã số thuế'
                            : 'Enter 12-digit Citizen ID / Tax ID',
                        helperText: isVi
                            ? 'Mã số thuế cá nhân hoặc số CCCD gắn chip (đúng 12 chữ số).'
                            : 'Personal Tax ID or Citizen ID number (exactly 12 digits).',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF64748B),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF28B79B),
                            width: 2,
                          ),
                        ),
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
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
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
}
