import 'package:flutter/material.dart';
import '../../../data/services/revenue_settlement_service.dart';
import '../../../utils/language_manager.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/course_manager_sidebar.dart';
import '../../widgets/shared_header.dart';
import 'course_manager_dashboard_page.dart';

class CourseManagerSettlementPage extends StatefulWidget {
  const CourseManagerSettlementPage({super.key});

  @override
  State<CourseManagerSettlementPage> createState() => _CourseManagerSettlementPageState();
}

class _CourseManagerSettlementPageState extends State<CourseManagerSettlementPage> {
  final _revenueService = RevenueSettlementService();
  bool _isLoading = true;
  bool _isSidebarVisible = true;
  List<dynamic> _statements = [];

  String _periodMonthFilter = '';
  String _statusFilter = '';

  @override
  void initState() {
    super.initState();
    _fetchStatements();
  }

  Future<void> _fetchStatements() async {
    setState(() => _isLoading = true);
    final data = await _revenueService.getCourseManagerStatements(
      periodMonth: _periodMonthFilter,
      status: _statusFilter,
    );
    if (mounted) {
      setState(() {
        _statements = data;
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerCutoff() async {
    final isVi = LanguageManager.isVi;
    setState(() => _isLoading = true);
    final generated = await _revenueService.generateMonthlyCutoff(periodMonth: _periodMonthFilter);
    if (mounted) {
      setState(() => _isLoading = false);
      if (generated.isNotEmpty) {
        ToastHelper.showSuccess(
          context,
          isVi
              ? 'Đã tạo kỳ quyết toán mới cho ${generated.length} giáo viên!'
              : 'Generated monthly cutoff statements for ${generated.length} trainers!',
        );
        _fetchStatements();
      } else {
        ToastHelper.show(
          context,
          isVi ? 'Không có đơn hàng mới nào cần chốt kỳ.' : 'No pending orders found for cutoff.',
        );
        _fetchStatements();
      }
    }
  }

  void _showSettleDialog(Map<String, dynamic> statement) {
    final isVi = LanguageManager.isVi;
    final bankRefController = TextEditingController();
    final notesController = TextEditingController();
    final statementId = (statement['id'] ?? 0) as int;
    final trainerName = statement['trainerName'] ?? 'N/A';
    final netAmount = statement['netPayoutAmount'] ?? 0;
    final bankName = statement['bankName'] ?? 'N/A';
    final bankAccount = statement['bankAccount'] ?? 'N/A';
    final bankAccountName = statement['bankAccountName'] ?? 'N/A';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isVi ? 'Xác nhận Đã chuyển khoản' : 'Mark as Paid / Record Transfer',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit'),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDialogRow(isVi ? 'Giáo viên thụ hưởng:' : 'Beneficiary Trainer:', trainerName),
                        const SizedBox(height: 8),
                        _buildDialogRow(isVi ? 'Ngân hàng:' : 'Bank Name:', bankName),
                        const SizedBox(height: 8),
                        _buildDialogRow(isVi ? 'Số tài khoản:' : 'Account Number:', bankAccount),
                        const SizedBox(height: 8),
                        _buildDialogRow(isVi ? 'Tên chủ tài khoản:' : 'Account Owner:', bankAccountName),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isVi ? 'Số tiền thực chuyển:' : 'Net Payout Amount:',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                            ),
                            Text(
                              _formatVND(netAmount),
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF28B79B)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isVi ? 'Mã giao dịch Ngân hàng (Bank Ref No) *' : 'Bank Transaction Reference *',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: bankRefController,
                    decoration: InputDecoration(
                      hintText: isVi ? 'Ví dụ: FT26078129381' : 'Example: FT26078129381',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: Color(0xFF28B79B), width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isVi ? 'Ghi chú / Admin Notes' : 'Admin Notes',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: notesController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: isVi ? 'Ghi chú bổ sung (không bắt buộc)...' : 'Optional notes...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isVi ? 'Hủy' : 'Cancel', style: const TextStyle(color: Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () async {
                final ref = bankRefController.text.trim();
                if (ref.isEmpty) {
                  ToastHelper.showError(context, isVi ? 'Vui lòng nhập Mã giao dịch Ngân hàng.' : 'Please enter Bank Transaction Reference.');
                  return;
                }
                Navigator.pop(context);
                setState(() => _isLoading = true);
                final success = await _revenueService.settleStatement(
                  statementId,
                  bankTxnRef: ref,
                  notes: notesController.text.trim(),
                );
                if (mounted) {
                  setState(() => _isLoading = false);
                  if (success) {
                    ToastHelper.showSuccess(
                      context,
                      isVi ? 'Đã ghi nhận thanh toán thành công!' : 'Statement marked as PAID successfully!',
                    );
                    _fetchStatements();
                  } else {
                    ToastHelper.showError(
                      context,
                      isVi ? 'Có lỗi xảy ra khi ghi nhận.' : 'Failed to update statement.',
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              child: Text(isVi ? 'Xác nhận Đã thanh toán' : 'Confirm Paid', style: const TextStyle(fontWeight: FontWeight.bold)),
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(
        isDesktop: isDesktop,
        activeTab: '',
        hideNavLinks: true,
        hideCommerceActions: true,
        hideLanguageSwitcher: true,
      ),
      drawer: !isDesktop ? const Drawer(child: CourseManagerSidebar(currentRoute: 'settlement')) : null,
      body: Row(
        children: [
          if (isDesktop && _isSidebarVisible)
            const SizedBox(width: 240, child: CourseManagerSidebar(currentRoute: 'settlement')),
          Expanded(
            child: Column(
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
                        const SizedBox(height: 24),
                        _buildMainContent(isVi),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
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
          ] else ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF4B5563)),
              onPressed: () {
                setState(() {
                  _isSidebarVisible = !_isSidebarVisible;
                });
              },
            ),
            const SizedBox(width: 12),
          ],
          InkWell(
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const CourseManagerDashboardPage()),
              );
            },
            child: const Text(
              'Dashboard',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
          const SizedBox(width: 4),
          const Text(
            'Revenue Settlement',
            style: TextStyle(
              color: Color(0xFF20B486),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
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
              isVi ? 'Quản lý Quyết toán & Doanh thu' : 'Revenue Settlement Management',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isVi ? 'Đối soát doanh thu, chốt kỳ tháng và xác nhận giải ngân cho Giáo viên.' : 'Reconcile revenue, run monthly cutoffs, and record manual bank payouts.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _triggerCutoff,
          icon: const Icon(Icons.calculate_outlined, size: 18),
          label: Text(
            isVi ? 'Chốt Kỳ Quyết Toán Mới' : 'Trigger Monthly Cutoff',
            style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF28B79B),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(bool isVi) {
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
                isVi ? 'Danh sách Báo cáo Quyết toán' : 'Settlement Statements List',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                onPressed: _fetchStatements,
                tooltip: isVi ? 'Làm mới' : 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF28B79B))),
            )
          else if (_statements.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.receipt_long_outlined, size: 48, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  Text(
                    isVi ? 'Chưa có dữ liệu quyết toán.' : 'No settlement statements available.',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                  ),
                ],
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: [
                  DataColumn(label: Text(isVi ? 'Mã Báo cáo' : 'Statement Code', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Giáo viên' : 'Trainer Name', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Loại' : 'Type', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Kỳ Tháng' : 'Period', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Tổng Gross' : 'Gross', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Thuế 10%' : 'Tax 10%', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Thực nhận (Net)' : 'Net Payout', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Tài khoản Ngân hàng' : 'Bank Account', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Trạng thái' : 'Status', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Thao tác' : 'Action', style: _headerStyle)),
                ],
                rows: _statements.map((s) {
                  final status = s['status']?.toString() ?? 'PENDING_TRAINER_CONFIRM';
                  final net = s['netPayoutAmount'] ?? 0;
                  final gross = s['totalGrossAmount'] ?? 0;
                  final tax = s['pitTaxAmount'] ?? 0;
                  final trainerName = s['trainerName'] ?? 'N/A';
                  final trainerType = s['trainerType'] ?? 'PROFESSIONAL';
                  final bankName = s['bankName'] ?? '';
                  final bankAcc = s['bankAccount'] ?? '';
                  final bankAccName = s['bankAccountName'] ?? '';

                  return DataRow(
                    cells: [
                      DataCell(Text(s['statementCode']?.toString() ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(trainerName, style: const TextStyle(fontWeight: FontWeight.w600))),
                      DataCell(Text(trainerType == 'PEER_TUTOR' ? 'Peer Tutor' : 'Professional')),
                      DataCell(Text(s['periodMonth']?.toString() ?? 'N/A')),
                      DataCell(Text(_formatVND(gross))),
                      DataCell(Text(_formatVND(tax), style: const TextStyle(color: Colors.redAccent))),
                      DataCell(Text(_formatVND(net), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF28B79B)))),
                      DataCell(Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$bankName - $bankAcc', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Text(bankAccName, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                        ],
                      )),
                      DataCell(_buildStatusBadge(status, isVi)),
                      DataCell(
                        status == 'PAID'
                            ? Text(s['bankTxnRef'] ?? 'PAID', style: const TextStyle(fontSize: 12, color: Color(0xFF16A34A), fontWeight: FontWeight.bold))
                            : ElevatedButton.icon(
                                onPressed: () => _showSettleDialog(s as Map<String, dynamic>),
                                icon: const Icon(Icons.check_circle_outline, size: 14),
                                label: Text(isVi ? 'Xác nhận Đã trả' : 'Mark Paid', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF28B79B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                              ),
                      ),
                    ],
                  );
                }).toList(),
              ),
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
      text = isVi ? 'Chờ GV xác nhận' : 'Pending Confirm';
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFFD97706);
    } else if (status == 'TRAINER_CONFIRMED') {
      text = isVi ? 'GV Đã xác nhận' : 'Trainer Confirmed';
      bg = const Color(0xFFE0F2FE);
      fg = const Color(0xFF0369A1);
    } else if (status == 'PAID') {
      text = isVi ? 'Đã thanh toán' : 'Paid';
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF15803D);
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
}
