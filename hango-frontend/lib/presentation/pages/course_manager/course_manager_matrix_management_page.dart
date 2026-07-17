import 'package:flutter/material.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../utils/toast_helper.dart';
import 'course_manager_matrix_builder_page.dart';
import 'course_manager_dashboard_page.dart';

class CourseManagerMatrixManagementPage extends StatefulWidget {
  final VoidCallback? onBack;

  const CourseManagerMatrixManagementPage({super.key, this.onBack});

  @override
  State<CourseManagerMatrixManagementPage> createState() => _CourseManagerMatrixManagementPageState();
}

class _CourseManagerMatrixManagementPageState extends State<CourseManagerMatrixManagementPage> {
  final _api = CourseManagerApi();
  List<Map<String, dynamic>> _matrices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMatrices();
  }

  Future<void> _fetchMatrices() async {
    try {
      final data = await _api.getExamMatrices();
      if (mounted) {
        setState(() {
          _matrices = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.showError(context, 'Lỗi tải danh sách ma trận: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF20B486)),
                    )
                  : _matrices.isEmpty
                      ? _buildEmptyState()
                      : _buildMatrixList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF4B5563)),
          onPressed: widget.onBack ??
              () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const CourseManagerDashboardPage()),
                );
              },
        ),
        const SizedBox(width: 16),
        const Text(
          'Quản lý Ma trận đề (Course Manager)',
          style: TextStyle(
            fontFamily: 'Outfit',
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        const Spacer(),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CourseManagerMatrixBuilderPage(
                  api: _api,
                  onSaved: () => _fetchMatrices(),
                ),
              ),
            );
          },
          icon: const Icon(Icons.add, color: Colors.white, size: 20),
          label: const Text(
            'Tạo Ma trận mới',
            style: TextStyle(
              fontFamily: 'Outfit',
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF20B486),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              color: Color(0xFFE6FFFA),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.grid_on_outlined, size: 48, color: Color(0xFF20B486)),
          ),
          const SizedBox(height: 24),
          const Text(
            'Chưa có ma trận nào',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Bạn chưa tạo ma trận đề thi nào.\nHãy tạo mới để bắt đầu.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrixList() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 400,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        mainAxisExtent: 160,
      ),
      itemCount: _matrices.length,
      itemBuilder: (context, index) {
        final matrix = _matrices[index];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.02),
                blurRadius: 10,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      matrix['title'] ?? 'Untitled',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'ID: ${matrix['id']}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontFamily: 'Outfit',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Text(
                  matrix['description'] ?? 'Không có mô tả',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Divider(color: Color(0xFFE2E8F0)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      // TODO: View details or edit
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF20B486),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                    ),
                    child: const Text('Xem chi tiết'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
