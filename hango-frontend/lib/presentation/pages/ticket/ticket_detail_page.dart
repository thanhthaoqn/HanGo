import 'package:flutter/material.dart';
import '../../../data/models/ticket_model.dart';
import '../../../data/services/ticket_service.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/shared_header.dart';
import 'create_ticket_modal.dart';

class TicketDetailPage extends StatefulWidget {
  final int ticketId;

  const TicketDetailPage({super.key, required this.ticketId});

  @override
  State<TicketDetailPage> createState() => _TicketDetailPageState();
}

class _TicketDetailPageState extends State<TicketDetailPage> {
  final _ticketService = TicketService();
  final _replyController = TextEditingController();

  TicketModel? _ticket;
  bool _isLoading = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _loadDetail(isInitial: true);
  }

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  Future<void> _loadDetail({bool isInitial = false}) async {
    if (isInitial || _ticket == null) {
      setState(() => _isLoading = true);
    }
    final res = await _ticketService.getTicketDetail(widget.ticketId);
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _ticket = res['ticket'];
        }
      });
    }
  }

  void _sendReply() async {
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSending = true);
    final res = await _ticketService.addMessage(widget.ticketId, text);
    if (mounted) {
      setState(() => _isSending = false);
      if (res['success'] == true) {
        _replyController.clear();
        ToastHelper.showSuccess(context, 'Response sent successfully!');
        _loadDetail(isInitial: false);
      } else {
        ToastHelper.showError(context, res['message'] ?? 'Failed to send reply.');
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
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          SharedHeader(isDesktop: isDesktop, activeTab: 'Support'),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF28B79B)))
                : _ticket == null
                    ? const Center(child: Text('Ticket not found'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 1100),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Top Breadcrumb & Back button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Support Tickets / #${_ticket!.ticketCode}',
                                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                                    ),
                                    OutlinedButton.icon(
                                      onPressed: () => Navigator.pop(context),
                                      icon: const Icon(Icons.arrow_back, size: 16),
                                      label: const Text('Back'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: const Color(0xFF475569),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  _ticket!.title,
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Created at ${_ticket!.createdAt}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                ),
                                const SizedBox(height: 24),

                                // Main 3-Column Layout (Mockup 4)
                                LayoutBuilder(
                                  builder: (context, constraints) {
                                    if (isDesktop) {
                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Left Filter Sidebar (Width 220)
                                          SizedBox(width: 220, child: _buildLeftSidebar(context)),
                                          const SizedBox(width: 24),
                                          // Center Message Thread
                                          Expanded(child: _buildCenterThread(context)),
                                          const SizedBox(width: 24),
                                          // Right Info Card (Width 260)
                                          SizedBox(width: 260, child: _buildRightInfoCard(context)),
                                        ],
                                      );
                                    } else {
                                      return Column(
                                        children: [
                                          _buildRightInfoCard(context),
                                          const SizedBox(height: 20),
                                          _buildCenterThread(context),
                                        ],
                                      );
                                    }
                                  },
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

  Widget _buildLeftSidebar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Filter Tickets',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 16),
          _buildFilterItem('All Tickets', true, () => Navigator.pop(context)),
          _buildFilterItem('Approved Tickets', false, () => Navigator.pop(context)),
          _buildFilterItem('Rejected Tickets', false, () => Navigator.pop(context)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => CreateTicketModal(
                  onSuccess: () => Navigator.pop(context),
                ),
              );
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('+ Create New Ticket'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterItem(String label, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFEF3C7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFD97706) : const Color(0xFF475569),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildCenterThread(BuildContext context) {
    return Column(
      children: [
        // Ticket Main Description Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_ticket!.userEmail ?? "User"} sent',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A)),
                  ),
                  Text(_ticket!.createdAt, style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                _ticket!.description,
                style: const TextStyle(fontSize: 14, color: Color(0xFF334155), height: 1.5),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Discussion Thread
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Discussion & Responses',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 16),

              if (_ticket!.messages.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        Icon(Icons.chat_bubble_outline, color: Color(0xFFCBD5E1), size: 36),
                        SizedBox(height: 8),
                        Text('No responses yet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
                      ],
                    ),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _ticket!.messages.length,
                  separatorBuilder: (context, index) => const Divider(height: 24, color: Color(0xFFF1F5F9)),
                  itemBuilder: (context, index) {
                    final msg = _ticket!.messages[index];
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
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: isStaff ? const Color(0xFF166534) : const Color(0xFF0F172A),
                                ),
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

              const SizedBox(height: 20),

              // Reply Input Box (Hidden if Ticket is APPROVED or REJECTED)
              if (_ticket?.status == 'APPROVED' || _ticket?.status == 'REJECTED')
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 8),
                      Text(
                        'This ticket is closed. No further replies required.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _replyController,
                        decoration: InputDecoration(
                          hintText: 'Type your message...',
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          fillColor: const Color(0xFFF8FAFC),
                          filled: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isSending ? null : _sendReply,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: _isSending
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Send'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRightInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Ticket Info',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ticket Code:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text('#${_ticket!.ticketCode}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Status:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              _buildStatusBadge(_ticket!.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Created Date:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
              Text(_ticket!.createdAt.split(' ').first, style: const TextStyle(fontSize: 12, color: Color(0xFF334155))),
            ],
          ),
          const SizedBox(height: 20),

          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => CreateTicketModal(
                  existingTicket: _ticket,
                  onSuccess: _loadDetail,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 44),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Update Ticket', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
