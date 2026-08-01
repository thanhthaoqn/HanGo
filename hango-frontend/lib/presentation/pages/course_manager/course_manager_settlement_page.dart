import 'package:flutter/material.dart';
import '../../../data/services/revenue_settlement_service.dart';
import '../../../utils/download_helper.dart';
import '../../../utils/language_manager.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/course_manager_sidebar.dart';
import '../../widgets/shared_header.dart';

class CourseManagerSettlementPage extends StatefulWidget {
  const CourseManagerSettlementPage({super.key});

  @override
  State<CourseManagerSettlementPage> createState() => _CourseManagerSettlementPageState();
}

class _CourseManagerSettlementPageState extends State<CourseManagerSettlementPage>
    with SingleTickerProviderStateMixin {
  final _revenueService = RevenueSettlementService();

  late TabController _tabController;

  // --- Tab 1: Statements State ---
  bool _isLoading = true;
  List<dynamic> _statements = [];
  String _periodMonthFilter = '';
  String _statusFilter = '';

  // --- Tab 2: Payments Log State ---
  bool _isPaymentsLoading = false;
  List<dynamic> _payments = [];
  int _paymentsPage = 0;
  int _paymentsTotalPages = 1;
  int _paymentsTotalElements = 0;
  final int _paymentsPageSize = 15;
  String _paymentStatusFilter = 'ALL';
  String _paymentSettlementStatusFilter = 'ALL';
  final TextEditingController _paymentSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchStatements();
    _fetchPayments();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _paymentSearchController.dispose();
    super.dispose();
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
        _fetchPayments();
      } else {
        ToastHelper.show(
          context,
          isVi ? 'Không có đơn hàng mới nào cần chốt kỳ.' : 'No pending orders found for cutoff.',
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
      status: _statusFilter,
    );
    if (mounted) {
      setState(() => _isLoading = false);
      if (bytes != null && bytes.isNotEmpty) {
        downloadBytes(
          bytes: bytes,
          filename: 'HanGo_Revenue_Statements_${_periodMonthFilter.isNotEmpty ? _periodMonthFilter : "All"}.xlsx',
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        ToastHelper.showSuccess(
          context,
          isVi ? 'Đã tải xuống file Excel Bảng kê thành công!' : 'Statements Excel downloaded successfully!',
        );
      } else {
        ToastHelper.showError(
          context,
          isVi ? 'Không thể tải xuống file Excel Bảng kê.' : 'Failed to download Statements Excel file.',
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
          mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        );
        ToastHelper.showSuccess(
          context,
          isVi ? 'Đã tải xuống file Excel Giao dịch thành công!' : 'Transactions Excel downloaded successfully!',
        );
      } else {
        ToastHelper.showError(
          context,
          isVi ? 'Không thể tải xuống file Excel Giao dịch.' : 'Failed to download Transactions Excel file.',
        );
      }
    }
  }

  void _showSettleDialog(Map<String, dynamic> statement) {
    final isVi = LanguageManager.isVi;
    final bankRefController = TextEditingController();
    final notesController = TextEditingController();
    final receiptUrlController = TextEditingController();
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
                    isVi ? 'Link Bằng chứng chuyển khoản / Bill URL' : 'Payout Receipt Proof Image URL',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: receiptUrlController,
                    decoration: InputDecoration(
                      hintText: isVi ? 'https://example.com/receipt.jpg (Tùy chọn)' : 'https://example.com/receipt.jpg (Optional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                  payoutReceiptUrl: receiptUrlController.text.trim(),
                );
                if (mounted) {
                  setState(() => _isLoading = false);
                  if (success) {
                    ToastHelper.showSuccess(
                      context,
                      isVi ? 'Đã ghi nhận thanh toán thành công!' : 'Statement marked as PAID successfully!',
                    );
                    _fetchStatements();
                    _fetchPayments();
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
    final tGross = statement['totalTrainerGross'] ?? 0;
    final tax = statement['pitTaxAmount'] ?? 0;
    final net = statement['netPayoutAmount'] ?? 0;
    final bankName = statement['bankName'] ?? 'N/A';
    final bankAccount = statement['bankAccount'] ?? 'N/A';
    final bankAccountName = statement['bankAccountName'] ?? 'N/A';
    final status = statement['status']?.toString() ?? 'PENDING_TRAINER_CONFIRM';
    final bankTxnRef = statement['bankTxnRef'];
    final notes = statement['adminNotes'];
    final receiptUrl = statement['payoutReceiptUrl']?.toString();

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
              Row(
                children: [
                  const Icon(Icons.receipt_long, color: Color(0xFF28B79B)),
                  const SizedBox(width: 8),
                  Text(
                    isVi ? 'Chi tiết Bảng kê $code' : 'Statement Breakdown ($code)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit'),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          content: Container(
            width: 850,
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
                          Text('$trainerName ($trainerEmail)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(
                            isVi
                                ? 'Kỳ tháng: $period | Loại: ${trainerType == 'PEER_TUTOR' ? 'Peer Tutor (60/40)' : 'Professional (70/30)'}'
                                : 'Period: $period | Type: ${trainerType == 'PEER_TUTOR' ? 'Peer Tutor (60/40)' : 'Professional (70/30)'}',
                            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                          ),
                        ],
                      ),
                      _buildStatusBadge(status, isVi),
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
                          isVi ? '🧮 Bảng Tính Doanh thu & Khấu trừ' : '🧮 Revenue Calculation Breakdown',
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
                        const Divider(height: 16),
                        _buildDialogRow(isVi ? '(=) Thu nhập trước thuế (Trainer Gross):' : '(=) Trainer Gross Earnings:', _formatVND(tGross)),
                        const SizedBox(height: 8),
                        _buildDialogRow(isVi ? '(-) Thuế TNCN 10% (PIT Tax):' : '(-) Personal Income Tax (PIT 10%):', '- ${_formatVND(tax)}'),
                        const Divider(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isVi ? '(=) Số tiền thực nhận (Net Payout):' : '(=) Final Net Payout Amount:',
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
                  const SizedBox(height: 16),
                  // Bank Details & Transfer Receipt Proof
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isVi ? '🏦 Thông tin Chuyển khoản Ngân hàng' : '🏦 Bank Payout & Transfer Receipt Proof',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(isVi ? 'Tài khoản:' : 'Account:', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                            Text('$bankName - $bankAccount ($bankAccountName)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                        if (bankTxnRef != null && bankTxnRef.toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(isVi ? 'Mã GD Ngân hàng:' : 'Bank Txn Ref:', style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
                              Text(bankTxnRef.toString(), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A), fontSize: 13)),
                            ],
                          ),
                        ],
                        if (receiptUrl != null && receiptUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(Icons.receipt, size: 16, color: Color(0xFF2563EB)),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () => _openImagePreview(receiptUrl),
                                child: Text(
                                  isVi ? '📸 Xem Ảnh Bằng chứng chuyển khoản (Bill đính kèm)' : '📸 View Transfer Receipt Proof Attachment',
                                  style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold, decoration: TextDecoration.underline, fontSize: 13),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (notes != null && notes.toString().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(isVi ? 'Ghi chú: $notes' : 'Notes: $notes', style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Color(0xFF475569))),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isVi ? '🛒 Danh sách Đơn hàng trong kỳ quyết toán này' : '🛒 Itemized Orders included in this statement',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 10),
                  // Itemized Orders Table
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
                            isVi ? 'Không có chi tiết đơn hàng.' : 'No itemized orders found.',
                            style: const TextStyle(color: Color(0xFF64748B)),
                          ),
                        );
                      }
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 40,
                          dataRowHeight: 44,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                          columns: [
                            DataColumn(label: Text(isVi ? 'Mã GD' : 'Txn Ref', style: _headerStyle)),
                            DataColumn(label: Text(isVi ? 'Học viên' : 'Learner', style: _headerStyle)),
                            DataColumn(label: Text(isVi ? 'Khóa học' : 'Course Title', style: _headerStyle)),
                            DataColumn(label: Text(isVi ? 'Số tiền' : 'Amount', style: _headerStyle)),
                          ],
                          rows: items.map((p) {
                            return DataRow(cells: [
                              DataCell(Text(p['txnRef']?.toString() ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                              DataCell(Text(p['userName']?.toString() ?? 'N/A', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(p['courseTitle']?.toString() ?? 'N/A', style: const TextStyle(fontSize: 12))),
                              DataCell(Text(_formatVND(p['amount'] ?? 0), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF28B79B)))),
                            ]);
                          }).toList(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            if (status != 'PAID')
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _showSettleDialog(statement);
                },
                icon: const Icon(Icons.check_circle_outline, size: 16),
                label: Text(isVi ? 'Xác nhận Đã trả' : 'Mark as Paid', style: const TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28B79B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isVi ? 'Đóng' : 'Close', style: const TextStyle(color: Color(0xFF64748B))),
            ),
          ],
        );
      },
    );
  }

  void _openImagePreview(String url) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          padding: const EdgeInsets.all(16),
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Transfer Receipt Proof', style: TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: Image.network(
                  url,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Could not load image from URL', style: TextStyle(color: Colors.red)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
          if (isDesktop)
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
                        const SizedBox(height: 20),
                        _buildTabBar(isVi),
                        const SizedBox(height: 20),
                        IndexedStack(
                          index: _tabController.index,
                          children: [
                            _buildStatementsTab(isVi),
                            _buildPaymentsTab(isVi),
                          ],
                        ),
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
              isVi ? 'Đối soát doanh thu, chốt kỳ tháng, quản lý giao dịch và giải ngân.' : 'Reconcile revenue, run monthly cutoffs, manage transactions and payouts.',
              style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
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
        labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit', fontSize: 15),
        tabs: [
          Tab(
            iconMargin: const EdgeInsets.only(bottom: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.receipt_long, size: 18),
                const SizedBox(width: 8),
                Text(isVi ? 'Bảng kê quyết toán hàng tháng' : 'Monthly Statements'),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.list_alt, size: 18),
                const SizedBox(width: 8),
                Text(isVi ? 'Danh sách tất cả giao dịch lẻ' : 'All Payment Transactions'),
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
                isVi ? 'Danh sách Báo cáo Quyết toán' : 'Settlement Statements List',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _exportStatementsExcel,
                    icon: const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF16A34A)),
                    label: Text(
                      isVi ? 'Xuất Excel Bảng kê' : 'Export Statements Excel',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A), fontFamily: 'Outfit'),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF16A34A)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                    onPressed: _fetchStatements,
                    tooltip: isVi ? 'Làm mới' : 'Refresh',
                  ),
                ],
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
                      DataCell(
                        InkWell(
                          onTap: () => _showStatementDetailDialog(s as Map<String, dynamic>),
                          child: Text(
                            s['statementCode']?.toString() ?? 'N/A',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB), decoration: TextDecoration.underline),
                          ),
                        ),
                      ),
                      DataCell(
                        InkWell(
                          onTap: () => _showStatementDetailDialog(s as Map<String, dynamic>),
                          child: Text(
                            trainerName,
                            style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                          ),
                        ),
                      ),
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
                isVi ? 'Danh sách Tất cả Giao dịch Thanh toán' : 'All Payment Transactions Log',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
              ),
              OutlinedButton.icon(
                onPressed: _exportPaymentsExcel,
                icon: const Icon(Icons.file_download_outlined, size: 18, color: Color(0xFF16A34A)),
                label: Text(
                  isVi ? 'Xuất Excel Giao dịch' : 'Export Transactions Excel',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF16A34A), fontFamily: 'Outfit'),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF16A34A)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    hintText: isVi ? 'Mã GD, Learner, Khóa học, Trainer...' : 'Search Txn, Learner, Course...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
              DropdownButton<String>(
                value: _paymentStatusFilter,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(8),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _paymentStatusFilter = val;
                      _paymentsPage = 0;
                    });
                    _fetchPayments();
                  }
                },
                items: [
                  DropdownMenuItem(value: 'ALL', child: Text(isVi ? 'Tất cả trạng thái GD' : 'All Payment Statuses')),
                  DropdownMenuItem(value: 'SUCCESS', child: Text(isVi ? 'Thành công' : 'Success')),
                  DropdownMenuItem(value: 'PENDING', child: Text(isVi ? 'Đang chờ' : 'Pending')),
                  DropdownMenuItem(value: 'FAILED', child: Text(isVi ? 'Thất bại' : 'Failed')),
                  DropdownMenuItem(value: 'EXPIRED', child: Text(isVi ? 'Hết hạn' : 'Expired')),
                ],
              ),
              // Settlement Status Filter
              DropdownButton<String>(
                value: _paymentSettlementStatusFilter,
                underline: const SizedBox.shrink(),
                borderRadius: BorderRadius.circular(8),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _paymentSettlementStatusFilter = val;
                      _paymentsPage = 0;
                    });
                    _fetchPayments();
                  }
                },
                items: [
                  DropdownMenuItem(value: 'ALL', child: Text(isVi ? 'Tất cả trạng thái đối soát' : 'All Settlement Statuses')),
                  DropdownMenuItem(value: 'PENDING', child: Text(isVi ? 'Chưa chốt kỳ' : 'Pending Cutoff')),
                  DropdownMenuItem(value: 'IN_STATEMENT', child: Text(isVi ? 'Đã gom bảng kê' : 'In Statement')),
                  DropdownMenuItem(value: 'SETTLED', child: Text(isVi ? 'Đã đối soát xong' : 'Settled')),
                ],
              ),

              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Color(0xFF64748B)),
                onPressed: () {
                  setState(() => _paymentsPage = 0);
                  _fetchPayments();
                },
                tooltip: isVi ? 'Làm mới' : 'Refresh',
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isPaymentsLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: Color(0xFF28B79B))),
            )
          else if (_payments.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              alignment: Alignment.center,
              child: Column(
                children: [
                  const Icon(Icons.payment_outlined, size: 48, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 12),
                  Text(
                    isVi ? 'Không tìm thấy giao dịch nào phù hợp.' : 'No payment transactions found.',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
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
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: [
                      DataColumn(label: Text(isVi ? 'STT' : 'No', style: _headerStyle)),
                      DataColumn(label: Text(isVi ? 'Mã GD (TxnRef)' : 'Txn Reference', style: _headerStyle)),
                      DataColumn(label: Text(isVi ? 'Học viên' : 'Learner', style: _headerStyle)),
                      DataColumn(label: Text(isVi ? 'Khóa học' : 'Course Title', style: _headerStyle)),
                      DataColumn(label: Text(isVi ? 'Giáo viên' : 'Trainer', style: _headerStyle)),
                      DataColumn(label: Text(isVi ? 'Số tiền' : 'Amount', style: _headerStyle)),
                      DataColumn(label: Text(isVi ? 'Phí sàn' : 'Platform Fee', style: _headerStyle)),
                      DataColumn(label: Text(isVi ? 'Thu nhập GV' : 'Trainer Earn', style: _headerStyle)),
                      DataColumn(label: Text(isVi ? 'Trạng thái GD' : 'Payment Status', style: _headerStyle)),
                      DataColumn(label: Text(isVi ? 'Trạng thái Đối soát' : 'Settlement', style: _headerStyle)),
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
                      final sStatus = p['settlementStatus']?.toString() ?? 'PENDING';

                      return DataRow(
                        cells: [
                          DataCell(Text('${_paymentsPage * _paymentsPageSize + idx + 1}')),
                          DataCell(Text(txnRef, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                          DataCell(Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(learnerName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                              Text(learnerEmail, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                            ],
                          )),
                          DataCell(Text(courseTitle, style: const TextStyle(fontSize: 13))),
                          DataCell(Text(trainerName, style: const TextStyle(fontSize: 13))),
                          DataCell(Text(_formatVND(amount), style: const TextStyle(fontWeight: FontWeight.bold))),
                          DataCell(Text(_formatVND(pFee), style: const TextStyle(color: Color(0xFF64748B)))),
                          DataCell(Text(_formatVND(tEarn), style: const TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.w600))),
                          DataCell(_buildPaymentStatusBadge(status, isVi)),
                          DataCell(_buildSettlementStatusBadge(sStatus, isVi)),
                        ],
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                // Pagination controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isVi
                          ? 'Hiển thị ${_payments.length} / $_paymentsTotalElements giao dịch (Trang ${_paymentsPage + 1}/$_paymentsTotalPages)'
                          : 'Showing ${_payments.length} of $_paymentsTotalElements transactions (Page ${_paymentsPage + 1}/$_paymentsTotalPages)',
                      style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _paymentsPage > 0
                              ? () {
                                  setState(() => _paymentsPage--);
                                  _fetchPayments();
                                }
                              : null,
                        ),
                        Text('${_paymentsPage + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: (_paymentsPage + 1) < _paymentsTotalPages
                              ? () {
                                  setState(() => _paymentsPage++);
                                  _fetchPayments();
                                }
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg, fontFamily: 'Outfit'),
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
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: fg, fontFamily: 'Outfit'),
      ),
    );
  }
}
