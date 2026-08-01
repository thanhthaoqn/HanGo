import 'package:flutter/material.dart';
import '../../../data/models/ticket_model.dart';
import '../../../data/services/ticket_service.dart';
import '../../../utils/toast_helper.dart';

class ProcessTicketModal extends StatefulWidget {
  final TicketModel ticket;
  final VoidCallback onSuccess;

  const ProcessTicketModal({
    super.key,
    required this.ticket,
    required this.onSuccess,
  });

  @override
  State<ProcessTicketModal> createState() => _ProcessTicketModalState();
}

class _ProcessTicketModalState extends State<ProcessTicketModal> {
  final _ticketService = TicketService();
  final _rejectionReasonController = TextEditingController();
  final _adminResponseController = TextEditingController();

  TicketModel? _fullTicket;
  bool _isFetchingDetail = true;
  String _selectedAction = 'APPROVE'; // APPROVE or REJECT
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.ticket.status == 'REJECTED') {
      _selectedAction = 'REJECT';
      _rejectionReasonController.text = widget.ticket.rejectionReason ?? '';
    } else if (widget.ticket.status == 'APPROVED') {
      _selectedAction = 'APPROVE';
      _adminResponseController.text = widget.ticket.adminResponse ?? '';
    }
    _loadTicketDetail();
  }

  Future<void> _loadTicketDetail() async {
    final res = await _ticketService.getTicketDetail(widget.ticket.id);
    if (mounted) {
      setState(() {
        _isFetchingDetail = false;
        if (res['success'] == true) {
          _fullTicket = res['ticket'];
        }
      });
    }
  }

  @override
  void dispose() {
    _rejectionReasonController.dispose();
    _adminResponseController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_selectedAction == 'REJECT' && _rejectionReasonController.text.trim().isEmpty) {
      ToastHelper.showError(context, 'Rejection reason is required.');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final res = await _ticketService.processTicket(
      widget.ticket.id,
      action: _selectedAction,
      rejectionReason: _selectedAction == 'REJECT' ? _rejectionReasonController.text.trim() : null,
      adminResponse: _adminResponseController.text.trim().isNotEmpty ? _adminResponseController.text.trim() : null,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (res['success'] == true) {
        ToastHelper.showSuccess(
          context,
          _selectedAction == 'APPROVE'
              ? 'Ticket #${widget.ticket.ticketCode} approved successfully!'
              : 'Ticket #${widget.ticket.ticketCode} rejected.',
        );
        Navigator.pop(context);
        widget.onSuccess();
      } else {
        ToastHelper.showError(context, res['message'] ?? 'Failed to process ticket.');
      }
    }
  }

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFFEF3C7);
    Color fg = const Color(0xFFD97706);
    String label = 'Pending';

    if (status == 'APPROVED') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = 'Approved';
    } else if (status == 'REJECTED') {
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFDC2626);
      label = 'Rejected';
    } else if (status == 'PROCESSING') {
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0284C7);
      label = 'Processing';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final senderName = widget.ticket.userName ?? widget.ticket.userEmail ?? 'User';

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680),
        padding: const EdgeInsets.all(28),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'View & Process Support Ticket',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.ticket.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            'Code: ${widget.ticket.ticketCode}',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Sender: $senderName (${widget.ticket.userRole})',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 12),
                          _buildStatusBadge(widget.ticket.status),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // 1. Content Block
              const Text(
                'Ticket Description / Content',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  widget.ticket.description,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), height: 1.5),
                ),
              ),
              const SizedBox(height: 16),

              // 1.5 Conversation History Block
              const Text(
                'Responses & Conversation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 8),
              if (_isFetchingDetail)
                const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF28B79B))))
              else if (_fullTicket == null || _fullTicket!.messages.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Text('No additional responses yet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _fullTicket!.messages.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final msg = _fullTicket!.messages[index];
                    final isStaff = msg.senderRole == 'ADMINISTRATOR' || msg.senderRole == 'COURSE_MANAGER';
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isStaff ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isStaff ? const Color(0xFFBBF7D0) : const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${msg.senderName} (${msg.senderRole})',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isStaff ? const Color(0xFF166534) : const Color(0xFF0F172A)),
                              ),
                              Text(msg.createdAt, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(msg.message, style: const TextStyle(fontSize: 13, color: Color(0xFF334155))),
                        ],
                      ),
                    );
                  },
                ),
              const SizedBox(height: 16),

              // 2. Current Response / Admin Notes
              if (widget.ticket.adminResponse != null && widget.ticket.adminResponse!.isNotEmpty) ...[
                const Text(
                  'Current Response',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFBBF7D0)),
                  ),
                  child: Text(
                    widget.ticket.adminResponse!,
                    style: const TextStyle(fontSize: 13, color: Color(0xFF166534), height: 1.4),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // 3. Decision Section (Only show editable decision options if ticket is PENDING or PROCESSING)
              if (widget.ticket.status == 'APPROVED' || widget.ticket.status == 'REJECTED') ...[
                if (widget.ticket.status == 'REJECTED' && widget.ticket.rejectionReason != null && widget.ticket.rejectionReason!.isNotEmpty) ...[
                  const Text(
                    'Rejection Reason',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626), fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFFCA5A5)),
                    ),
                    child: Text(
                      widget.ticket.rejectionReason!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B), height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF64748B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ] else ...[
                const Text(
                  'Decision Action',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedAction = 'APPROVE';
                        });
                      },
                      icon: const Icon(Icons.check_circle_outline, size: 18),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedAction == 'APPROVE' ? const Color(0xFF28B79B) : const Color(0xFFF1F5F9),
                        foregroundColor: _selectedAction == 'APPROVE' ? Colors.white : const Color(0xFF475569),
                        elevation: _selectedAction == 'APPROVE' ? 2 : 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedAction = 'REJECT';
                        });
                      },
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Reject'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _selectedAction == 'REJECT' ? Colors.redAccent : const Color(0xFFF1F5F9),
                        foregroundColor: _selectedAction == 'REJECT' ? Colors.white : const Color(0xFF475569),
                        elevation: _selectedAction == 'REJECT' ? 2 : 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Action Form Fields
                if (_selectedAction == 'REJECT') ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Rejection Reason *',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFDC2626), fontFamily: 'Outfit'),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _rejectionReasonController,
                        builder: (context, value, _) {
                          return Text(
                            '${value.text.length} / 2000',
                            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _rejectionReasonController,
                    maxLines: 4,
                    maxLength: 2000,
                    decoration: InputDecoration(
                      counterText: '',
                      hintText: 'Please state the detailed reason for rejection...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
                      fillColor: const Color(0xFFFEF2F2),
                      filled: true,
                    ),
                  ),
                ] else ...[
                  const Text(
                    'Manager Response / Note',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _adminResponseController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Enter approval comments or instructions for user...',
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      fillColor: const Color(0xFFF8FAFC),
                      filled: true,
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Actions Footer
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('Close', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Save Decision'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
