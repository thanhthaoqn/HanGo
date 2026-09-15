import 'package:flutter/material.dart';
import '../../../data/services/revenue_settlement_service.dart';
import '../../../utils/download_helper.dart';
import '../../../utils/language_manager.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/course_manager_sidebar.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';

class CourseManagerSettlementPage extends StatefulWidget {
  final bool isEmbedded;

  const CourseManagerSettlementPage({super.key, this.isEmbedded = false});

  @override
  State<CourseManagerSettlementPage> createState() =>
      _CourseManagerSettlementPageState();
}

class _CourseManagerSettlementPageState
    extends State<CourseManagerSettlementPage>
    with SingleTickerProviderStateMixin {
  final _revenueService = RevenueSettlementService();

  late TabController _tabController;

  // --- Tab 1: Statements State ---
  bool _isLoading = true;
  List<dynamic> _statements = [];
  int _statementCurrentPage = 1;
  final int _statementItemsPerPage = 10;
  String _periodMonthFilter = '';
  final Set<String> _knownPeriods = {
    DateTime.now().toIso8601String().substring(0, 7),
  };
  final TextEditingController _statementSearchController =
      TextEditingController();

  // --- Tab 2: Payments Log State ---
  bool _isPaymentsLoading = false;
  List<dynamic> _payments = [];
  int _paymentsPage = 0;
  int _paymentsTotalPages = 1;
  int _paymentsTotalElements = 0;
  final int _paymentsPageSize = 15;
  String _paymentStatusFilter = 'ALL';
  String _paymentSettlementStatusFilter = 'ALL';
  final TextEditingController _paymentSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
    _fetchStatements();
    _fetchPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _statementSearchController.dispose();
    _paymentSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStatements() async {
    setState(() {
      _isLoading = true;
      _statementCurrentPage = 1;
    });
    final data = await _revenueService.getCourseManagerStatements(
      periodMonth: _periodMonthFilter,
    );
    if (mounted) {
      setState(() {
        _statements = data;
        for (final s in data) {
          final p = s['periodMonth']?.toString();
          if (p != null && p.trim().isNotEmpty) {
            _knownPeriods.add(p.trim());
          }
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchPayments() async {
    setState(() => _isPaymentsLoading = true);
    final res = await _revenueService.getAllPayments(
      page: _paymentsPage,
      size: _paymentsPageSize,
      status: _paymentStatusFilter,
      settlementStatus: _paymentSettlementStatusFilter,
      search: _paymentSearchController.text.trim(),
    );
    if (mounted) {
      setState(() {
        if (res != null) {
          _payments = res['content'] as List? ?? [];
          _paymentsTotalPages = (res['totalPages'] ?? 1) as int;
          _paymentsTotalElements = (res['totalElements'] ?? 0) as int;
        } else {
          _payments = [];
          _paymentsTotalPages = 1;
          _paymentsTotalElements = 0;
        }
        _isPaymentsLoading = false;
      });
    }
  }

  Future<void> _triggerCutoff() async {
    final isVi = LanguageManager.isVi;
    setState(() => _isLoading = true);
    final generated = await _revenueService.generateMonthlyCutoff(
      periodMonth: _periodMonthFilter,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (generated.isNotEmpty) {
        ToastHelper.showSuccess(
          context,
          isVi
              ? 'Đã chốt sổ thành công và gửi thông báo/email cho ${generated.length} giáo viên!'
              : 'Cutoff completed and emails/notifications sent to ${generated.length} trainers!',
        );
        _fetchStatements();
        _fetchPayments();
      } else {
        ToastHelper.show(
          context,
          isVi
              ? 'Không có đơn hàng mới nào cần chốt kỳ.'
              : 'No pending orders found for cutoff.',
        );
        _fetchStatements();
      }
    }
  }

  Future<void> _exportStatementsExcel() async {
    final isVi = LanguageManager.isVi;
    setState(() => _isLoading = true);
    final bytes = await _revenueService.exportStatementsExcel(
      periodMonth: _periodMonthFilter,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (bytes != null && bytes.isNotEmpty) {
        downloadBytes(
          bytes: bytes,
          filename:
              'HanGo_Revenue_Statements_${_periodMonthFilter.isNotEmpty ? _periodMonthFilter : "All"}.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        ToastHelper.showSuccess(
          context,
          isVi
              ? 'Đã tải xuống file Excel Bảng kê thành công!'
              : 'Statements Excel downloaded successfully!',
        );
      } else {
        ToastHelper.showError(
          context,
          isVi
              ? 'Không thể tải xuống file Excel Bảng kê.'
              : 'Failed to download Statements Excel file.',
        );
      }
    }
  }

  Future<void> _exportPaymentsExcel() async {
    final isVi = LanguageManager.isVi;
    setState(() => _isPaymentsLoading = true);
    final bytes = await _revenueService.exportPaymentsExcel(
      status: _paymentStatusFilter,
      settlementStatus: _paymentSettlementStatusFilter,
      search: _paymentSearchController.text.trim(),
    );
    if (mounted) {
      setState(() => _isPaymentsLoading = false);
      if (bytes != null && bytes.isNotEmpty) {
        downloadBytes(
          bytes: bytes,
          filename: 'HanGo_Payment_Transactions.xlsx',
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        ToastHelper.showSuccess(
          context,
          isVi
              ? 'Đã tải xuống file Excel Giao dịch thành công!'
              : 'Transactions Excel downloaded successfully!',
        );
      } else {
        ToastHelper.showError(
          context,
          isVi
              ? 'Không thể tải xuống file Excel Giao dịch.'
              : 'Failed to download Transactions Excel file.',
        );
      }
    }
  }

  void _showStatementDetailDialog(Map<String, dynamic> statement) {
    final isVi = LanguageManager.isVi;
    final statementId = (statement['id'] ?? 0) as int;
    final code = statement['statementCode']?.toString() ?? 'N/A';
    final trainerName = statement['trainerName'] ?? 'N/A';
    final trainerEmail = statement['trainerEmail'] ?? 'N/A';
    final trainerType = statement['trainerType'] ?? 'PROFESSIONAL';
    final period = statement['periodMonth'] ?? 'N/A';
    final gross = statement['totalGrossAmount'] ?? 0;
    final pFee = statement['totalPlatformFee'] ?? 0;
    final net = statement['netPayoutAmount'] ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.all(24),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi
                    ? 'Chi tiết Bảng kê ($code)'
                    : 'Statement Breakdown ($code)',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  fontFamily: 'Outfit',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: Container(
            width: 850,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Header info & Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$trainerName ($trainerEmail)',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isVi
                                ? 'Kỳ tháng: $period | Loại: ${trainerType == 'PEER_TUTOR' ? 'Gia sư (60/40)' : 'Giáo viên (70/30)'}'
                                : 'Period: $period | Type: ${trainerType == 'PEER_TUTOR' ? 'Tutor (60/40)' : 'Teacher (70/30)'}',
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Financial Calculation Breakdown Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi
                              ? 'Bảng Tính Doanh thu & Khấu trừ'
                              : 'Revenue Calculation Breakdown',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: Color(0xFF0F172A),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogRow(
                          isVi
                              ? 'Tổng doanh thu gộp (Gross Sales):'
                              : 'Total Gross Sales:',
                          _formatVND(gross),
                        ),
                        const SizedBox(height: 8),
                        _buildDialogRow(
                          isVi
                              ? '(-) Phí sàn HanGo (${trainerType == 'PEER_TUTOR' ? '40%' : '30%'}):'
                              : '(-) Platform Service Fee (${trainerType == 'PEER_TUTOR' ? '40%' : '30%'}):',
                          '- ${_formatVND(pFee)}',
                        ),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isVi
                                  ? '(=) Thu nhập thực nhận (Net Payout):'
                                  : '(=) Final Net Payout Amount:',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            Text(
                              _formatVND(net),
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF28B79B),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),
                  Text(
                    isVi
                        ? 'Tổng quan Số liệu Tính toán theo Khóa học'
                        : 'Course Revenue Calculation Breakdown',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Calculated Course Metrics Summary Table
                  FutureBuilder<List<dynamic>>(
                    future: _revenueService.getStatementPayments(statementId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF28B79B),
                            ),
                          ),
                        );
                      }
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          child: Text(
                            isVi
                                ? 'Không có dữ liệu khóa học trong kỳ.'
                                : 'No course breakdown data found.',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        );
                      }

                      // Aggregate orders by Course Title
                      Map<String, Map<String, dynamic>> courseMetrics = {};
                      for (var item in items) {
                        String cTitle =
                            item['courseTitle']?.toString() ??
                            (isVi
                                ? 'Khóa học chưa đặt tên'
                                : 'Untitled Course');
                        double amt =
                            (item['amount'] as num?)?.toDouble() ?? 0.0;
                        double platformFee =
                            (item['platformFee'] as num?)?.toDouble() ??
                            (amt * (trainerType == 'PEER_TUTOR' ? 0.40 : 0.30));
                        double trainerEarn =
                            (item['trainerEarnings'] as num?)?.toDouble() ??
                            (amt - platformFee);

                        if (!courseMetrics.containsKey(cTitle)) {
                          courseMetrics[cTitle] = {
                            'title': cTitle,
                            'orderCount': 0,
                            'gross': 0.0,
                            'pFee': 0.0,
                            'tEarn': 0.0,
                          };
                        }
                        courseMetrics[cTitle]!['orderCount'] =
                            (courseMetrics[cTitle]!['orderCount'] as int) + 1;
                        courseMetrics[cTitle]!['gross'] =
                            (courseMetrics[cTitle]!['gross'] as double) + amt;
                        courseMetrics[cTitle]!['pFee'] =
                            (courseMetrics[cTitle]!['pFee'] as double) +
                            platformFee;
                        courseMetrics[cTitle]!['tEarn'] =
                            (courseMetrics[cTitle]!['tEarn'] as double) +
                            trainerEarn;
                      }

                      final courseList = courseMetrics.values.toList();
                      int totalOrders = items.length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary KPI Pills
                          Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(
                                      isVi ? 'Số Khóa học' : 'Active Courses',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${courseList.length}',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 24,
                                  width: 1,
                                  color: const Color(0xFFCBD5E1),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      isVi
                                          ? 'Tổng lượt đăng ký'
                                          : 'Total Orders',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$totalOrders',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  height: 24,
                                  width: 1,
                                  color: const Color(0xFFCBD5E1),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      isVi
                                          ? 'Giá trị Đơn TB'
                                          : 'Avg Order Value',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatVND(
                                        totalOrders > 0
                                            ? (gross / totalOrders)
                                            : 0,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0F172A),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          // Calculated Metrics Table
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              headingRowHeight: 40,
                              dataRowHeight: 44,
                              headingRowColor: WidgetStateProperty.all(
                                const Color(0xFFF8FAFC),
                              ),
                              columns: [
                                DataColumn(
                                  label: Text(
                                    isVi ? 'Khóa học' : 'Course Title',
                                    style: _headerStyle,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    isVi ? 'Số đơn' : 'Orders',
                                    style: _headerStyle,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    isVi ? 'Doanh thu Gộp' : 'Gross Sales',
                                    style: _headerStyle,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    isVi ? 'Phí Sàn' : 'Platform Fee',
                                    style: _headerStyle,
                                  ),
                                ),
                                DataColumn(
                                  label: Text(
                                    isVi ? 'Thu nhập GV' : 'Trainer Earnings',
                                    style: _headerStyle,
                                  ),
                                ),
                              ],
                              rows: courseList.map((c) {
                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        c['title'].toString(),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '${c['orderCount']}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatVND(c['gross']),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        '- ${_formatVND(c['pFee'])}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFDC2626),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      Text(
                                        _formatVND(c['tEarn']),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF28B79B),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isVi ? 'Đóng' : 'Close',
                style: const TextStyle(
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }


  Widget _buildDialogRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  String _formatVND(dynamic amount) {
    if (amount == null) return '0 VNĐ';
    final val = (amount as num).toDouble();
    return '${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VNĐ';
  }

  String _formatDateTime(dynamic dateTime) {
    if (dateTime == null) return '-';
    try {
      final str = dateTime.toString();
      if (str.isEmpty || str == 'null') return '-';
      final dt = DateTime.parse(str).toLocal();
      final day = dt.day.toString().padLeft(2, '0');
      final month = dt.month.toString().padLeft(2, '0');
      final year = dt.year.toString();
      final hour = dt.hour.toString().padLeft(2, '0');
      final minute = dt.minute.toString().padLeft(2, '0');
      return '$day/$month/$year $hour:$minute';
    } catch (_) {
      return dateTime.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isVi = LanguageManager.isVi;

    final Widget bodyContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildContentHeader(context, isDesktop),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(isVi),
                const SizedBox(height: 20),
                _buildTabBar(isVi),
                const SizedBox(height: 20),
                _tabController.index == 0
                    ? _buildStatementsTab(isVi)
                    : _buildPaymentsTab(isVi),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.isEmbedded) {
      return bodyContent;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: InternalAppHeader(isMobile: !(isDesktop), activeTab: ''),
      drawer: !isDesktop
          ? const Drawer(
              child: CourseManagerSidebar(currentRoute: 'settlement'),
            )
          : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(
              width: 240,
              child: CourseManagerSidebar(currentRoute: 'settlement'),
            ),
          Expanded(child: bodyContent),
        ],
      ),
    );
  }

  Widget _buildContentHeader(BuildContext context, bool isDesktop) {
    if (isDesktop) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(bool isVi) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVi
                  ? 'Quản lý Quyết toán & Doanh thu'
                  : 'Revenue Settlement Management',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar(bool isVi) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (index) {
          setState(() {});
          if (index == 0) {
            _fetchStatements();
          } else {
            _fetchPayments();
          }
        },
        indicatorColor: const Color(0xFF28B79B),
        labelColor: const Color(0xFF28B79B),
        unselectedLabelColor: const Color(0xFF64748B),
        labelStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          fontFamily: 'Outfit',
          fontSize: 15,
        ),
        tabs: [
          Tab(
            iconMargin: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long, size: 18),
                const SizedBox(width: 8),
                Text(
                  isVi ? 'Bảng kê quyết toán hàng tháng' : 'Monthly Statements',
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.list_alt, size: 18),
                const SizedBox(width: 8),
                Text(
                  isVi
                      ? 'Danh sách tất cả giao dịch lẻ'
                      : 'All Payment Transactions',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- TAB 1: STATEMENTS TAB ---
  Widget _buildStatementsTab(bool isVi) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi
                    ? 'Danh sách Báo cáo Quyết toán'
                    : 'Settlement Statements List',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _exportStatementsExcel,
                    icon: const Icon(
                      Icons.file_download_outlined,
                      size: 18,
                      color: Color(0xFF16A34A),
                    ),
                    label: Text(
                      isVi ? 'Xuất Excel Bảng kê' : 'Export Statements Excel',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF16A34A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF16A34A)),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _triggerCutoff,
                    icon: const Icon(Icons.calculate_outlined, size: 18),
                    label: Text(
                      isVi
                          ? 'Chốt Kỳ Quyết Toán Mới'
                          : 'Trigger Monthly Cutoff',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28B79B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      Icons.refresh_rounded,
                      color: Color(0xFF64748B),
                    ),
                    onPressed: _fetchStatements,
                    tooltip: isVi ? 'Làm mới' : 'Refresh',
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filters bar for Statements Tab
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search input
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _statementSearchController,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: isVi
                        ? 'Mã BC, Giáo viên, Số TK...'
                        : 'Search Code, Trainer, Bank...',
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF28B79B),
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: _statementSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _statementSearchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
              ),

              // Period Month Filter Dropdown (Dynamic Periods)
              Builder(
                builder: (context) {
                  final dynamicPeriods = Set<String>.from(_knownPeriods);
                  for (final s in _statements) {
                    final p = s['periodMonth']?.toString();
                    if (p != null && p.trim().isNotEmpty) {
                      dynamicPeriods.add(p.trim());
                    }
                  }
                  final sortedPeriods = dynamicPeriods.toList()
                    ..sort((a, b) => b.compareTo(a));

                  final currentPeriodLabel = _periodMonthFilter.isEmpty
                      ? (isVi ? 'Tất cả kỳ tháng' : 'All Periods')
                      : (isVi
                            ? 'Kỳ $_periodMonthFilter'
                            : 'Period $_periodMonthFilter');

                  return PopupMenuButton<String>(
                    position: PopupMenuPosition.under,
                    offset: const Offset(0, 6),
                    color: Colors.white,
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    onSelected: (val) {
                      setState(() {
                        _periodMonthFilter = val == 'ALL' ? '' : val;
                      });
                      _fetchStatements();
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: 'ALL',
                        child: Text(isVi ? 'Tất cả kỳ tháng' : 'All Periods'),
                      ),
                      ...sortedPeriods.map(
                        (p) => PopupMenuItem(
                          value: p,
                          child: Text(isVi ? 'Kỳ $p' : 'Period $p'),
                        ),
                      ),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            currentPeriodLabel,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0F172A),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.arrow_drop_down_rounded,
                            color: Color(0xFF64748B),
                            size: 24,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF28B79B)),
              ),
            )
          else if (_statements.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 48,
                    color: Color(0xFFCBD5E1),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isVi
                        ? 'Chưa có dữ liệu quyết toán.'
                        : 'No settlement statements available.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            )
          else
            Builder(
              builder: (context) {
                final searchKey = _statementSearchController.text
                    .trim()
                    .toLowerCase();
                final displayList = _statements.where((s) {
                  if (searchKey.isEmpty) return true;
                  final code = (s['statementCode'] ?? '')
                      .toString()
                      .toLowerCase();
                  final trainer = (s['trainerName'] ?? '')
                      .toString()
                      .toLowerCase();
                  final bank = (s['bankName'] ?? '').toString().toLowerCase();
                  final acc = (s['bankAccount'] ?? '').toString().toLowerCase();
                  final accName = (s['bankAccountName'] ?? '')
                      .toString()
                      .toLowerCase();
                  return code.contains(searchKey) ||
                      trainer.contains(searchKey) ||
                      bank.contains(searchKey) ||
                      acc.contains(searchKey) ||
                      accName.contains(searchKey);
                }).toList();

                if (displayList.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(40),
                    alignment: Alignment.center,
                    child: Column(
                      children: [
                        const Icon(
                          Icons.search_off_outlined,
                          size: 48,
                          color: Color(0xFFCBD5E1),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          isVi
                              ? 'Không tìm thấy Báo cáo Quyết toán nào phù hợp.'
                              : 'No matching settlement statements found.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF64748B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                  );
                }

                displayList.sort((a, b) {
                  final timeA = a['createdAt']?.toString() ?? '';
                  final timeB = b['createdAt']?.toString() ?? '';
                  if (timeA.isNotEmpty && timeB.isNotEmpty) {
                    return timeB.compareTo(timeA);
                  }
                  final idA = (a['id'] ?? 0) as int;
                  final idB = (b['id'] ?? 0) as int;
                  return idB.compareTo(idA);
                });

                final totalItems = displayList.length;
                final totalPages = (totalItems / _statementItemsPerPage)
                    .ceil()
                    .clamp(1, 999999);
                final safeCurrentPage = _statementCurrentPage.clamp(
                  1,
                  totalPages,
                );
                final startIndex =
                    (safeCurrentPage - 1) * _statementItemsPerPage;
                final endIndex =
                    (startIndex + _statementItemsPerPage > totalItems)
                    ? totalItems
                    : startIndex + _statementItemsPerPage;
                final paginatedList = displayList.sublist(
                  startIndex < totalItems ? startIndex : 0,
                  endIndex <= totalItems ? endIndex : totalItems,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF8FAFC),
                        ),
                        columns: [
                          DataColumn(
                            label: Text(
                              isVi ? 'Mã Báo cáo' : 'Statement Code',
                              style: _headerStyle,
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              isVi ? 'Thời gian tạo' : 'Created At',
                              style: _headerStyle,
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              isVi ? 'Giáo viên' : 'Trainer Name',
                              style: _headerStyle,
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              isVi ? 'Loại' : 'Type',
                              style: _headerStyle,
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              isVi ? 'Kỳ Tháng' : 'Period',
                              style: _headerStyle,
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              isVi ? 'Tổng Gross' : 'Gross',
                              style: _headerStyle,
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              isVi ? 'Thực nhận (Net)' : 'Net Payout',
                              style: _headerStyle,
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              isVi ? 'Tài khoản Ngân hàng' : 'Bank Account',
                              style: _headerStyle,
                            ),
                          ),
                        ],
                        rows: paginatedList.map((s) {
                          final net = s['netPayoutAmount'] ?? 0;
                          final gross = s['totalGrossAmount'] ?? 0;
                          final trainerName = s['trainerName'] ?? 'N/A';
                          final trainerType =
                              s['trainerType'] ?? 'PROFESSIONAL';
                          final bankName = s['bankName'] ?? '';
                          final bankAcc = s['bankAccount'] ?? '';
                          final bankAccName = s['bankAccountName'] ?? '';

                          return DataRow(
                            cells: [
                              DataCell(
                                InkWell(
                                  onTap: () => _showStatementDetailDialog(
                                    s as Map<String, dynamic>,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Text(
                                      s['statementCode']?.toString() ?? 'N/A',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF2563EB),
                                        decoration:
                                            TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  _formatDateTime(
                                    s['paidAt'] ??
                                        s['createdAt'] ??
                                        s['trainerConfirmedAt'],
                                  ),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                              DataCell(
                                InkWell(
                                  onTap: () => _showStatementDetailDialog(
                                    s as Map<String, dynamic>,
                                  ),
                                  child: Text(
                                    trainerName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  trainerType == 'PEER_TUTOR'
                                      ? 'Tutor'
                                      : 'Teacher',
                                ),
                              ),

                              DataCell(
                                Text(s['periodMonth']?.toString() ?? 'N/A'),
                              ),
                              DataCell(Text(_formatVND(gross))),
                              DataCell(
                                Text(
                                  _formatVND(net),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF28B79B),
                                  ),
                                ),
                              ),
                              DataCell(
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '$bankName - $bankAcc',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      bankAccName,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                    if (totalItems > 0)
                      _buildPaginationFooter(
                        totalItems: totalItems,
                        startIndex: startIndex,
                        endIndex: endIndex,
                        currentPage: safeCurrentPage,
                        totalPages: totalPages,
                        onPageChanged: (page) =>
                            setState(() => _statementCurrentPage = page),
                        isVi: isVi,
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  // --- TAB 2: PAYMENTS TAB ---
  Widget _buildPaymentsTab(bool isVi) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi
                    ? 'Danh sách Tất cả Giao dịch Thanh toán'
                    : 'All Payment Transactions',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
              OutlinedButton.icon(
                onPressed: _exportPaymentsExcel,
                icon: const Icon(
                  Icons.file_download_outlined,
                  size: 18,
                  color: Color(0xFF16A34A),
                ),
                label: Text(
                  isVi ? 'Xuất Excel Giao dịch' : 'Export Transactions Excel',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF16A34A),
                    fontFamily: 'Outfit',
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF16A34A)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Filters bar
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Search input
              SizedBox(
                width: 280,
                child: TextField(
                  controller: _paymentSearchController,
                  onSubmitted: (_) {
                    setState(() => _paymentsPage = 0);
                    _fetchPayments();
                  },
                  decoration: InputDecoration(
                    hintText: isVi
                        ? 'Mã GD, Learner, Khóa học, Trainer...'
                        : 'Search Txn, Learner, Course...',
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: Color(0xFF64748B),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(
                        color: Color(0xFF28B79B),
                        width: 1.5,
                      ),
                    ),
                    suffixIcon: _paymentSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _paymentSearchController.clear();
                              setState(() => _paymentsPage = 0);
                              _fetchPayments();
                            },
                          )
                        : null,
                  ),
                ),
              ),
              // Payment Status Filter
              PopupMenuButton<String>(
                position: PopupMenuPosition.under,
                offset: const Offset(0, 6),
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                onSelected: (val) {
                  setState(() {
                    _paymentStatusFilter = val;
                    _paymentsPage = 0;
                  });
                  _fetchPayments();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'ALL',
                    child: Text(
                      isVi ? 'Tất cả trạng thái GD' : 'All Payment Statuses',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'SUCCESS',
                    child: Text(isVi ? 'Thành công' : 'Success'),
                  ),
                  PopupMenuItem(
                    value: 'PENDING',
                    child: Text(isVi ? 'Đang chờ' : 'Pending'),
                  ),
                  PopupMenuItem(
                    value: 'FAILED',
                    child: Text(isVi ? 'Thất bại' : 'Failed'),
                  ),
                  PopupMenuItem(
                    value: 'EXPIRED',
                    child: Text(isVi ? 'Hết hạn' : 'Expired'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _paymentStatusFilter == 'SUCCESS'
                            ? (isVi ? 'Thành công' : 'Success')
                            : (_paymentStatusFilter == 'PENDING'
                                  ? (isVi ? 'Đang chờ' : 'Pending')
                                  : (_paymentStatusFilter == 'FAILED'
                                        ? (isVi ? 'Thất bại' : 'Failed')
                                        : (_paymentStatusFilter == 'EXPIRED'
                                              ? (isVi ? 'Hết hạn' : 'Expired')
                                              : (isVi
                                                    ? 'Tất cả trạng thái GD'
                                                    : 'All Payment Statuses')))),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Color(0xFF64748B),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),
              // Settlement Status Filter
              PopupMenuButton<String>(
                position: PopupMenuPosition.under,
                offset: const Offset(0, 6),
                color: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                onSelected: (val) {
                  setState(() {
                    _paymentSettlementStatusFilter = val;
                    _paymentsPage = 0;
                  });
                  _fetchPayments();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'ALL',
                    child: Text(
                      isVi
                          ? 'Tất cả trạng thái đối soát'
                          : 'All Settlement Statuses',
                    ),
                  ),
                  PopupMenuItem(
                    value: 'PENDING',
                    child: Text(isVi ? 'Chưa chốt kỳ' : 'Pending Cutoff'),
                  ),
                  PopupMenuItem(
                    value: 'IN_STATEMENT',
                    child: Text(isVi ? 'Đã gom bảng kê' : 'In Statement'),
                  ),
                  PopupMenuItem(
                    value: 'SETTLED',
                    child: Text(isVi ? 'Đã đối soát xong' : 'Settled'),
                  ),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _paymentSettlementStatusFilter == 'PENDING'
                            ? (isVi ? 'Chưa chốt kỳ' : 'Pending Cutoff')
                            : (_paymentSettlementStatusFilter == 'IN_STATEMENT'
                                  ? (isVi ? 'Đã gom bảng kê' : 'In Statement')
                                  : (_paymentSettlementStatusFilter == 'SETTLED'
                                        ? (isVi
                                              ? 'Đã đối soát xong'
                                              : 'Settled')
                                        : (isVi
                                              ? 'Tất cả trạng thái đối soát'
                                              : 'All Settlement Statuses'))),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0F172A),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_drop_down_rounded,
                        color: Color(0xFF64748B),
                        size: 24,
                      ),
                    ],
                  ),
                ),
              ),

              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.refresh_rounded,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: () {
                    setState(() => _paymentsPage = 0);
                    _fetchPayments();
                  },
                  tooltip: isVi ? 'Làm mới' : 'Refresh',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isPaymentsLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF28B79B)),
              ),
            )
          else if (_payments.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(
                    Icons.payment_outlined,
                    size: 48,
                    color: Color(0xFFCBD5E1),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isVi
                        ? 'Không tìm thấy giao dịch nào phù hợp.'
                        : 'No payment transactions found.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  if (_paymentStatusFilter != 'ALL' ||
                      _paymentSettlementStatusFilter != 'ALL' ||
                      _paymentSearchController.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        isVi
                            ? 'Mẹo: Bạn đang lọc trạng thái. Hãy chọn "Tất cả trạng thái GD" để xem danh sách giao dịch thành công.'
                            : 'Tip: Active filters applied. Switch to "All Payment Statuses" to view successful transactions.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            )
          else
            Column(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: WidgetStateProperty.all(
                      const Color(0xFFF8FAFC),
                    ),
                    columns: [
                      DataColumn(
                        label: Text(isVi ? 'STT' : 'No', style: _headerStyle),
                      ),
                      DataColumn(
                        label: Text(
                          isVi ? 'Thời gian GD' : 'Payment Time',
                          style: _headerStyle,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          isVi ? 'Mã GD (TxnRef)' : 'Txn Reference',
                          style: _headerStyle,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          isVi ? 'Học viên' : 'Learner',
                          style: _headerStyle,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          isVi ? 'Khóa học' : 'Course Title',
                          style: _headerStyle,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          isVi ? 'Giáo viên' : 'Trainer',
                          style: _headerStyle,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          isVi ? 'Số tiền' : 'Amount',
                          style: _headerStyle,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          isVi ? 'Phí sàn' : 'Platform Fee',
                          style: _headerStyle,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          isVi ? 'Thu nhập GV' : 'Trainer Earn',
                          style: _headerStyle,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          isVi ? 'Trạng thái GD' : 'Payment Status',
                          style: _headerStyle,
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          isVi ? 'Trạng thái Đối soát' : 'Settlement',
                          style: _headerStyle,
                        ),
                      ),
                    ],
                    rows: List.generate(_payments.length, (idx) {
                      final p = _payments[idx] as Map<String, dynamic>;
                      final txnRef = p['txnRef']?.toString() ?? 'N/A';
                      final learnerName = p['learnerName']?.toString() ?? 'N/A';
                      final learnerEmail = p['learnerEmail']?.toString() ?? '';
                      final courseTitle = p['courseTitle']?.toString() ?? 'N/A';
                      final trainerName = p['trainerName']?.toString() ?? 'N/A';
                      final amount = p['amount'] ?? 0;
                      final pFee = p['platformFee'] ?? 0;
                      final tEarn = p['trainerEarnings'] ?? 0;
                      final status = p['status']?.toString() ?? 'PENDING';
                      final sStatus =
                          p['settlementStatus']?.toString() ?? 'PENDING';

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              '${_paymentsPage * _paymentsPageSize + idx + 1}',
                            ),
                          ),
                          DataCell(
                            Text(
                              _formatDateTime(p['paidAt'] ?? p['createdAt']),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              txnRef,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          DataCell(
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  learnerName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                                Text(
                                  learnerEmail,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          DataCell(
                            Text(
                              courseTitle,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              trainerName,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          DataCell(
                            Text(
                              _formatVND(amount),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              _formatVND(pFee),
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                          ),
                          DataCell(
                            Text(
                              _formatVND(tEarn),
                              style: const TextStyle(
                                color: Color(0xFF28B79B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(_buildPaymentStatusBadge(status, isVi)),
                          DataCell(_buildSettlementStatusBadge(sStatus, isVi)),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                if (_paymentsTotalElements > 0)
                  _buildPaginationFooter(
                    totalItems: _paymentsTotalElements,
                    startIndex: _paymentsPage * _paymentsPageSize,
                    endIndex:
                        (_paymentsPage * _paymentsPageSize + _payments.length),
                    currentPage: _paymentsPage + 1,
                    totalPages: _paymentsTotalPages == 0
                        ? 1
                        : _paymentsTotalPages,
                    onPageChanged: (page) {
                      setState(() => _paymentsPage = page - 1);
                      _fetchPayments();
                    },
                    isVi: isVi,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildPaginationFooter({
    required int totalItems,
    required int startIndex,
    required int endIndex,
    required int currentPage,
    required int totalPages,
    required Function(int) onPageChanged,
    required bool isVi,
  }) {
    if (totalItems == 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;
          final entriesText = Text(
            isVi
                ? 'Hiển thị ${totalItems == 0 ? 0 : startIndex + 1} đến $endIndex của $totalItems mục'
                : 'Showing ${totalItems == 0 ? 0 : startIndex + 1} to $endIndex of $totalItems entries',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
          );

          final paginationControls = SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildPaginationButton(
                  Icons.chevron_left,
                  onPressed: currentPage > 1
                      ? () => onPageChanged(currentPage - 1)
                      : null,
                ),
                const SizedBox(width: 8),
                ..._getPageNumbers(currentPage, totalPages).map((p) {
                  if (p == null) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        '...',
                        style: TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildPaginationNumber(
                      p.toString(),
                      isActive: p == currentPage,
                      onPressed: () => onPageChanged(p),
                    ),
                  );
                }),
                _buildPaginationButton(
                  Icons.chevron_right,
                  onPressed: currentPage < totalPages
                      ? () => onPageChanged(currentPage + 1)
                      : null,
                ),
              ],
            ),
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                entriesText,
                const SizedBox(height: 12),
                paginationControls,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [entriesText, paginationControls],
          );
        },
      ),
    );
  }

  Widget _buildPaginationButton(IconData icon, {VoidCallback? onPressed}) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: onPressed == null ? const Color(0xFFF8FAFC) : Colors.white,
          border: Border.all(color: const Color(0xFFE2E8F0)),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: onPressed == null
              ? const Color(0xFFCBD5E1)
              : const Color(0xFF64748B),
        ),
      ),
    );
  }

  Widget _buildPaginationNumber(
    String text, {
    bool isActive = false,
    VoidCallback? onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF28B79B) : Colors.white,
          border: Border.all(
            color: isActive ? const Color(0xFF28B79B) : const Color(0xFFE2E8F0),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: isActive ? Colors.white : const Color(0xFF64748B),
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  List<int?> _getPageNumbers(int currentPage, int totalPages) {
    if (totalPages <= 7) {
      return List.generate(totalPages, (index) => index + 1);
    }
    if (currentPage <= 4) {
      return [1, 2, 3, 4, 5, null, totalPages];
    }
    if (currentPage >= totalPages - 3) {
      return [
        1,
        null,
        totalPages - 4,
        totalPages - 3,
        totalPages - 2,
        totalPages - 1,
        totalPages,
      ];
    }
    return [
      1,
      null,
      currentPage - 1,
      currentPage,
      currentPage + 1,
      null,
      totalPages,
    ];
  }

  TextStyle get _headerStyle => const TextStyle(
    fontWeight: FontWeight.bold,
    fontSize: 13,
    color: Color(0xFF475569),
    fontFamily: 'Outfit',
  );



  Widget _buildPaymentStatusBadge(String status, bool isVi) {
    String text = status;
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    if (status == 'SUCCESS') {
      text = isVi ? 'Thành công' : 'Success';
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (status == 'PENDING') {
      text = isVi ? 'Đang chờ' : 'Pending';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (status == 'FAILED') {
      text = isVi ? 'Thất bại' : 'Failed';
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else if (status == 'EXPIRED') {
      text = isVi ? 'Hết hạn' : 'Expired';
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _buildSettlementStatusBadge(String sStatus, bool isVi) {
    String text = sStatus;
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    if (sStatus == 'PENDING') {
      text = isVi ? 'Chưa chốt' : 'Pending Cutoff';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (sStatus == 'IN_STATEMENT') {
      text = isVi ? 'Đã vào bảng kê' : 'In Statement';
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
    } else if (sStatus == 'SETTLED') {
      text = isVi ? 'Đã quyết toán' : 'Settled';
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: fg,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

}
