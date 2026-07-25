import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../../../data/services/revenue_settlement_service.dart';
import '../../../utils/language_manager.dart';
import '../../../utils/toast_helper.dart';
import '../login_page.dart';
import 'trainer_courses_page.dart';
import 'trainer_dashboard_page.dart';
import 'trainer_exams_page.dart';
import 'trainer_profile_page.dart';
import 'question_bank/trainer_question_bank_page.dart';

import 'trainer_shell_page.dart';

class TrainerRevenuePage extends StatefulWidget {
  final bool isEmbedded;
  const TrainerRevenuePage({super.key, this.isEmbedded = false});

  @override
  State<TrainerRevenuePage> createState() => _TrainerRevenuePageState();
}

class _TrainerRevenuePageState extends State<TrainerRevenuePage> {
  final _revenueService = RevenueSettlementService();
  final _authService = AuthService();

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

  void _navigateSeamless(Widget targetPage) {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetPage,
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
      ),
    );
  }

  void _handleLogout() async {
    await _authService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
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
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 260, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              children: [
                _buildHeader(context, !isDesktop),
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
        ? (isVi ? 'Gia sư đồng học (Chia 60/40)' : 'Peer Tutor (60/40 Split)')
        : (isVi ? 'Giáo viên chuyên nghiệp (Chia 70/30)' : 'Professional Teacher (70/30 Split)');

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFE6F4F1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF28B79B).withOpacity(0.3)),
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
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: [
                  DataColumn(label: Text(isVi ? 'Mã Báo cáo' : 'Statement Code', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Kỳ Tháng' : 'Period', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Số đơn' : 'Orders', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Tổng bán' : 'Gross Amount', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Thuế TNCN (10%)' : 'PIT Tax (10%)', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Thực nhận (Net)' : 'Net Payout', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Trạng thái' : 'Status', style: _headerStyle)),
                  DataColumn(label: Text(isVi ? 'Thao tác' : 'Action', style: _headerStyle)),
                ],
                rows: _statements.map((s) {
                  final status = s['status']?.toString() ?? 'PENDING_TRAINER_CONFIRM';
                  final net = s['netPayoutAmount'] ?? 0;
                  final gross = s['totalGrossAmount'] ?? 0;
                  final tax = s['pitTaxAmount'] ?? 0;
                  final id = (s['id'] ?? 0) as int;

                  return DataRow(
                    cells: [
                      DataCell(Text(s['statementCode']?.toString() ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.bold))),
                      DataCell(Text(s['periodMonth']?.toString() ?? 'N/A')),
                      DataCell(Text('${s['totalOrders'] ?? 0}')),
                      DataCell(Text(_formatVND(gross))),
                      DataCell(Text(_formatVND(tax), style: const TextStyle(color: Colors.redAccent))),
                      DataCell(Text(_formatVND(net), style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF28B79B)))),
                      DataCell(_buildStatusBadge(status, isVi)),
                      DataCell(
                        status == 'PENDING_TRAINER_CONFIRM'
                            ? ElevatedButton(
                                onPressed: () => _confirmStatement(id),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF28B79B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                child: Text(
                                  isVi ? 'Xác nhận' : 'Confirm',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              )
                            : const Text('-', style: TextStyle(color: Color(0xFF94A3B8))),
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

  Widget _buildHeader(BuildContext context, bool showMenuButton) {
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
            backgroundImage: _trainerAvatarUrl.isNotEmpty ? NetworkImage(_trainerAvatarUrl) : null,
            child: _trainerAvatarUrl.isEmpty
                ? Text(_trainerInitials, style: const TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontSize: 14))
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.network(

                'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',

                height: 36,

                fit: BoxFit.contain,

                errorBuilder: (context, error, stackTrace) {

                  return Row(

                    children: [

                      Container(

                        padding: const EdgeInsets.all(8),

                        decoration: BoxDecoration(color: const Color(0xFF28B79B), borderRadius: BorderRadius.circular(10)),

                        child: const Icon(Icons.school, color: Colors.white, size: 24),

                      ),

                      const SizedBox(width: 12),

                      const Text(

                        'HanGo',

                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),

                      ),

                    ],

                  );

                },

              ),
            ],
          ),
          const SizedBox(height: 32),
          _buildSidebarItem(
            Icons.dashboard_outlined,
            'Dashboard',
            onTap: () => _navigateSeamless(const TrainerDashboardPage()),
          ),
          _buildSidebarItem(
            Icons.book_outlined,
            'Courses',
            onTap: () => _navigateSeamless(const TrainerCoursesPage()),
          ),
          _buildSidebarItem(
            Icons.assignment_outlined,
            'Exam',
            onTap: () => _navigateSeamless(const TrainerExamsPage()),
          ),
          _buildSidebarItem(
            Icons.question_answer_outlined,
            'Question Bank',
            onTap: () => _navigateSeamless(const TrainerQuestionBankPage()),
          ),
          _buildSidebarItem(
            Icons.account_balance_wallet_outlined,
            'Revenue',
            isActive: true,
          ),
          _buildSidebarItem(
            Icons.person_outline,
            'My Profile',
            onTap: () => _navigateSeamless(const TrainerProfilePage()),
          ),
          const Spacer(),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _buildSidebarItem(Icons.logout, 'Logout', color: Colors.redAccent, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(
    IconData icon,
    String title, {
    bool isActive = false,
    Color? color,
    VoidCallback? onTap,
  }) {
    final activeColor = const Color(0xFF28B79B);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: onTap ?? () {},
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? activeColor : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(icon, color: isActive ? Colors.white : (color ?? const Color(0xFF4B5563)), size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: isActive ? Colors.white : (color ?? const Color(0xFF1F2937)),
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
