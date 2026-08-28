import 'package:flutter/material.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/revenue_settlement_service.dart';
import '../../../utils/language_manager.dart';
import '../../widgets/trainer/trainer_sidebar.dart';

class TrainerRevenuePage extends StatefulWidget {
  final bool isEmbedded;
  const TrainerRevenuePage({super.key, this.isEmbedded = false});

  @override
  State<TrainerRevenuePage> createState() => _TrainerRevenuePageState();
}

class _TrainerRevenuePageState extends State<TrainerRevenuePage> {
  final _revenueService = RevenueSettlementService();

  bool _isLoading = true;
  String _trainerName = '';

  Map<String, dynamic>? _summaryData;
  List<dynamic> _statements = [];

  @override
  void initState() {
    super.initState();
    _loadHeaderInfo();
    _fetchRevenueData();
  }

  Future<void> _loadHeaderInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Trainer';
    setState(() {
      _trainerName = fullName;
    });
  }

  Future<void> _fetchRevenueData() async {
    setState(() => _isLoading = true);
    final summary = await _revenueService.getTrainerRevenueSummary();
    if (mounted) {
      setState(() {
        _summaryData = summary;
        _statements = summary?['statements'] as List? ?? [];
        _isLoading = false;
      });
    }
  }

  String _formatVND(dynamic amount) {
    if (amount == null) return '0 VNĐ';
    final val = (amount as num).toDouble();
    return '${val.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} VNĐ';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isVi = LanguageManager.isVi;

    if (widget.isEmbedded) {
      return _buildBodyContent(isVi);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? const Drawer(child: TrainerSidebar(activeIndex: 4)) : null,
      body: Row(
        children: [
          if (isDesktop) const SizedBox(width: 260, child: TrainerSidebar(activeIndex: 4)),
          Expanded(
            child: Column(
              children: [
                InternalAppHeader(isMobile: !isDesktop),
                Expanded(
                  child: _buildBodyContent(isVi),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBodyContent(bool isVi) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator(color: Color(0xFF28B79B)))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTitleSection(isVi),
                const SizedBox(height: 24),
                _buildKpiCards(isVi),
                const SizedBox(height: 32),
                _buildStatementsTable(isVi),
              ],
            ),
          );
  }

  Widget _buildTitleSection(bool isVi) {
    final trainerType = _summaryData?['trainerType'] ?? 'PROFESSIONAL';
    final typeLabel = trainerType == 'PEER_TUTOR'
        ? (isVi ? 'Gia sư (Chia 60/40)' : 'Tutor (60/40 Split)')
        : (isVi ? 'Giáo viên (Chia 70/30)' : 'Teacher (70/30 Split)');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVi ? 'Doanh thu & Quyết toán' : 'Revenue & Settlement',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
        Row(
          children: [
            OutlinedButton.icon(
              onPressed: () => _showSalaryCalculationModal(context, isVi),
              icon: const Icon(Icons.help_outline_rounded, color: Color(0xFF28B79B), size: 18),
              label: Text(
                isVi ? 'Công thức tính lương' : 'Salary Breakdown',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF28B79B), fontFamily: 'Outfit'),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF28B79B)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F4F1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF28B79B).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.stars_rounded, color: Color(0xFF28B79B), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    typeLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D),
                      fontSize: 13,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSalaryCalculationModal(BuildContext context, bool isVi) {
    final trainerType = _summaryData?['trainerType'] ?? 'PROFESSIONAL';
    final isTeacher = trainerType == 'PROFESSIONAL';

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 600),
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.calculate_rounded, color: Color(0xFF28B79B), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          isVi ? 'Chính sách & Công thức tính lương' : 'Salary & Revenue Policy',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFFE2E8F0)),
                const SizedBox(height: 16),
                _buildPolicyRow(
                  icon: Icons.pie_chart_outline_rounded,
                  title: isVi ? '1. Tỷ lệ phân chia doanh thu' : '1. Revenue Split Ratio',
                  content: isTeacher
                      ? (isVi
                          ? '• Loại tài khoản: Giáo viên (Teacher).\n• Tỷ lệ: 70% thuộc về Giáo viên, 30% phí nền tảng HanGo.'
                          : '• Account Type: Teacher.\n• Ratio: 70% Trainer Share / 30% HanGo Platform Fee.')
                      : (isVi
                          ? '• Loại tài khoản: Gia sư (Tutor).\n• Tỷ lệ: 60% thuộc về Gia sư, 40% phí nền tảng HanGo.'
                          : '• Account Type: Tutor.\n• Ratio: 60% Trainer Share / 40% HanGo Platform Fee.'),
                ),
                const SizedBox(height: 16),
                _buildPolicyRow(
                  icon: Icons.hourglass_top_rounded,
                  title: isVi ? '2. Thời gian giữ tiền bảo hành 7 ngày' : '2. 7-Day Pending Hold Warranty',
                  content: isVi
                      ? '• Doanh thu khóa học mới mua sẽ giữ ở trạng thái Tạm giữ trong 7 ngày để phục vụ chính sách hoàn tiền cho học viên.\n• Sau 7 ngày, tiền tự động chuyển sang Số dư khả dụng.'
                      : '• Course sales are held in Pending Hold for 7 days to cover student refund warranties.\n• After 7 days, funds automatically transfer to Available Balance.',
                ),
                const SizedBox(height: 16),
                _buildPolicyRow(
                  icon: Icons.calendar_month_rounded,
                  title: isVi ? '3. Chốt sổ doanh thu hàng tháng' : '3. Monthly Revenue Settlement',
                  content: isVi
                      ? '• Quản lý đào tạo thực hiện chốt sổ báo cáo doanh thu định kỳ hàng tháng.\n• Báo cáo chi tiết và xác nhận quyết toán được gửi trực tiếp đến Email và chuông thông báo hệ thống của bạn.'
                      : '• Monthly revenue statements are cut off at the end of each billing cycle.\n• Summary notices and reports are dispatched directly to your Email and In-App notifications.',
                ),
                const SizedBox(height: 24),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28B79B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(isVi ? 'Đã hiểu' : 'Got it'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPolicyRow({required IconData icon, required String title, required String content}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF28B79B), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1E293B), fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.5, fontFamily: 'Outfit'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildKpiCards(bool isVi) {
    final available = _summaryData?['availableBalance'] ?? 0;
    final pendingHold = _summaryData?['pendingHoldBalance'] ?? 0;
    final totalPaid = _summaryData?['totalPaid'] ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 32) / 3;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            _buildKpiCard(
              title: isVi ? 'Số dư khả dụng (Sẵn sàng chốt)' : 'Available Balance',
              amount: _formatVND(available),
              subtitle: isVi ? 'Đã qua 7 ngày bảo hành' : 'Passed 7-day warranty hold',
              icon: Icons.account_balance_wallet_outlined,
              iconColor: const Color(0xFF10B981),
              bgColor: const Color(0xFFECFDF5),
              borderColor: const Color(0xFFA7F3D0),
              width: cardWidth < 280 ? constraints.maxWidth : cardWidth,
            ),
            _buildKpiCard(
              title: isVi ? 'Tạm tính (Bảo lưu 7 ngày)' : '7-Day Pending Hold',
              amount: _formatVND(pendingHold),
              subtitle: isVi ? 'Chờ hết hạn đổi trả học phí' : 'Holding for money-back policy',
              icon: Icons.hourglass_top_rounded,
              iconColor: const Color(0xFFF59E0B),
              bgColor: const Color(0xFFFFFBEB),
              borderColor: const Color(0xFFFDE68A),
              width: cardWidth < 280 ? constraints.maxWidth : cardWidth,
            ),
            _buildKpiCard(
              title: isVi ? 'Tổng tiền đã nhận (Net Paid)' : 'Total Net Paid',
              amount: _formatVND(totalPaid),
              subtitle: isVi ? 'Đã chuyển vào tài khoản ngân hàng' : 'Transferred to bank account',
              icon: Icons.check_circle_outline_rounded,
              iconColor: const Color(0xFF28B79B),
              bgColor: const Color(0xFFF0FDF4),
              borderColor: const Color(0xFFBBF7D0),
              width: cardWidth < 280 ? constraints.maxWidth : cardWidth,
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String amount,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required double width,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                  fontFamily: 'Outfit',
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            amount,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatementsTable(bool isVi) {
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
                isVi ? 'Báo cáo Quyết toán Hàng tháng' : 'Monthly Settlement Statements',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                onPressed: _fetchRevenueData,
                tooltip: isVi ? 'Làm mới' : 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_statements.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  Text(
                    isVi ? 'Chưa có báo cáo quyết toán nào.' : 'No monthly statements generated yet.',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                  ),
                ],
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: DataTable(
                      headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                      horizontalMargin: 20,
                      columnSpacing: 28,
                      columns: [
                        DataColumn(label: Text(isVi ? 'Mã Báo cáo' : 'Statement Code', style: _headerStyle)),
                        DataColumn(label: Text(isVi ? 'Kỳ Tháng' : 'Period', style: _headerStyle)),
                        DataColumn(label: Text(isVi ? 'Số đơn' : 'Orders', style: _headerStyle)),
                        DataColumn(label: Text(isVi ? 'Tổng bán' : 'Gross Amount', style: _headerStyle)),
                        DataColumn(label: Text(isVi ? 'Thực nhận (Net)' : 'Net Payout', style: _headerStyle)),
                      ],
                      rows: _statements.map((s) {
                        final net = s['netPayoutAmount'] ?? 0;
                        final gross = s['totalGrossAmount'] ?? 0;

                        return DataRow(
                          cells: [
                            DataCell(
                              InkWell(
                                onTap: () => _showStatementDetailDialog(s as Map<String, dynamic>),
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        s['statementCode']?.toString() ?? 'N/A',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2563EB),
                                          decoration: TextDecoration.underline,
                                          fontFamily: 'Outfit',
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(Icons.open_in_new_rounded, size: 13, color: Color(0xFF2563EB)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(s['periodMonth']?.toString() ?? 'N/A')),
                            DataCell(Text('${s['totalOrders'] ?? 0}')),
                            DataCell(Text(_formatVND(gross))),
                            DataCell(Text(_formatVND(net), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF28B79B)))),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  TextStyle get _headerStyle => const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 13,
        color: Color(0xFF475569),
        fontFamily: 'Outfit',
      );



  void _showStatementDetailDialog(Map<String, dynamic> statement) {
    final isVi = LanguageManager.isVi;
    final statementId = (statement['id'] ?? 0) as int;
    final code = statement['statementCode']?.toString() ?? 'N/A';
    final trainerName = statement['trainerName'] ?? _trainerName;
    final trainerType = _summaryData?['trainerType'] ?? statement['trainerType'] ?? 'PROFESSIONAL';
    final period = statement['periodMonth'] ?? 'N/A';
    final gross = statement['totalGrossAmount'] ?? 0;
    final pFee = statement['totalPlatformFee'] ?? 0;
    final net = statement['netPayoutAmount'] ?? 0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          contentPadding: const EdgeInsets.all(24),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'Chi tiết Bảng kê ($code)' : 'Statement Breakdown ($code)',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit'),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: Container(
            width: 800,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
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
                          Text(trainerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                            isVi
                                ? 'Kỳ tháng: $period | Loại: ${trainerType == 'PEER_TUTOR' ? 'Gia sư (60/40)' : 'Giáo viên (70/30)'}'
                                : 'Period: $period | Type: ${trainerType == 'PEER_TUTOR' ? 'Tutor (60/40)' : 'Teacher (70/30)'}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
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
                          isVi ? 'Bảng Tính Doanh thu & Khấu trừ' : 'Revenue Calculation Breakdown',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                        ),
                        const SizedBox(height: 12),
                        _buildDialogRow(isVi ? 'Tổng doanh thu gộp (Gross Sales):' : 'Total Gross Sales:', _formatVND(gross)),
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
                              isVi ? '(=) Thu nhập thực nhận (Net Payout):' : '(=) Final Net Payout Amount:',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A)),
                            ),
                            Text(
                              _formatVND(net),
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF28B79B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isVi ? 'Tổng quan Số liệu Tính toán theo Khóa học' : 'Course Revenue Calculation Breakdown',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 10),
                  // Calculated Course Metrics Summary Table
                  FutureBuilder<List<dynamic>>(
                    future: _revenueService.getStatementPayments(statementId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator(color: Color(0xFF28B79B))),
                        );
                      }
                      final items = snapshot.data ?? [];
                      if (items.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          alignment: Alignment.center,
                          child: Text(
                            isVi ? 'Không có dữ liệu khóa học trong kỳ.' : 'No course breakdown data found.',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        );
                      }

                      // Aggregate orders by Course Title
                      Map<String, Map<String, dynamic>> courseMetrics = {};
                      for (var item in items) {
                        String cTitle = item['courseTitle']?.toString() ?? (isVi ? 'Khóa học chưa đặt tên' : 'Untitled Course');
                        double amt = (item['amount'] as num?)?.toDouble() ?? 0.0;
                        double platformFee = (item['platformFee'] as num?)?.toDouble() ?? (amt * (trainerType == 'PEER_TUTOR' ? 0.40 : 0.30));
                        double trainerEarn = (item['trainerEarnings'] as num?)?.toDouble() ?? (amt - platformFee);

                        if (!courseMetrics.containsKey(cTitle)) {
                          courseMetrics[cTitle] = {
                            'title': cTitle,
                            'orderCount': 0,
                            'gross': 0.0,
                            'pFee': 0.0,
                            'tEarn': 0.0,
                          };
                        }
                        courseMetrics[cTitle]!['orderCount'] = (courseMetrics[cTitle]!['orderCount'] as int) + 1;
                        courseMetrics[cTitle]!['gross'] = (courseMetrics[cTitle]!['gross'] as double) + amt;
                        courseMetrics[cTitle]!['pFee'] = (courseMetrics[cTitle]!['pFee'] as double) + platformFee;
                        courseMetrics[cTitle]!['tEarn'] = (courseMetrics[cTitle]!['tEarn'] as double) + trainerEarn;
                      }

                      final courseList = courseMetrics.values.toList();
                      int totalOrders = courseList.fold<int>(0, (sum, c) => sum + (c['orderCount'] as int));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Summary metrics box
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Column(
                                  children: [
                                    Text(isVi ? 'Số khóa học bán ra' : 'Courses Sold', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text('${courseList.length}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  ],
                                ),
                                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                                Column(
                                  children: [
                                    Text(isVi ? 'Tổng lượt đăng ký' : 'Total Enrollments', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text('$totalOrders', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                                  ],
                                ),
                                Container(width: 1, height: 28, color: const Color(0xFFCBD5E1)),
                                Column(
                                  children: [
                                    Text(isVi ? 'Giá trị đơn TB' : 'Avg Order Value', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                                    const SizedBox(height: 2),
                                    Text(
                                      _formatVND(totalOrders > 0 ? (gross / totalOrders) : 0),
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
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
                              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                              columns: [
                                DataColumn(label: Text(isVi ? 'Khóa học' : 'Course Title', style: _headerStyle)),
                                DataColumn(label: Text(isVi ? 'Số đơn' : 'Orders', style: _headerStyle)),
                                DataColumn(label: Text(isVi ? 'Doanh thu Gộp' : 'Gross Sales', style: _headerStyle)),
                                DataColumn(label: Text(isVi ? 'Phí Sàn' : 'Platform Fee', style: _headerStyle)),
                                DataColumn(label: Text(isVi ? 'Thu nhập GV' : 'Trainer Earnings', style: _headerStyle)),
                              ],
                              rows: courseList.map((c) {
                                return DataRow(cells: [
                                  DataCell(Text(c['title'].toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  DataCell(Text('${c['orderCount']}', style: const TextStyle(fontSize: 12))),
                                  DataCell(Text(_formatVND(c['gross']), style: const TextStyle(fontSize: 12))),
                                  DataCell(Text('- ${_formatVND(c['pFee'])}', style: const TextStyle(fontSize: 12, color: Color(0xFFDC2626)))),
                                  DataCell(Text(_formatVND(c['tEarn']), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF28B79B)))),
                                ]);
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
              child: Text(isVi ? 'Đóng' : 'Close', style: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold)),
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
        Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontSize: 13)),
      ],
    );
  }
}
