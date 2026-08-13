import 'package:flutter/material.dart';
import '../../data/services/ticket_service.dart';
import '../../utils/toast_helper.dart';

class RefundRequestModal extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String priceText;
  final String? courseImageUrl;
  final VoidCallback? onSuccess;

  const RefundRequestModal({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.priceText,
    this.courseImageUrl,
    this.onSuccess,
  });

  @override
  State<RefundRequestModal> createState() => _RefundRequestModalState();
}

class _RefundRequestModalState extends State<RefundRequestModal> {
  final _ticketService = TicketService();
  final _detailsController = TextEditingController();
  final _bankInfoController = TextEditingController();

  String _selectedReason = 'Content discrepancy';
  bool _isSubmitting = false;

  final List<String> _reasons = [
    'Content discrepancy',
    'Technical / Audio issue',
    'Accidental purchase',
    'Other reason',
  ];

  @override
  void dispose() {
    _detailsController.dispose();
    _bankInfoController.dispose();
    super.dispose();
  }

  Future<void> _submitRefundRequest() async {
    final details = _detailsController.text.trim();
    if (details.isEmpty) {
      ToastHelper.showError(context, 'Please provide details for your refund request.');
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final bankInfo = _bankInfoController.text.trim();
    final fullDescription = 'Course ID: ${widget.courseId}\n'
        'Reason: $_selectedReason\n'
        'Details: $details'
        '${bankInfo.isNotEmpty ? "\nBank / Refund Info: $bankInfo" : ""}';

    final result = await _ticketService.createTicket(
      category: 'REFUND_REQUEST',
      priority: 'HIGH',
      title: '[Refund Request] ${widget.courseTitle}',
      description: fullDescription,
    );

    if (!mounted) return;

    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      Navigator.of(context).pop();
      ToastHelper.showSuccess(
        context,
        'Refund request submitted successfully! Admin will review your request shortly.',
      );
      if (widget.onSuccess != null) {
        widget.onSuccess!();
      }
    } else {
      ToastHelper.showError(
        context,
        result['message'] ?? 'Failed to submit refund request. Please try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 520,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.currency_exchange_rounded,
                      color: Color(0xFFEF4444),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Request Course Refund',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Outfit',
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Submit a formal request to System Administrators',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Course summary card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    if (widget.courseImageUrl != null && widget.courseImageUrl!.isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.courseImageUrl!,
                          width: 60,
                          height: 48,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 48,
                            color: const Color(0xFFCBD5E1),
                            child: const Icon(Icons.school, color: Colors.white),
                          ),
                        ),
                      ),
                    if (widget.courseImageUrl != null && widget.courseImageUrl!.isNotEmpty)
                      const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.courseTitle,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Outfit',
                              color: Color(0xFF0F172A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Paid: ${widget.priceText}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF10B981),
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Reason dropdown
              const Text(
                'Refund Reason',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedReason,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                items: _reasons.map((r) {
                  return DropdownMenuItem<String>(
                    value: r,
                    child: Text(
                      r,
                      style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedReason = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Detailed notes
              const Text(
                'Detailed Explanation',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Please describe specifically why you are requesting a refund...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Bank / Account Info
              const Text(
                'Refund Bank Info / Account (Optional)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Outfit',
                  color: Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _bankInfoController,
                decoration: InputDecoration(
                  hintText: 'e.g. Vietcombank - 123456789 - NGUYEN VAN A',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRefundRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text(
                            'Submit Refund Request',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
}
