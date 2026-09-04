import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/language_manager.dart';
import '../../../../utils/trainer_onboarding_validation_utils.dart';
import 'trainer_onboarding_shell_page.dart';
import '../trainer_shell_page.dart';

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

  String? _bankNameErrorText;
  String? _bankAccountErrorText;
  String? _bankAccountNameErrorText;

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
  }

  void _populateFields(Map<String, dynamic> p) {
    _bankNameController.text = p['bankName'] ?? '';
    _bankAccountController.text = p['bankAccount'] ?? '';
    _bankAccountNameController.text = p['bankAccountName'] ?? '';
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
    return validateTrainerBankAccount(bankAccount, isVi: isVi);
  }

  String? _validateBankAccountName(String bankAccountName, bool isVi) {
    return validateTrainerBankAccountName(bankAccountName, isVi: isVi);
  }

  bool _validateFields() {
    final isVi = LanguageManager.isVi;
    final bankName = _bankNameController.text.trim();
    final bankAccount = _bankAccountController.text.trim();
    final bankAccountName = _bankAccountNameController.text.trim();

    setState(() {
      _bankNameErrorText = _validateBankName(bankName, isVi);
      _bankAccountErrorText = _validateBankAccount(bankAccount, isVi);
      _bankAccountNameErrorText = _validateBankAccountName(
        bankAccountName,
        isVi,
      );
    });

    return _bankNameErrorText == null &&
        _bankAccountErrorText == null &&
        _bankAccountNameErrorText == null;
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
    payload['agreementSigned'] = true;

    final result = await _onboardingService.saveProfileDraft(payload);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      ToastHelper.showSuccess(
        context,
        LanguageManager.isVi
            ? 'Cập nhật tài khoản thanh toán thành công!'
            : 'Payout details saved successfully! Welcome to your Trainer Dashboard.',
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const TrainerShellPage()),
        (route) => false,
      );
    } else {
      ToastHelper.showError(
        context,
        result['message'] ?? 'Failed to save payout details.',
      );
    }
  }

  @override
  void dispose() {
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankAccountNameController.dispose();
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
                      color: Colors.black.withValues(alpha: 0.02),
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
                                    ? 'Thông tin tài khoản ngân hàng'
                                    : 'Payout Bank Account',
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
                                    ? 'Nhập tài khoản nhận thanh toán doanh thu định kỳ'
                                    : 'Enter bank account details to receive revenue payouts',
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
                      initialValue:
                          _bankSuggestions.contains(_bankNameController.text)
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
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      maxLength: 20,
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
                        counterText: '',
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
