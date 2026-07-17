import 'package:flutter/material.dart';
import '../../../data/services/course_manager_api.dart';
import '../../../utils/toast_helper.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/course_manager_sidebar.dart';
import 'course_manager_matrix_builder_page.dart';


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
  bool _isSidebarVisible = true;

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
        ToastHelper.showError(context, 'Failed to load matrices: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(
        isDesktop: isDesktop,
        activeTab: '',
        hideNavLinks: true,
        hideCommerceActions: true,
        hideLanguageSwitcher: true,
      ),
      drawer: !isDesktop ? const Drawer(child: CourseManagerSidebar(currentRoute: 'matrix')) : null,
      body: Row(
        children: [
          if (isDesktop && _isSidebarVisible)
            const SizedBox(width: 240, child: CourseManagerSidebar(currentRoute: 'matrix')),
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
                        if (_isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(40.0),
                              child: CircularProgressIndicator(color: Color(0xFF20B486)),
                            ),
                          )
                        else if (_matrices.isEmpty)
                          _buildEmptyState()
                        else
                          _buildMatrixTable(),
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
          const Text(
            'Exam Matrix',
            style: TextStyle(
              color: Color(0xFF20B486),
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right, size: 16, color: Color(0xFF20B486)),
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
              'Create New Matrix',
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
      ),
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
            'No exam matrices yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You haven\'t created any exam matrices.\nCreate a new one to get started.',
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

  Widget _buildMatrixTable() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
        dataRowMaxHeight: 64,
        dataRowMinHeight: 64,
        columns: const [
          DataColumn(
              label: Text('Matrix Name',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'Outfit'))),
          DataColumn(
              label: Text('Created Date',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'Outfit'))),
          DataColumn(
              label: Text('Status',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'Outfit'))),
          DataColumn(
              label: Text('Actions',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF64748B), fontFamily: 'Outfit'))),
        ],
        rows: _matrices.map((matrix) {
          // Dummy logic for status
          bool isPublic = (matrix['status'] ?? 'public').toString().toLowerCase() == 'public';

          return DataRow(
            cells: [
              DataCell(
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      matrix['title'] ?? 'Untitled',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                    ),
                    Text(
                      'ID: ${matrix['id']}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                    ),
                  ],
                ),
              ),
              DataCell(
                Text(
                  '20/07/2026', // TODO: Format actual date if available
                  style: const TextStyle(color: Color(0xFF4B5563), fontFamily: 'Outfit'),
                ),
              ),
              DataCell(
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isPublic ? const Color(0xFFDEF7EC) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isPublic ? 'Public' : 'Private',
                    style: TextStyle(
                      color: isPublic ? const Color(0xFF03543F) : const Color(0xFF475569),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
              DataCell(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.visibility_outlined, color: Color(0xFF64748B)),
                      tooltip: 'View',
                      onPressed: () {
                        // TODO: View
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Color(0xFF20B486)),
                      tooltip: 'Edit',
                      onPressed: () {
                        // TODO: Edit
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
