import 'package:flutter/material.dart';
import '../../../data/models/ticket_model.dart';
import '../../../data/services/ticket_service.dart';
import '../../widgets/course_manager_sidebar.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'process_ticket_modal.dart';

class ManagementTicketsPage extends StatefulWidget {
  final bool isEmbedded;

  const ManagementTicketsPage({super.key, this.isEmbedded = false});

  @override
  State<ManagementTicketsPage> createState() => _ManagementTicketsPageState();
}

class _ManagementTicketsPageState extends State<ManagementTicketsPage> {
  final _ticketService = TicketService();
  final _searchController = TextEditingController();

  List<TicketModel> _tickets = [];
  bool _isLoading = true;
  bool _isFetchingBackground = false;
  String _selectedTab = 'ALL'; // ALL, PENDING, PROCESSED
  int _currentPage = 0;
  int _pageSize = 10;
  int _totalPages = 1;
  int _totalElements = 0;

  @override
  void initState() {
    super.initState();
    _fetchTickets();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchTickets({bool isSilent = false}) async {
    if (_tickets.isEmpty || !isSilent) {
      setState(() => _isLoading = true);
    } else {
      setState(() => _isFetchingBackground = true);
    }

    String? statusFilter;
    if (_selectedTab == 'PENDING') {
      statusFilter = 'PENDING';
    } else if (_selectedTab == 'PROCESSED') {
      statusFilter = 'PROCESSED';
    }

    final res = await _ticketService.getManagementTickets(
      status: statusFilter,
      keyword: _searchController.text.trim(),
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
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 900;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Card Container (Mockup 2)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Tabs Row & Toolbar
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Tabs (All, Unprocessed, Processed)
                  Row(
                    children: [
                      _buildTabItem('ALL', 'All'),
                      const SizedBox(width: 8),
                      _buildTabItem('PENDING', 'Unprocessed'),
                      const SizedBox(width: 8),
                      _buildTabItem('PROCESSED', 'Processed'),
                    ],
                  ),

                  // Search box & Page Size Selector
                  Row(
                    children: [
                      SizedBox(
                        width: 240,
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) {
                            setState(() => _currentPage = 0);
                            _fetchTickets(isSilent: true);
                          },
                          decoration: InputDecoration(
                            hintText: 'Search code, title, sender...',
                            hintStyle: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                            prefixIcon: const Icon(Icons.search, size: 18, color: Color(0xFF94A3B8)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            fillColor: const Color(0xFFF8FAFC),
                            filled: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const Text('Show: ', style: TextStyle(color: Color(0xFF6B7280), fontSize: 13, fontFamily: 'Outfit')),
                            DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _pageSize,
                                icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4B5563), size: 16),
                                style: const TextStyle(color: Color(0xFF1F2937), fontSize: 13, fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                                onChanged: (int? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      _pageSize = newValue;
                                      _currentPage = 0;
                                    });
                                    _fetchTickets(isSilent: true);
                                  }
                                },
                                items: <int>[5, 10, 20, 50].map<DropdownMenuItem<int>>((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text('$value'),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // Data Table (Mockup 2 Layout)
              if (_isLoading && _tickets.isEmpty)
                const SizedBox(
                  height: 300,
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF28B79B))),
                )
              else if (_tickets.isEmpty)
                const SizedBox(
                  height: 250,
                  child: Center(
                    child: Text('No ticket records found', style: TextStyle(color: Color(0xFF94A3B8))),
                  ),
                )
              else
                Stack(
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(minWidth: constraints.maxWidth),
                            child: DataTable(
                              columnSpacing: 28,
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                              columns: const [
                                DataColumn(label: Text('Ticket Code', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
                                DataColumn(label: Text('Title', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
                                DataColumn(label: Text('Sender', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
                                DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
                                DataColumn(label: Text('Created At', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
                                DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)))),
                              ],
                              rows: _tickets.map((t) {
                                final sender = t.userName ?? t.userEmail ?? 'User';
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        '#${t.ticketCode}',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF28B79B)),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 280,
                                        child: Text(
                                          t.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Color(0xFF0F172A)),
                                        ),
                                      ),
                                    ),
                                    DataCell(Text('$sender (${t.userRole})', style: const TextStyle(fontSize: 13, color: Color(0xFF475569)))),
                                    DataCell(_buildStatusBadge(t.status)),
                                    DataCell(Text(t.createdAt, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)))),
                                    DataCell(
                                      IconButton(
                                        icon: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF0284C7), size: 20),
                                        tooltip: 'View & Process Ticket',
                                        onPressed: () {
                                          showDialog(
                                            context: context,
                                            builder: (context) => ProcessTicketModal(
                                              ticket: t,
                                              onSuccess: () => _fetchTickets(isSilent: true),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
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

              // Footer Pagination Controls (Comment Management matching layout)
              const SizedBox(height: 20),
              if (_tickets.isNotEmpty)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total $_totalElements ticket(s)',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit'),
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
                        ...List.generate(_totalPages > 0 ? _totalPages : 1, (index) {
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
                                color: isCurrent ? const Color(0xFF28B79B) : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Center(
                                child: Text(
                                  '$pageNum',
                                  style: TextStyle(
                                    color: isCurrent ? Colors.white : const Color(0xFF4B5563),
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
      ],
    );

    if (widget.isEmbedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildContentHeader(context, isDesktop),
          Padding(
            padding: const EdgeInsets.fromLTRB(24.0, 0, 24.0, 24.0),
            child: content,
          ),
        ],
      );
    }

    final Widget bodyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildContentHeader(context, isDesktop),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: content,
          ),
        ),
      ],
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: InternalAppHeader(isMobile: !isDesktop),
      drawer: !isDesktop ? const Drawer(child: CourseManagerSidebar(currentRoute: 'support')) : null,
      body: Row(
        children: [
          if (isDesktop) const SizedBox(width: 240, child: CourseManagerSidebar(currentRoute: 'support')),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }

  Widget _buildContentHeader(BuildContext context, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
      child: Row(
        children: [
          if (!isDesktop) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          const Text(
            'Support Tickets',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(String key, String label) {
    final isSelected = _selectedTab == key;
    return InkWell(
      onTap: () {
        setState(() {
          _selectedTab = key;
          _currentPage = 0;
        });
        _fetchTickets(isSilent: true);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE0F2FE) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF64748B),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
