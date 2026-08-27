import 'package:flutter/material.dart';
import '../../../data/models/ticket_model.dart';
import '../../../data/services/ticket_service.dart';
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
  bool _isFetchingBackground = false;
  String _selectedStatus = 'ALL';
  int _currentPage = 0;
  int _pageSize = 10;
  int _totalPages = 1;
  int _totalElements = 0;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  Future<void> _fetchTickets({bool isSilent = false}) async {
    if (_tickets.isEmpty || !isSilent) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isFetchingBackground = true);
    }
    final res = await _ticketService.getMyTickets(
      status: _selectedStatus,
      page: _currentPage,
      size: _pageSize,
    );
    if (mounted) {
      setState(() {
        _isLoading = false;
        _isFetchingBackground = false;
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
      label = 'Accepted';
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
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  void _showDetailModal(TicketModel ticket) {
    showDialog(
      context: context,
      builder: (context) => _TrainerTicketDetailDialog(
        ticketId: ticket.id,
        onRefresh: () => _fetchTickets(isSilent: true),
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
                      'Support Tickets',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CreateTicketModal(
                        onSuccess: () => _fetchTickets(isSilent: true),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Support Request'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28B79B),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                    textStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      fontSize: 13,
                    ),
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
                  _buildFilterChip('APPROVED', 'Accepted'),
                  const SizedBox(width: 8),
                  _buildFilterChip('REJECTED', 'Rejected'),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(color: Color(0xFFF1F5F9)),
            const SizedBox(height: 16),

            // Tickets List
            if (_isLoading && _tickets.isEmpty)
              const SizedBox(
                height: 250,
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF28B79B)),
                ),
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
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 40,
                        color: Color(0xFFCBD5E1),
                      ),
                      SizedBox(height: 10),
                      Text(
                        'No support requests found',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Stack(
                children: [
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _tickets.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
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
                              child: const Icon(
                                Icons.confirmation_number_outlined,
                                color: Color(0xFF28B79B),
                                size: 20,
                              ),
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
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFF28B79B),
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      _buildStatusBadge(t.status),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    t.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Color(0xFF0F172A),
                                      fontFamily: 'Outfit',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Created: ${t.createdAt}',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF94A3B8),
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            OutlinedButton(
                              onPressed: () => _showDetailModal(t),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF334155),
                                side: const BorderSide(
                                  color: Color(0xFFCBD5E1),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: const Text(
                                'View',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  if (_isFetchingBackground)
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: const LinearProgressIndicator(
                        color: Color(0xFF28B79B),
                        backgroundColor: Colors.transparent,
                        minHeight: 3,
                      ),
                    ),
                ],
              ),

            // Pagination Controls
            const SizedBox(height: 20),
            if (_tickets.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total $_totalElements request(s)',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 18),
                        onPressed: _currentPage > 0
                            ? () {
                                setState(() => _currentPage--);
                                _fetchTickets(isSilent: true);
                              }
                            : null,
                      ),
                      const SizedBox(width: 4),
                      ...List.generate(_totalPages > 0 ? _totalPages : 1, (
                        index,
                      ) {
                        final pageNum = index + 1;
                        final isCurrent = index == _currentPage;

                        return InkWell(
                          onTap: () {
                            setState(() => _currentPage = index);
                            _fetchTickets(isSilent: true);
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? const Color(0xFF28B79B)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Center(
                              child: Text(
                                '$pageNum',
                                style: TextStyle(
                                  color: isCurrent
                                      ? Colors.white
                                      : const Color(0xFF4B5563),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 18),
                        onPressed: _currentPage < _totalPages - 1
                            ? () {
                                setState(() => _currentPage++);
                                _fetchTickets(isSilent: true);
                              }
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );

    if (widget.isEmbedded) {
      return content;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop
          ? const Drawer(child: TrainerSidebar(activeIndex: 6))
          : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(width: 250, child: TrainerSidebar(activeIndex: 6)),
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
        _fetchTickets(isSilent: true);
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6FFFA) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF28B79B)
                : const Color(0xFFE2E8F0),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? const Color(0xFF28B79B)
                : const Color(0xFF64748B),
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

  const _TrainerTicketDetailDialog({
    required this.ticketId,
    required this.onRefresh,
  });

  @override
  State<_TrainerTicketDetailDialog> createState() =>
      _TrainerTicketDetailDialogState();
}

class _TrainerTicketDetailDialogState
    extends State<_TrainerTicketDetailDialog> {
  final _ticketService = TicketService();
  TicketModel? _ticket;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail(isInitial: true);
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

  Widget _buildStatusBadge(String status) {
    Color bg = const Color(0xFFFEF3C7);
    Color fg = const Color(0xFFD97706);
    String label = 'Pending';

    if (status == 'APPROVED') {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
      label = 'Accepted';
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
        style: TextStyle(color: fg, fontWeight: FontWeight.bold, fontSize: 11),
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
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLeftContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _ticket!.title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '#${_ticket!.ticketCode}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF28B79B),
                fontSize: 12,
              ),
            ),
            const SizedBox(width: 8),
            _buildStatusBadge(_ticket!.status),
          ],
        ),
        const SizedBox(height: 14),
        const Divider(color: Color(0xFFE2E8F0)),
        const SizedBox(height: 12),

        // Original Request Description
        const Text(
          'Original Request Description',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF334155),
            fontFamily: 'Outfit',
          ),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Created: ${_formatDateTime(_ticket!.createdAt)}',
                style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 6),
              Text(
                _ticket!.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF334155),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Admin Response Note (only if Approved)
        if (_ticket!.status == 'APPROVED' &&
            _ticket!.adminResponse != null &&
            _ticket!.adminResponse!.isNotEmpty &&
            !_ticket!.adminResponse!.startsWith('Ticket rejected')) ...[
          const Text(
            'Admin Response / Note',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFF15803D),
              fontFamily: 'Outfit',
            ),
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
              _ticket!.adminResponse!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF166534),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Rejection Reason (if Rejected)
        if (_ticket!.rejectionReason != null &&
            _ticket!.rejectionReason!.isNotEmpty) ...[
          const Text(
            'Rejection Reason',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Color(0xFFDC2626),
              fontFamily: 'Outfit',
            ),
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
              _ticket!.rejectionReason!,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF991B1B),
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Ticket Metadata Summary Card
        const Text(
          'Ticket Information',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF334155),
            fontFamily: 'Outfit',
          ),
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
              _buildAuditRow(
                Icons.calendar_today_rounded,
                'Submitted Date',
                _formatDateTime(_ticket!.createdAt),
              ),
              const Divider(height: 16, color: Color(0xFFF1F5F9)),
              _buildAuditRow(
                Icons.history_rounded,
                'Last Updated',
                _formatDateTime(_ticket!.updatedAt),
              ),
              if (_ticket!.processedByName != null &&
                  _ticket!.processedByName!.isNotEmpty) ...[
                const Divider(height: 16, color: Color(0xFFF1F5F9)),
                _buildAuditRow(
                  Icons.admin_panel_settings_rounded,
                  'Processed By',
                  _ticket!.processedByName!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    if (_isLoading) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const SizedBox(
          height: 200,
          width: 300,
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF28B79B)),
          ),
        ),
      );
    }

    if (_ticket == null) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: const SizedBox(
          height: 150,
          width: 300,
          child: Center(child: Text('Ticket not found')),
        ),
      );
    }

    final dialogWidth = isDesktop
        ? 980.0
        : (size.width * 0.94).clamp(300.0, 620.0);
    final dialogHeight = isDesktop
        ? 520.0
        : (size.height * 0.72).clamp(400.0, 620.0);

    Widget bottomActions = Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Close',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
        ),
        if (_ticket != null &&
            _ticket!.status != 'APPROVED' &&
            _ticket!.status != 'REJECTED') ...[
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => CreateTicketModal(
                  existingTicket: _ticket,
                  onSuccess: () {
                    _loadDetail();
                    widget.onRefresh();
                  },
                ),
              );
            },
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Update Ticket'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ],
    );

    // Desktop Layout
    Widget desktopBody = Column(
      children: [
        Expanded(child: SingleChildScrollView(child: _buildLeftContent())),
        const SizedBox(height: 12),
        bottomActions,
      ],
    );

    // Mobile / Shrunk Window Layout (Single Column Stack)
    Widget mobileBody = Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_buildLeftContent(), const SizedBox(height: 20)],
            ),
          ),
        ),
        const SizedBox(height: 12),
        bottomActions,
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
            // Modal Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Support Request Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Modal Body Layout
            Expanded(child: isDesktop ? desktopBody : mobileBody),
          ],
        ),
      ),
    );
  }
}
