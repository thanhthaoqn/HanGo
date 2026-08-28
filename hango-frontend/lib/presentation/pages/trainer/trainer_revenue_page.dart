import 'package:flutter/material.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/revenue_settlement_service.dart';
import '../../../utils/language_manager.dart';
import '../../../utils/toast_helper.dart';
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
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

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
    final avatarUrl = prefs.getString('user_avatar_url') ?? '';
    String initials = 'T';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    setState(() {
      _trainerName = fullName;
      _trainerInitials = initials;
      _trainerAvatarUrl = avatarUrl;
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
  void _confirmStatement(int id) async {
    final isVi = LanguageManager.isVi;
    final success = await _revenueService.confirmTrainerStatement(id);
    if (success) {
      if (mounted) {
        ToastHelper.showSuccess(
          context,
          isVi ? 'Đã xác nhận báo cáo doanh thu thành công.' : 'Revenue statement confirmed successfully.',
        );
        _fetchRevenueData();
      }
    } else {
      if (mounted) {
        ToastHelper.showError(
          context,
          isVi ? 'Không thể xác nhận báo cáo. Vui lòng thử lại.' : 'Failed to confirm statement. Please try again.',
        );
      }
    }
  }

  void _rejectStatement(int id) async {
    final isVi = LanguageManager.isVi;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isVi ? 'Từ chối Báo cáo Doanh thu' : 'Reject Revenue Statement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(isVi ? 'Vui lòng nhập lý do từ chối để Quản lý khóa học xử lý lại:' : 'Please enter a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: isVi ? 'Lý do từ chối...' : 'Rejection reason...',
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isVi ? 'Hủy' : 'Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ToastHelper.showError(context, isVi ? 'Vui lòng nhập lý do.' : 'Please enter a reason.');
                return;
              }
              Navigator.pop(context);
              final success = await _revenueService.rejectStatement(id, reason);
              if (mounted) {
                if (success) {
                  ToastHelper.showSuccess(
                    context,
                    isVi ? 'Đã phản hồi từ chối báo cáo thành công.' : 'Statement rejected successfully.',
                  );
                  _fetchRevenueData();
                } else {
                  ToastHelper.showError(
                    context,
                    isVi ? 'Không thể phản hồi từ chối. Vui lòng thử lại.' : 'Failed to reject statement.',
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(isVi ? 'Từ chối' : 'Reject'),
          ),
        ],
      ),
    );
  }

  void _openImagePreview(String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    padding: const EdgeInsets.all(20),
                    color: Colors.white,
                    child: Text(
                      LanguageManager.isVi ? 'Không thể tải ảnh bill chứng từ' : 'Cannot load receipt image',
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
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
            const SizedBox(height: 4),
            Text(
              isVi ? 'Theo dõi thu nhập, chính sách phân chia và các kỳ đối soát hàng tháng.' : 'Track your earnings, revenue split policies, and monthly settlements.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
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
                  title: isVi ? '3. Chốt sổ & Thanh toán hàng tháng' : '3. Monthly Cutoff & Settlement',
                  content: isVi
                      ? '• Quản lý đào tạo thực hiện chốt sổ báo cáo doanh thu hàng tháng.\n• Tiền được chuyển khoản thẳng vào tài khoản ngân hàng đã liên kết của Trainer.'
                      : '• Monthly statements are cut off at the end of each billing cycle.\n• Net earnings are wired directly to your registered bank account upon confirmation.',
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
                        DataColumn(label: Text(isVi ? 'Trạng thái' : 'Status', style: _headerStyle)),
                        DataColumn(label: Text(isVi ? 'Thao tác' : 'Action', style: _headerStyle)),
                      ],
                      rows: _statements.map((s) {
                        final status = s['status']?.toString() ?? 'PENDING_TRAINER_CONFIRM';
                        final net = s['netPayoutAmount'] ?? 0;
                        final gross = s['totalGrossAmount'] ?? 0;
                        final id = (s['id'] ?? 0) as int;

                        return DataRow(
                          cells: [
                            DataCell(Text(s['statementCode']?.toString() ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
                            DataCell(Text(s['periodMonth']?.toString() ?? 'N/A')),
                            DataCell(Text('${s['totalOrders'] ?? 0}')),
                            DataCell(Text(_formatVND(gross))),
                            DataCell(Text(_formatVND(net), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF28B79B)))),
                            DataCell(_buildStatusBadge(status, isVi)),
                            DataCell(
                              status == 'PENDING_TRAINER_CONFIRM'
                                  ? Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ElevatedButton(
                                          onPressed: () => _confirmStatement(id),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(0xFF28B79B),
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          child: Text(
                                            isVi ? 'Xác nhận' : 'Confirm',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        OutlinedButton(
                                          onPressed: () => _rejectStatement(id),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: Colors.redAccent,
                                            side: const BorderSide(color: Colors.redAccent),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                          child: Text(
                                            isVi ? 'Từ chối' : 'Reject',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    )
                                  : (status == 'PAID' && s['payoutReceiptUrl'] != null && s['payoutReceiptUrl'].toString().isNotEmpty)
                                      ? OutlinedButton.icon(
                                          onPressed: () => _openImagePreview(s['payoutReceiptUrl'].toString()),
                                          icon: const Icon(Icons.receipt_long, size: 14),
                                          label: Text(isVi ? 'Xem Bill chuyển tiền' : 'View Receipt', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          style: OutlinedButton.styleFrom(
                                            foregroundColor: const Color(0xFF28B79B),
                                            side: const BorderSide(color: Color(0xFF28B79B)),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          ),
                                        )
                                      : const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
                            ),
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

  Widget _buildStatusBadge(String status, bool isVi) {
    String text = status;
    Color bg = const Color(0xFFF1F5F9);
    Color fg = const Color(0xFF475569);

    if (status == 'PENDING_TRAINER_CONFIRM') {
      text = isVi ? 'Chờ xác nhận' : 'Pending Confirm';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (status == 'TRAINER_CONFIRMED') {
      text = isVi ? 'Đã xác nhận (Chờ chi)' : 'Confirmed (Awaiting Payout)';
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
    } else if (status == 'PAID') {
      text = isVi ? 'Đã thanh toán' : 'Paid';
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
    } else if (status == 'REJECTED') {
      text = isVi ? 'Đã từ chối' : 'Rejected';
      bg = const Color(0xFFFEE2E2);
      fg = const Color(0xFFB91C1C);
    } else if (status == 'CANCELLED') {
      text = isVi ? 'Đã hủy' : 'Cancelled';
      bg = const Color(0xFFF1F5F9);
      fg = const Color(0xFF64748B);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: fg, fontFamily: 'Outfit'),
      ),
    );
  }

  Widget _unusedLegacyHeader(bool showMenuButton) {
    return Container(
      color: Colors.white,
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 12),
          ],
          Row(
            children: const [
              Icon(Icons.chevron_right, size: 16, color: Color(0xFF28B79B)),
              SizedBox(width: 4),
              Text(
                'Revenue & Settlement',
                style: TextStyle(
                  color: Color(0xFF28B79B),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            _trainerName,
            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B), fontSize: 14, fontFamily: 'Outfit'),
          ),
          const SizedBox(width: 8),
          CircleAvatar(
            radius: 16,
            backgroundColor: const Color(0xFFE2F9F3),
            backgroundImage: _trainerAvatarUrl.isNotEmpty
                ? NetworkImage(_trainerAvatarUrl.contains('dicebear.com') && _trainerAvatarUrl.contains('/svg')
                    ? _trainerAvatarUrl.replaceAll('/svg', '/png')
                    : _trainerAvatarUrl)
                : null,
            onBackgroundImageError: _trainerAvatarUrl.isNotEmpty ? (exception, stackTrace) {} : null,
            child: _trainerAvatarUrl.isEmpty
                ? Text(_trainerInitials, style: const TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontSize: 14))
                : null,
          ),
        ],
      ),
    );
  }
}
