import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/repositories/payment_repository.dart';
import '../../utils/web_session_helper.dart';

class PaymentQrDialog extends StatefulWidget {
  final int? courseId;
  final List<int>? courseIds;
  final String courseTitle;
  final double price;
  final VoidCallback onPaymentSuccess;

  const PaymentQrDialog({
    super.key,
    this.courseId,
    this.courseIds,
    required this.courseTitle,
    required this.price,
    required this.onPaymentSuccess,
  });

  @override
  State<PaymentQrDialog> createState() => _PaymentQrDialogState();
}

class _PaymentQrDialogState extends State<PaymentQrDialog> {
  final PaymentRepository _paymentRepository = PaymentRepository();

  bool _isLoading = true;
  bool _isPolling = false;
  String? _errorMessage;
  String? _paymentUrl;
  String? _qrCode;
  String? _txnRef;
  double? _amount;

  // Countdown: 15 phút
  int _secondsRemaining = 15 * 60;
  Timer? _countdownTimer;
  Timer? _pollingTimer;

  static const Color _primary = Color(0xFF28B79B);

  @override
  void initState() {
    super.initState();
    _createPayment();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _createPayment() async {
    _countdownTimer?.cancel();
    _pollingTimer?.cancel();
    setState(() {
      _secondsRemaining = 15 * 60;
      _isLoading = true;
      _isPolling = false;
      _errorMessage = null;
    });

    try {
      final result = await _paymentRepository.createPayment(
        courseId: widget.courseId,
        courseIds: widget.courseIds,
      );
      if (!mounted) return;
      if (result['paymentUrl'] == 'FREE_SUCCESS') {
        Navigator.of(context).pop();
        widget.onPaymentSuccess();
        return;
      }
      setState(() {
        _paymentUrl = result['paymentUrl'] as String?;
        _qrCode = result['qrCode'] as String?;
        _txnRef = result['txnRef'] as String?;
        _amount = (result['amount'] as num?)?.toDouble();
        _isLoading = false;
      });
      _startCountdown();
      _startPolling(); // Automatically start polling upon QR creation
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          timer.cancel();
          _pollingTimer?.cancel();
          _isPolling = false;
          _errorMessage = 'Payment session expired (15-minute timer ended). Please click "Try Again" to generate a new QR code.';
        }
      });
    });
  }

  void _startPolling() {
    if (_txnRef == null || _isPolling) return;
    setState(() => _isPolling = true);

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (!mounted) {
        timer.cancel();
        return;
      }
      try {
        final status = await _paymentRepository.checkPaymentStatus(_txnRef!);
        final paymentStatus = status['status'] as String? ?? 'PENDING';

        if (paymentStatus == 'SUCCESS') {
          timer.cancel();
          _countdownTimer?.cancel();
          if (mounted) {
            Navigator.of(context).pop();
            widget.onPaymentSuccess();
          }
        } else if (paymentStatus == 'FAILED') {
          timer.cancel();
          _countdownTimer?.cancel();
          if (mounted) {
            setState(() {
              _isPolling = false;
              _errorMessage = 'Payment failed. Please try again.';
            });
          }
        } else if (paymentStatus == 'EXPIRED') {
          timer.cancel();
          _countdownTimer?.cancel();
          if (mounted) {
            setState(() {
              _isPolling = false;
              _errorMessage = 'Payment session expired. Please click "Try Again" to generate a new QR code.';
            });
          }
        }
      } catch (_) {
        // Keep polling on temporary network glitches
      }
    });
  }

  Future<void> _openPaymentUrl() async {
    if (_paymentUrl == null) return;
    if (kIsWeb) {
      navigateToUrl(_paymentUrl!);
      return;
    }
    final uri = Uri.parse(_paymentUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.platformDefault,
      );
    }
  }

  String get _countdownText {
    final minutes = _secondsRemaining ~/ 60;
    final seconds = _secondsRemaining % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatPrice(double price) {
    final formatted = price.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return '$formatted ₫';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 32,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF28B79B), Color(0xFF1A9B82)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded,
                        color: Colors.white, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'VietQR Express Payment',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.courseTitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 22),
                  ),
                ],
              ),
            ),

            // Body
            Padding(
              padding: const EdgeInsets.all(24),
              child: _isLoading
                  ? const SizedBox(
                      height: 220,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: _primary),
                            SizedBox(height: 16),
                            Text('Generating VietQR payment code...',
                                style: TextStyle(color: Color(0xFF64748B), fontSize: 14)),
                          ],
                        ),
                      ),
                    )
                  : _errorMessage != null
                      ? _buildError()
                      : _buildQrContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return SizedBox(
      height: 220,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Color(0xFF475569)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
                _createPayment();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQrContent() {
    final amount = _amount ?? widget.price;

    return Column(
      children: [
        // Live Status Banner
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF0FDF4),
            border: Border.all(color: const Color(0xFFBBF7D0)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF16A34A),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _isPolling
                      ? 'Waiting for mobile banking payment...'
                      : 'Checking payment status...',
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Price Card
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F7F4),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total Amount',
                style: TextStyle(color: Color(0xFF475569), fontSize: 14),
              ),
              Text(
                _formatPrice(amount),
                style: const TextStyle(
                  color: _primary,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // QR Code Container
        if (_qrCode != null || _paymentUrl != null) ...[
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                QrImageView(
                  data: _qrCode ?? _paymentUrl!,
                  version: QrVersions.auto,
                  size: 190,
                  backgroundColor: Colors.white,
                  errorStateBuilder: (context, error) => const SizedBox(
                    height: 190,
                    child: Center(child: Text('Unable to generate QR code')),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Scan with any Mobile Banking App (VietQR)',
                  style: TextStyle(
                    color: Color(0xFF334155),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (_txnRef != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Order ID: #$_txnRef',
                    style: const TextStyle(
                      color: Color(0xFF94A3B8),
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Countdown Timer
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.timer_outlined,
                  size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                'QR expires in: $_countdownText',
                style: TextStyle(
                  color: _secondsRemaining < 60
                      ? Colors.red
                      : const Color(0xFF64748B),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Manual Check / Verification Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _isPolling ? null : _startPolling,
              icon: _isPolling
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _primary),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(
                _isPolling
                    ? 'Auto-verifying payment...'
                    : 'Check Payment Status',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _primary,
                side: const BorderSide(color: _primary),
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Fallback option link
          TextButton.icon(
            onPressed: _openPaymentUrl,
            icon: const Icon(Icons.open_in_new_rounded, size: 14),
            label: const Text(
              'Having trouble scanning? Open PayOS Checkout Page',
              style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
            ),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF64748B),
              padding: const EdgeInsets.symmetric(vertical: 4),
            ),
          ),

          const SizedBox(height: 4),
          const Text(
            '🔒 256-Bit Encrypted Payment via PayOS Gate',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

