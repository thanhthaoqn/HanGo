import 'package:flutter/material.dart';
import '../../../data/models/ticket_model.dart';
import '../../../data/services/ticket_service.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/trainer/trainer_sidebar.dart';
import '../ticket/create_ticket_modal.dart';

class TrainerTicketsPage extends StatefulWidget {
  final bool isEmbedded;
  const TrainerTicketsPage({super.key, this.isEmbedded = false});

  @override
  State<TrainerTicketsPage> createState() => _TrainerTicketsPageState();
}

class _TrainerTicketsPageState extends State<TrainerTicketsPage> {
  final _ticketService = TicketService();
  List<TicketModel> _tickets = [];
  bool _isLoading = true;
  String _selectedStatus = 'ALL';
  int _currentPage = 0;
  int _totalPages = 1;
  int _totalElements = 0;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets() async {
    setState(() => _isLoading = true);
    final res = await _ticketService.getMyTickets(
      status: _selectedStatus,
      page: _currentPage,
      size: 10,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        if (res['success'] == true) {
          _tickets = res['tickets'] as List<TicketModel>;
          _totalPages = res['totalPages'] ?? 1;
          _totalElements = res['totalElements'] ?? 0;
        }
      });
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
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11, fontFamily: 'Outfit'),
      ),
    );
  }

  void _showDetailModal(TicketModel ticket) {
    showDialog(
      context: context,
      builder: (context) => _TrainerTicketDetailDialog(
        ticketId: ticket.id,
        onRefresh: _fetchTickets,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    final content = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Support & Disputes',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Submit and track content bugs, revenue disputes, tax/bank info updates ($_totalElements total)',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CreateTicketModal(
                        onSuccess: _fetchTickets,
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Support Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28B79B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Status Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('ALL', 'All Requests'),
                  const SizedBox(width: 8),
                  _buildFilterChip('PENDING', 'Pending'),
                  const SizedBox(width: 8),
                  _buildFilterChip('PROCESSING', 'Processing'),
                  const SizedBox(width: 8),
                  _buildFilterChip('APPROVED', 'Approved'),
                  const SizedBox(width: 8),
                  _buildFilterChip('REJECTED', 'Rejected'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // Tickets List
            if (_isLoading)
              const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF28B79B))),
              )
            else if (_tickets.isEmpty)
              Container(
                height: 220,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFF1F5F9)),
                ),
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.confirmation_number_outlined, size: 40, color: Color(0xFFCBD5E1)),
                      SizedBox(height: 10),
                      Text(
                        'No support requests found',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _tickets.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final t = _tickets[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6FFFA),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.confirmation_number_outlined, color: Color(0xFF28B79B), size: 20),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    '#${t.ticketCode}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF28B79B), fontFamily: 'Outfit'),
                                  ),
                                  const SizedBox(width: 8),
                                  _buildStatusBadge(t.status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                t.title,
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Created: ${t.createdAt}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: () => _showDetailModal(t),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF334155),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          child: const Text('View', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, fontFamily: 'Outfit')),
                        ),
                      ],
                    ),
                  );
                },
              ),

            // Pagination Controls
            if (_totalPages > 1) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _currentPage > 0
                        ? () {
                            setState(() => _currentPage--);
                            _fetchTickets();
                          }
                        : null,
                  ),
                  Text('Page ${_currentPage + 1} of $_totalPages', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _currentPage < _totalPages - 1
                        ? () {
                            setState(() => _currentPage++);
                            _fetchTickets();
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? const Drawer(child: TrainerSidebar(activeIndex: 6)) : null,
      body: Row(
        children: [
          if (isDesktop) const SizedBox(width: 250, child: TrainerSidebar(activeIndex: 6)),
          Expanded(child: content),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedStatus == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedStatus = key;
          _currentPage = 0;
        });
        _fetchTickets();
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6FFFA) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF28B79B) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF28B79B) : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 12,
            fontFamily: 'Outfit',
          ),
        ),
      ),
    );
  }
}

class _TrainerTicketDetailDialog extends StatefulWidget {
  final int ticketId;
  final VoidCallback onRefresh;

  const _TrainerTicketDetailDialog({required this.ticketId, required this.onRefresh});

  @override
  State<_TrainerTicketDetailDialog> createState() => _TrainerTicketDetailDialogState();
}

class _TrainerTicketDetailDialogState extends State<_TrainerTicketDetailDialog> {
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
        widget.onRefresh();
      } else {
        ToastHelper.showError(context, res['message'] ?? 'Failed to send reply.');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF28B79B)))
            : _ticket == null
                ? const Center(child: Text('Ticket not found'))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text('#${_ticket!.ticketCode}', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF28B79B), fontSize: 13)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFEF3C7),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(_ticket!.status, style: const TextStyle(color: Color(0xFFD97706), fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(_ticket!.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 12),

                      // Thread List
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Initial Description
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFE2E8F0)),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Original Request', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF64748B))),
                                        Text(_ticket!.createdAt, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(_ticket!.description, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), height: 1.4)),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Rejection or Admin Note if exists
                              if (_ticket!.rejectionReason != null && _ticket!.rejectionReason!.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Rejection Reason', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFFDC2626))),
                                      const SizedBox(height: 6),
                                      Text(_ticket!.rejectionReason!, style: const TextStyle(fontSize: 13, color: Color(0xFF991B1B))),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Discussion Messages
                              const Text('Responses & Conversation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                              const SizedBox(height: 10),
                              if (_ticket!.messages.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 16),
                                  child: Center(child: Text('No responses yet', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12))),
                                )
                              else
                                ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _ticket!.messages.length,
                                  separatorBuilder: (context, index) => const SizedBox(height: 10),
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
                                              Text('${msg.senderName} (${msg.senderRole})', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: isStaff ? const Color(0xFF166534) : const Color(0xFF0F172A))),
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
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),
                      // Reply Box (Hidden if Ticket is APPROVED or REJECTED)
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
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                  fillColor: const Color(0xFFF8FAFC),
                                  filled: true,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            ElevatedButton(
                              onPressed: _isSending ? null : _sendReply,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF28B79B),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: _isSending ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Send'),
                            ),
                          ],
                        ),
                    ],
                  ),
      ),
    );
  }
}
