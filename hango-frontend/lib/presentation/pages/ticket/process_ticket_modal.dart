import 'dart:async';
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
  final _adminReplyController = TextEditingController();

  TicketModel? _fullTicket;
  bool _isFetchingDetail = true;
  String _selectedAction = 'APPROVE'; // APPROVE or REJECT
  bool _isLoading = false;
  bool _isSendingReply = false;
  String? _rejectionReasonError;
  String? _adminReplyError;
  Timer? _pollingTimer;

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

    // Start 3-second live auto-polling for chat messages
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _loadTicketDetail(isSilent: true);
    });
  }

  Future<void> _loadTicketDetail({bool isSilent = false}) async {
    if (!isSilent && mounted) {
      setState(() => _isFetchingDetail = true);
    }
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

  void _sendAdminReply() async {
    final text = _adminReplyController.text.trim();
    if (text.isEmpty) {
      setState(() {
        _adminReplyError = 'Please enter a message to reply.';
      });
      return;
    } else {
      setState(() {
        _adminReplyError = null;
      });
    }

    setState(() => _isSendingReply = true);
    final res = await _ticketService.addMessage(widget.ticket.id, text);
    if (mounted) {
      setState(() => _isSendingReply = false);
      if (res['success'] == true) {
        _adminReplyController.clear();
        setState(() => _adminReplyError = null);
        ToastHelper.showSuccess(context, 'Message sent to Trainer!');
        _loadTicketDetail(isSilent: true);
        widget.onSuccess();
      } else {
        ToastHelper.showError(context, res['message'] ?? 'Failed to send message.');
      }
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _rejectionReasonController.dispose();
    _adminResponseController.dispose();
    _adminReplyController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (_selectedAction == 'REJECT' && _rejectionReasonController.text.trim().isEmpty) {
      setState(() {
        _rejectionReasonError = 'Rejection reason is required.';
      });
      return;
    } else {
      setState(() {
        _rejectionReasonError = null;
      });
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

  String _formatDateTime(String? raw) {
    if (raw == null || raw.isEmpty) return 'N/A';
    try {
      final parsed = DateTime.parse(raw);
      final year = parsed.year.toString().padLeft(4, '0');
      final month = parsed.month.toString().padLeft(2, '0');
      final day = parsed.day.toString().padLeft(2, '0');
      final hour = parsed.hour.toString().padLeft(2, '0');
      final minute = parsed.minute.toString().padLeft(2, '0');
      return '$year-$month-$day $hour:$minute';
    } catch (_) {
      String formatted = raw.replaceAll('T', ' ');
      if (formatted.contains('.')) {
        formatted = formatted.split('.').first;
      }
      return formatted;
    }
  }

  Widget _buildAuditRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF64748B)),
        const SizedBox(width: 8),
        Text('$label: ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B), fontFamily: 'Outfit')),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'Outfit'),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // Reusable Ticket Overview & Decision Form Fields
  Widget _buildLeftContent(bool isClosed, String senderName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.ticket.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('Code: ${widget.ticket.ticketCode}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            Text('• Sender: $senderName (${widget.ticket.userRole})', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            _buildStatusBadge(widget.ticket.status),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(color: Color(0xFFE2E8F0)),
        const SizedBox(height: 12),

        // 1. Description Block
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
            style: const TextStyle(fontSize: 13, color: Color(0xFF0F172A), height: 1.5),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Decision Result Callouts (if closed)
        if (widget.ticket.status == 'APPROVED' && widget.ticket.adminResponse != null && widget.ticket.adminResponse!.isNotEmpty) ...[
          const Text(
            'Admin Response / Note',
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
          const SizedBox(height: 16),
        ],

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
          const SizedBox(height: 16),
        ],

        // 3. Ticket Audit & Metadata Summary Card
        const Text(
          'Ticket Information & Audit',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit'),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            children: [
              _buildAuditRow(Icons.calendar_today_rounded, 'Submitted Date', _formatDateTime(widget.ticket.createdAt)),
              const Divider(height: 16, color: Color(0xFFF1F5F9)),
              _buildAuditRow(Icons.history_rounded, 'Last Updated', _formatDateTime(widget.ticket.updatedAt)),
              if (widget.ticket.processedByName != null && widget.ticket.processedByName!.isNotEmpty) ...[
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildAuditRow(Icons.admin_panel_settings_rounded, 'Processed By', widget.ticket.processedByName!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 4. Decision Action Panel (if active)
        if (!isClosed) ...[
          const Text(
            'Decision Action',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => setState(() => _selectedAction = 'APPROVE'),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAction == 'APPROVE' ? const Color(0xFF28B79B) : const Color(0xFFF1F5F9),
                  foregroundColor: _selectedAction == 'APPROVE' ? Colors.white : const Color(0xFF475569),
                  elevation: _selectedAction == 'APPROVE' ? 2 : 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: () => setState(() => _selectedAction = 'REJECT'),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Reject'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedAction == 'REJECT' ? Colors.redAccent : const Color(0xFFF1F5F9),
                  foregroundColor: _selectedAction == 'REJECT' ? Colors.white : const Color(0xFF475569),
                  elevation: _selectedAction == 'REJECT' ? 2 : 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (_selectedAction == 'REJECT') ...[
            const Text(
              'Rejection Reason *',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFDC2626), fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _rejectionReasonController,
              maxLines: 3,
              maxLength: 2000,
              onChanged: (val) {
                if (_rejectionReasonError != null && val.trim().isNotEmpty) {
                  setState(() => _rejectionReasonError = null);
                }
              },
              decoration: InputDecoration(
                counterText: '',
                hintText: 'State the detailed reason for rejection...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: _rejectionReasonError != null ? Colors.red : const Color(0xFFFCA5A5), width: _rejectionReasonError != null ? 1.5 : 1.0),
                ),
                fillColor: const Color(0xFFFEF2F2),
                filled: true,
              ),
            ),
            if (_rejectionReasonError != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                  const SizedBox(width: 4),
                  Text(
                    _rejectionReasonError!,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500, fontFamily: 'Outfit'),
                  ),
                ],
              ),
            ],
          ] else ...[
            const Text(
              'Admin Response / Note',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF334155), fontFamily: 'Outfit'),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _adminResponseController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Approval comments or instructions for user...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                fillColor: const Color(0xFFF8FAFC),
                filled: true,
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  // Conversation Thread List Widget (Handles both Desktop & Mobile)
  Widget _buildConversationList({bool shrinkWrap = false}) {
    if (_isFetchingDetail) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF28B79B)));
    }
    if (_fullTicket == null || _fullTicket!.messages.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF1F5F9)),
        ),
        child: const Center(
          child: Text('No additional responses yet.', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontFamily: 'Outfit')),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(right: 4),
      itemCount: _fullTicket!.messages.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final msg = _fullTicket!.messages[index];
        final isStaff = msg.senderRole == 'ADMINISTRATOR' || msg.senderRole == 'COURSE_MANAGER';
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isStaff ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(10),
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
                  Text(_formatDateTime(msg.createdAt), style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 6),
              Text(msg.message, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.3)),
            ],
          ),
        );
      },
    );
  }

  // Live Chat Input Box / Closed Banner
  Widget _buildChatInputBox() {
    if (widget.ticket.status == 'PENDING' || widget.ticket.status == 'PROCESSING') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _adminReplyController,
                  style: const TextStyle(fontSize: 13, fontFamily: 'Outfit'),
                  onChanged: (val) {
                    if (_adminReplyError != null && val.trim().isNotEmpty) {
                      setState(() => _adminReplyError = null);
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Type your message to trainer...',
                    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: _adminReplyError != null ? Colors.red : const Color(0xFFCBD5E1), width: _adminReplyError != null ? 1.5 : 1.0),
                    ),
                    fillColor: const Color(0xFFF8FAFC),
                    filled: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _isSendingReply ? null : _sendAdminReply,
                icon: _isSendingReply
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 16),
                label: const Text('Send'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28B79B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          if (_adminReplyError != null) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.error_outline_rounded, size: 14, color: Color(0xFFDC2626)),
                const SizedBox(width: 4),
                Text(
                  _adminReplyError!,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626), fontWeight: FontWeight.w500, fontFamily: 'Outfit'),
                ),
              ],
            ),
          ],
        ],
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFF64748B)),
          SizedBox(width: 8),
          Text('This ticket is closed. No further replies required.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit')),
        ],
      ),
    );
  }

  // Footer Actions Row
  Widget _buildFooterActions(bool isClosed) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Close', style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit')),
        ),
        if (!isClosed) ...[
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF28B79B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Decision', style: TextStyle(fontFamily: 'Outfit')),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final senderName = widget.ticket.userName ?? widget.ticket.userEmail ?? 'User';
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;
    final isClosed = widget.ticket.status == 'APPROVED' || widget.ticket.status == 'REJECTED';

    final dialogWidth = isDesktop ? 980.0 : (size.width * 0.94).clamp(300.0, 620.0);
    final dialogHeight = isDesktop ? 680.0 : (size.height * 0.88).clamp(400.0, 780.0);

    // Desktop Layout (Side-by-Side 2 Columns)
    Widget desktopBody = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 5,
          child: Column(
            children: [
              Expanded(child: SingleChildScrollView(child: _buildLeftContent(isClosed, senderName))),
              const SizedBox(height: 12),
              _buildFooterActions(isClosed),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: VerticalDivider(width: 1, color: Color(0xFFE2E8F0)),
        ),
        Expanded(
          flex: 6,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Responses & Conversation',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 10),
              Expanded(child: _buildConversationList(shrinkWrap: false)),
              const SizedBox(height: 12),
              _buildChatInputBox(),
            ],
          ),
        ),
      ],
    );

    // Mobile / Shrunk Window Layout (Single Column Stack)
    Widget mobileBody = Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLeftContent(isClosed, senderName),
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                const Text(
                  'Responses & Conversation',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 10),
                _buildConversationList(shrinkWrap: true),
                const SizedBox(height: 16),
                _buildChatInputBox(),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildFooterActions(isClosed),
      ],
    );

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: dialogWidth,
        height: dialogHeight,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Modal Top Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'View & Process Support Ticket',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Responsive Modal Body
            Expanded(child: isDesktop ? desktopBody : mobileBody),
          ],
        ),
      ),
    );
  }
}
