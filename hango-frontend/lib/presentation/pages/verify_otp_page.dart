import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/services/auth_service.dart';
import '../../utils/toast_helper.dart';
import 'reset_password_page.dart';

class VerifyOtpPage extends StatefulWidget {
  final String email;
  const VerifyOtpPage({super.key, required this.email});

  @override
  State<VerifyOtpPage> createState() => _VerifyOtpPageState();
}

class _VerifyOtpPageState extends State<VerifyOtpPage> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _isLoading = false;
  int _resendCooldown = 60;
  Timer? _timer;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _startCooldownTimer();
    for (int i = 0; i < 6; i++) {
      final index = i;
      _focusNodes[index].addListener(() {
        if (_focusNodes[index].hasFocus) {
          _controllers[index].selection = TextSelection(
            baseOffset: 0,
            extentOffset: _controllers[index].text.length,
          );
        }
      });
    }
  }

  void _startCooldownTimer() {
    _timer?.cancel();
    setState(() {
      _resendCooldown = 60;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        if (mounted) {
          setState(() {
            _resendCooldown--;
          });
        }
      } else {
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _handleVerify() async {
    String otp = _controllers.map((c) => c.text).join();
    if (otp.length < 6) {
      ToastHelper.showError(context, 'Please enter all 6 digits of the OTP code.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final result = await _authService.verifyOtp(widget.email, otp);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (result['success']) {
        ToastHelper.showSuccess(context, 'OTP Verified successfully! Please set your new password.');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ResetPasswordPage(email: widget.email, otpCode: otp),
          ),
        );
      } else {
        ToastHelper.showError(context, result['message'] ?? 'OTP verification failed.');
      }
    }
  }

  void _handleResend() async {
    if (_resendCooldown > 0) return;

    setState(() {
      _isLoading = true;
    });

    final result = await _authService.forgotPassword(widget.email);

    setState(() {
      _isLoading = false;
    });

    if (mounted) {
      if (result['success']) {
        for (var controller in _controllers) {
          controller.clear();
        }
        _focusNodes[0].requestFocus();
        ToastHelper.showSuccess(context, 'A new OTP code has been sent to ${widget.email}.');
        _startCooldownTimer();
      } else {
        ToastHelper.showError(context, result['message'] ?? 'Failed to resend OTP code.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Row(
        children: [
          if (isDesktop) ...[
            // Left Panel: Illustration and decoration (50% width)
            Expanded(
              child: Container(
                color: const Color(0xFF28B79B),
                padding: const EdgeInsets.all(48.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 450),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(
                            'https://res.cloudinary.com/diqekap4o/image/upload/v1781621072/login_tolpmx.png',
                            fit: BoxFit.contain,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(
                                Icons.broken_image,
                                color: Colors.white,
                                size: 100,
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text(
                          'Your trusted education\npartner',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w400,
                            height: 1.4,
                          ),
                        ),
                        Row(
                          children: [
                            Icon(Icons.verified_user_outlined, color: Colors.white70, size: 20),
                            SizedBox(width: 12),
                            Icon(Icons.school_outlined, color: Colors.white70, size: 20),
                          ],
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          // Right Panel: Verify OTP Form
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 64.0 : 24.0,
                vertical: 36.0,
              ),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // HanGo logo
                      Image.network(
                        'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
                        height: 60,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFFE6FFFA),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const Icon(
                                    Icons.school_outlined,
                                    color: Color(0xFF28B79B),
                                    size: 24,
                                  ),
                                ],
                              ),
                              const SizedBox(width: 12),
                              RichText(
                                text: const TextSpan(
                                  text: 'Han',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                    fontFamily: 'Outfit',
                                  ),
                                  children: [
                                    TextSpan(
                                      text: 'Go',
                                      style: TextStyle(
                                        color: Color(0xFF28B79B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 36),

                      // Back to Login Link
                      GestureDetector(
                        onTap: () {
                          // This screen is always reached via Login -> ForgotPassword ->
                          // VerifyOtp, so two pops (skipping the "enter your email" step)
                          // lands back on Login -- popUntil(isFirst) overshoots to the
                          // landing page instead.
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        child: MouseRegion(
                          cursor: SystemMouseCursors.click,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(
                                Icons.arrow_back,
                                color: Color(0xFF4B5563),
                                size: 16,
                              ),
                              SizedBox(width: 8),
                              Text(
                                'Back to Login',
                                style: TextStyle(
                                  color: Color(0xFF4B5563),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Title
                      const Text(
                        'Verify OTP',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Subtitle
                      const Text(
                        'We have sent a 6-digit OTP code to your email. Please enter the code to continue.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 36),

                      // 6 Digit OTP fields
                      const Text(
                        'OTP Code',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF374151),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(6, (index) {
                          return SizedBox(
                            width: isDesktop ? 56 : 45,
                            height: 60,
                            child: Focus(
                              onKeyEvent: (node, event) {
                                if (event is KeyDownEvent &&
                                    event.logicalKey == LogicalKeyboardKey.backspace) {
                                  if (_controllers[index].text.isNotEmpty) {
                                    _controllers[index].clear();
                                    if (index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                    return KeyEventResult.handled;
                                  } else if (index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                    return KeyEventResult.handled;
                                  }
                                }
                                return KeyEventResult.ignored;
                              },
                              child: TextFormField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                textInputAction: index == 5 ? TextInputAction.done : TextInputAction.next,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1F2937),
                                ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                decoration: InputDecoration(
                                  fillColor: const Color(0xFFF3F4F6),
                                  filled: true,
                                  contentPadding: EdgeInsets.zero,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF28B79B),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                                onTap: () {
                                  _controllers[index].selection = TextSelection(
                                    baseOffset: 0,
                                    extentOffset: _controllers[index].text.length,
                                  );
                                },
                                onChanged: (value) {
                                  final digits = value.replaceAll(RegExp(r'\D'), '');

                                  // Handle paste of 6 digits (or full OTP string)
                                  if (digits.length >= 6) {
                                    for (int i = 0; i < 6; i++) {
                                      _controllers[i].text = digits[i];
                                    }
                                    _focusNodes[5].requestFocus();
                                    _handleVerify();
                                    return;
                                  }

                                  if (digits.isEmpty) {
                                    return;
                                  }

                                  // If user typed over an existing number, keep only the latest digit
                                  final singleDigit = digits.substring(digits.length - 1);
                                  _controllers[index].value = TextEditingValue(
                                    text: singleDigit,
                                    selection: TextSelection(
                                      baseOffset: 0,
                                      extentOffset: singleDigit.length,
                                    ),
                                  );

                                  if (index < 5) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else {
                                    _focusNodes[index].unfocus();
                                  }
                                },
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 36),

                      // Verify Button
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleVerify,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Verify',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Didn't receive link
                      Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Didn't receive the code? ",
                              style: TextStyle(
                                color: Color(0xFF6B7280),
                                fontSize: 13,
                              ),
                            ),
                            GestureDetector(
                              onTap: _resendCooldown == 0 && !_isLoading ? _handleResend : null,
                              child: MouseRegion(
                                cursor: _resendCooldown == 0 && !_isLoading
                                    ? SystemMouseCursors.click
                                    : SystemMouseCursors.basic,
                                child: Text(
                                  _resendCooldown > 0
                                      ? 'Resend OTP (${_resendCooldown}s)'
                                      : 'Resend OTP',
                                  style: TextStyle(
                                    color: _resendCooldown > 0 || _isLoading
                                        ? const Color(0xFF9CA3AF)
                                        : const Color(0xFF28B79B),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
