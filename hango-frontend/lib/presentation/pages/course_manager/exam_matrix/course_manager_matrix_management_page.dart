import 'package:flutter/material.dart';
import '../../../../data/services/course_manager_api.dart';
import '../../../../utils/toast_helper.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import '../../../widgets/course_manager_sidebar.dart';
import 'course_manager_matrix_builder_page.dart';

class CourseManagerMatrixManagementPage extends StatefulWidget {
  final VoidCallback? onBack;
  final bool isEmbedded;

  const CourseManagerMatrixManagementPage({super.key, this.onBack, this.isEmbedded = false});

  @override
  State<CourseManagerMatrixManagementPage> createState() =>
      _CourseManagerMatrixManagementPageState();
}

class _CourseManagerMatrixManagementPageState
    extends State<CourseManagerMatrixManagementPage> {
  final _api = CourseManagerApi();
  List<Map<String, dynamic>> _allMatrices = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStatus = 'ALL';
  String _sortBy = 'NEWEST';

  int _currentPage = 1;
  final int _itemsPerPage = 10;

  List<Map<String, dynamic>> get _displayedMatrices {
    var filtered = _allMatrices.where((m) {
      final matchesSearch = _searchQuery.isEmpty ||
          (m['title']?.toString().toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
      
      final isPublic = m['isPublic'] as bool? ?? false;
      final matchesStatus = _selectedStatus == 'ALL' ||
          (_selectedStatus == 'PUBLIC' && isPublic) ||
          (_selectedStatus == 'PRIVATE' && !isPublic);
          
      return matchesSearch && matchesStatus;
    }).toList();

    filtered.sort((a, b) {
      final dateA = _parseDate(a['createdAt']);
      final dateB = _parseDate(b['createdAt']);
      return _sortBy == 'NEWEST' ? dateB.compareTo(dateA) : dateA.compareTo(dateB);
    });

    return filtered;
  }

  @override
  void initState() {
    super.initState();
    _fetchMatrices();
  }

  Future<void> _fetchMatrices() async {
    try {
      final data = await _api.getExamMatrices();
      // ignore: avoid_print
      print('[MatrixMgmt] fetched ${data.length} matrices: $data');
      if (mounted) {
        setState(() {
          _allMatrices = data;
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('[MatrixMgmt] error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ToastHelper.showError(context, 'System error, please try again later.');
      }
    }
  }

  DateTime _parseDate(dynamic dateData) {
    if (dateData == null) return DateTime(2000);
    if (dateData is List && dateData.isNotEmpty) {
      try {
        return DateTime(
          dateData.length > 0 ? (dateData[0] as num).toInt() : 2000,
          dateData.length > 1 ? (dateData[1] as num).toInt() : 1,
          dateData.length > 2 ? (dateData[2] as num).toInt() : 1,
          dateData.length > 3 ? (dateData[3] as num).toInt() : 0,
          dateData.length > 4 ? (dateData[4] as num).toInt() : 0,
          dateData.length > 5 ? (dateData[5] as num).toInt() : 0,
        );
      } catch (e) {
        return DateTime(2000);
      }
    }
    return DateTime.tryParse(dateData.toString()) ?? DateTime(2000);
  }

  String _formatDate(dynamic dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      DateTime dateTime;
      if (dateStr is List && dateStr.isNotEmpty) {
        dateTime = DateTime(
          dateStr.length > 0 ? (dateStr[0] as num).toInt() : 2000,
          dateStr.length > 1 ? (dateStr[1] as num).toInt() : 1,
          dateStr.length > 2 ? (dateStr[2] as num).toInt() : 1,
        );
      } else {
        dateTime = DateTime.parse(dateStr.toString());
      }
      return '${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}/${dateTime.year}';
    } catch (e) {
      String str = dateStr.toString();
      if (str.length >= 10) {
        final parts = str.substring(0, 10).split('-');
        if (parts.length == 3) {
          return '${parts[2]}/${parts[1]}/${parts[0]}';
        }
      }
      return str;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

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
                _buildFilterBar(),
                const SizedBox(height: 16),
                if (_isLoading)
                  const Padding(
                    padding: EdgeInsets.all(80.0),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF10B981),
                      ),
                    ),
                  )
                else if (_displayedMatrices.isEmpty)
                  _buildEmptyState()
                else
                  _buildMatrixTable(),
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
      appBar: InternalAppHeader(isMobile: !(isDesktop), activeTab: '',),
      drawer: !isDesktop
          ? const Drawer(child: CourseManagerSidebar(currentRoute: 'matrix'))
          : null,
      body: Row(
        children: [
          if (isDesktop)
            const SizedBox(
              width: 240,
              child: CourseManagerSidebar(currentRoute: 'matrix'),
            ),
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
          const Expanded(
            child: Text(
              'Exam Matrix Management',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
                fontFamily: 'Outfit',
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 12),
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
            icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 18),
            label: const Text(
              'Create\nNew Matrix',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                height: 1.2,
                fontFamily: 'Outfit',
              ),
              textAlign: TextAlign.center,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20B486),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              minimumSize: const Size(130, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Column(
        children: [
          Icon(Icons.description_outlined,
              size: 64, color: const Color(0xFF94A3B8).withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'No matrices found',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Try adjusting your search or filters.',
            style: TextStyle(
              color: Color(0xFF94A3B8),
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBar() {
    final searchField = SizedBox(
      height: 48,
      child: TextField(
        onChanged: (value) => setState(() {
          _searchQuery = value;
          _currentPage = 1;
        }),
        decoration: InputDecoration(
          hintText: 'Search by title...',
          prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF94A3B8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );

    final statusDropdown = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.filter_list, color: Color(0xFF64748B), size: 18),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedStatus == 'ALL' ? null : _selectedStatus,
              hint: const Text('All Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 16),
              dropdownColor: Colors.white,
              items: const [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('All Status', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                ),
                DropdownMenuItem<String>(
                  value: 'PUBLIC',
                  child: Text('Public', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                ),
                DropdownMenuItem<String>(
                  value: 'PRIVATE',
                  child: Text('Private', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                ),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedStatus = val ?? 'ALL';
                  _currentPage = 1;
                });
              },
            ),
          ),
        ],
      ),
    );

    final sortDropdown = Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.sort, color: Color(0xFF64748B), size: 18),
          const SizedBox(width: 6),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _sortBy == 'NEWEST' ? 'Newest' : 'Oldest',
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B), size: 16),
              dropdownColor: Colors.white,
              items: ['Newest', 'Oldest'].map((String val) {
                return DropdownMenuItem<String>(
                  value: val,
                  child: Text(
                    'Sort by:\n$val',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      height: 1.1,
                    ),
                  ),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _sortBy = val == 'Newest' ? 'NEWEST' : 'OLDEST';
                    _currentPage = 1;
                  });
                }
              },
            ),
          ),
        ],
      ),
    );

    final refreshButton = InkWell(
      onTap: _fetchMatrices,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 48,
        width: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFCBD5E1)),
        ),
        child: const Icon(Icons.refresh, color: Color(0xFF64748B), size: 20),
      ),
    );

    final isDesktop = MediaQuery.of(context).size.width > 1024;
    if (!isDesktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          searchField,
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: statusDropdown),
              const SizedBox(width: 12),
              Expanded(child: sortDropdown),
              const SizedBox(width: 12),
              refreshButton,
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: searchField),
        const SizedBox(width: 12),
        statusDropdown,
        const SizedBox(width: 12),
        sortDropdown,
        const SizedBox(width: 12),
        refreshButton,
      ],
    );
  }

  Widget _buildMatrixTable() {
    final allMatrices = _displayedMatrices;
    int totalItems = allMatrices.length;
    int totalPages = (totalItems / _itemsPerPage).ceil();
    if (totalPages == 0) totalPages = 1;
    if (_currentPage > totalPages) _currentPage = totalPages;

    int startIndex = (_currentPage - 1) * _itemsPerPage;
    int endIndex = startIndex + _itemsPerPage;
    if (endIndex > totalItems) endIndex = totalItems;

    List<Map<String, dynamic>> pageMatrices = allMatrices.isEmpty
        ? []
        : allMatrices.sublist(startIndex, endIndex);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
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
          child: _buildDataTable(pageMatrices),
        ),
        const SizedBox(height: 16),
        _buildPaginationFooter(totalItems, startIndex, endIndex, totalPages),
      ],
    );
  }

  Widget _buildDataTable(List<Map<String, dynamic>> pageMatrices) {
    return LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: ConstrainedBox(
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: DataTable(
        headingRowColor: MaterialStateProperty.all(const Color(0xFFF8FAFC)),
        dataRowMaxHeight: 64,
        dataRowMinHeight: 64,
        columns: const [
          DataColumn(
            label: Text(
              'Matrix Name',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
          ),
          DataColumn(
            label: Text(
              'Created Date',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF64748B),
                fontFamily: 'Outfit',
              ),
            ),
          ),
          DataColumn(
            label: Expanded(
              child: Center(
                child: Text(
                  'Status',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
          ),
          DataColumn(
            label: Expanded(
              child: Center(
                child: Text(
                  'Actions',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
          ),
        ],
        rows: pageMatrices.map((matrix) {
          bool isPublic = matrix['isPublic'] == true;

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
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
              DataCell(
                Text(
                  _formatDate(matrix['createdAt']),
                  style: const TextStyle(
                    color: Color(0xFF4B5563),
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              DataCell(
                Center(
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: PopupMenuButton<bool>(
                      tooltip: 'Change Status',
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      offset: const Offset(0, 36),
                      onSelected: (newVal) async {
                        if (newVal == isPublic) return;
                        // Optimistic Update
                        setState(() {
                          matrix['isPublic'] = newVal;
                        });
                        try {
                          await _api.toggleMatrixStatus(matrix['id']);
                        } catch (e) {
                          // Rollback
                          if (mounted) {
                            setState(() {
                              matrix['isPublic'] = isPublic;
                            });
                            ToastHelper.showError(
                              context,
                              'System error, please try again later.',
                            );
                          }
                        }
                      },
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: true,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.public,
                                size: 18,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Public',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Outfit',
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (isPublic) const Spacer(),
                              if (isPublic)
                                const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Color(0xFF10B981),
                                ),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: false,
                          child: Row(
                            children: [
                              const Icon(
                                Icons.lock_outline,
                                size: 18,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Private',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Outfit',
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              if (!isPublic) const Spacer(),
                              if (!isPublic)
                                const Icon(
                                  Icons.check,
                                  size: 18,
                                  color: Color(0xFF10B981),
                                ),
                            ],
                          ),
                        ),
                      ],
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isPublic
                              ? const Color(0xFFF0FDF4)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isPublic
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFFE2E8F0),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isPublic
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isPublic ? 'Public' : 'Private',
                              style: TextStyle(
                                color: isPublic
                                    ? const Color(0xFF16A34A)
                                    : const Color(0xFF64748B),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.keyboard_arrow_down,
                              size: 14,
                              color: isPublic
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF64748B),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              DataCell(
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.visibility_outlined,
                          color: Color(0xFF64748B),
                        ),
                        tooltip: 'View',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CourseManagerMatrixBuilderPage(
                                    api: _api,
                                    onSaved: _fetchMatrices,
                                    mode: MatrixMode.view,
                                    initialData: matrix,
                                  ),
                            ),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Color(0xFF20B486),
                        ),
                        tooltip: 'Edit',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  CourseManagerMatrixBuilderPage(
                                    api: _api,
                                    onSaved: _fetchMatrices,
                                    mode: MatrixMode.edit,
                                    initialData: matrix,
                                  ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }).toList(),
              ),
            ),
          );
        },
    );
  }

  Widget _buildPaginationFooter(
    int totalItems,
    int startIndex,
    int endIndex,
    int totalPages,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          Text(
            'Showing ${totalItems == 0 ? 0 : startIndex + 1} to $endIndex of $totalItems entries',
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildPaginationButton(
                  Icons.chevron_left,
                  onPressed: _currentPage > 1
                      ? () => setState(() => _currentPage--)
                      : null,
                ),
                const SizedBox(width: 8),
                ...List.generate(totalPages, (index) {
                  int pageNum = index + 1;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildPaginationNumber(
                      pageNum.toString(),
                      isActive: pageNum == _currentPage,
                      onPressed: () => setState(() => _currentPage = pageNum),
                    ),
                  );
                }),
                _buildPaginationButton(
                  Icons.chevron_right,
                  onPressed: _currentPage < totalPages
                      ? () => setState(() => _currentPage++)
                      : null,
                ),
              ],
            ),
          ),
        ],
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
          color: isActive ? const Color(0xFF0F766E) : Colors.white,
          border: Border.all(
            color: isActive ? const Color(0xFF0F766E) : const Color(0xFFE2E8F0),
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
}
