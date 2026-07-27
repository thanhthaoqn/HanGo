import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../data/services/auth_service.dart';
import '../../../utils/toast_helper.dart';

class CommentManagementPage extends StatefulWidget {
  final Function(String) onTabChanged;
  const CommentManagementPage({super.key, required this.onTabChanged});

  @override
  State<CommentManagementPage> createState() => _CommentManagementPageState();
}

class _CommentManagementPageState extends State<CommentManagementPage> {
  final _authService = AuthService();
  bool _isLoading = false;
  
  String get apiBaseUrl {
    final authUrl = AuthService.baseUrl;
    return authUrl.replaceAll('/auth', '');
  }

  // State for active tab: 'lesson' or 'quiz'
  String _activeTab = 'lesson'; // 'lesson' | 'quiz'
  
  // Search and filter inputs
  final TextEditingController _searchController = TextEditingController();
  String _statusFilter = 'All status'; // 'All status' | 'Pending' | 'Approved' | 'Rejected'
  int _pageSize = 10;
  int _currentPage = 1;
  
  // Original comments list
  List<Map<String, dynamic>> _comments = [];

  @override
  void initState() {
    super.initState();
    _initializeData();
    // Notify initial state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onTabChanged('Lesson');
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeData() {
    _comments = [];
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final url = Uri.parse('$apiBaseUrl/admin/comments');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _comments = List<Map<String, dynamic>>.from(data);
          _isLoading = false;
        });
      } else {
        debugPrint('Failed to load comments: ${response.statusCode}');
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching comments: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  List<Map<String, dynamic>> _getFilteredAndSortedData() {
    // 1. Filter by tab type ('lesson' or 'quiz')
    List<Map<String, dynamic>> list = _comments.where((c) => c['type'] == _activeTab).toList();

    // 2. Filter by search query (commenter name or content)
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((c) {
        final name = (c['commenter'] as String).toLowerCase();
        final commentText = (c['comment'] as String).toLowerCase();
        final content = (c['quizOrLesson'] as String).toLowerCase();
        return name.contains(query) || commentText.contains(query) || content.contains(query);
      }).toList();
    }

    // 3. Filter by status
    if (_statusFilter != 'All status') {
      list = list.where((c) => c['status'] == _statusFilter).toList();
    }

    // 4. Sort
    list.sort((a, b) {
      // By default, sort by ID descending (newest first)
      return b['id'].compareTo(a['id']);
    });

    return list;
  }

  Future<void> _updateCommentStatus(int id, String newStatus) async {
    // Update locally for visual responsiveness
    setState(() {
      final index = _comments.indexWhere((c) => c['id'] == id);
      if (index != -1) {
        _comments[index]['status'] = newStatus;
      }
    });

    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final url = Uri.parse('$apiBaseUrl/admin/comments/$id/status?status=$newStatus');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ToastHelper.showSuccess(context, 'Comment status updated to $newStatus');
        }
      } else {
        debugPrint('Failed to update status on server: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ToastHelper.showError(context, 'Failed to update status: ${response.body}');
        }
        _fetchComments();
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
      _fetchComments();
    }
  }

  Future<void> _deleteComment(int id) async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final url = Uri.parse('$apiBaseUrl/admin/comments/$id');
      final response = await http.delete(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _comments.removeWhere((c) => c['id'] == id);
        });
        if (mounted) {
          ToastHelper.showSuccess(context, 'Comment deleted successfully');
        }
      } else if (mounted) {
        ToastHelper.showError(context, 'Failed to delete comment: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Error deleting comment: $e');
      }
    }
  }

  void _confirmDelete(int id) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Comment', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
          content: const Text(
            'Are you sure you want to delete this comment? This action cannot be undone.',
            style: TextStyle(fontFamily: 'Outfit'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(context);
                _deleteComment(id);
              },
              child: const Text('Delete', style: TextStyle(fontFamily: 'Outfit', color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showCommentDetailDialog(Map<String, dynamic> summary) async {
    final int id = summary['id'];
    Map<String, dynamic> detail = summary;

    try {
      final token = await _authService.getToken();
      if (token != null) {
        final response = await http.get(
          Uri.parse('$apiBaseUrl/admin/comments/$id'),
          headers: {'Authorization': 'Bearer $token'},
        );
        if (response.statusCode == 200) {
          detail = jsonDecode(response.body) as Map<String, dynamic>;
        }
      }
    } catch (e) {
      debugPrint('Failed to load comment detail: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        final String status = (detail['status'] ?? summary['status'] ?? 'Pending').toString();
        return Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 640),
            padding: const EdgeInsets.all(28),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Comment Detail #$id',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
                        ),
                      ),
                      IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${detail['commenter'] ?? ''} • ${detail['email'] ?? ''}',
                    style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Course: ${detail['course'] ?? 'N/A'}  •  Lesson/Quiz: ${detail['quizOrLesson'] ?? 'N/A'}  •  ${detail['createdAt'] ?? ''}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),
                  _buildDetailField('Original Comment', detail['originalContent'] ?? detail['comment'] ?? ''),
                  const SizedBox(height: 16),
                  _buildDetailField('Normalized Comment', detail['normalizedContent'] ?? '(no rule triggered)'),
                  const SizedBox(height: 16),
                  _buildDetailField('Detection Reason', detail['detectionReason'] ?? 'No violation detected'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Text('Current Status: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit')),
                      _buildStatusDropdownChip(id, status),
                    ],
                  ),
                  const SizedBox(height: 28),
                  const Divider(color: Color(0xFFE2E8F0)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _confirmDelete(id);
                        },
                        icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
                        label: const Text('Delete'),
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: () {
                          _updateCommentStatus(id, 'Rejected');
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.cancel_outlined, size: 16),
                        label: const Text('Reject'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          _updateCommentStatus(id, 'Approved');
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF14B8A6)),
                        icon: const Icon(Icons.check_circle_outline, size: 16, color: Colors.white),
                        label: const Text('Approve', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailField(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit')),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFF1F5F9)),
          ),
          child: Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontFamily: 'Outfit', height: 1.4)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filtered data count for badges
    final lessonCount = _comments.where((c) => c['type'] == 'lesson').length;
    final quizCount = _comments.where((c) => c['type'] == 'quiz').length;

    final filteredList = _getFilteredAndSortedData();
    final totalRecords = filteredList.length;
    
    // Pagination math
    final totalPages = (totalRecords / _pageSize).ceil();
    final safeCurrentPage = _currentPage > totalPages ? (totalPages > 0 ? totalPages : 1) : _currentPage;
    final startIndex = (safeCurrentPage - 1) * _pageSize;
    final endIndex = startIndex + _pageSize > totalRecords ? totalRecords : startIndex + _pageSize;
    
    final paginatedList = totalRecords > 0 ? filteredList.sublist(startIndex, endIndex) : <Map<String, dynamic>>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and Subtitle
        const Text(
          'Comment Management',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 24),

        // Subtabs: Lesson & Quiz (Pill shape tabs)
        Container(
          height: 48,
          decoration: BoxDecoration(
            color: const Color(0xFFEFF6FF),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTabPill('Lesson', lessonCount, _activeTab == 'lesson', () {
                setState(() {
                  _activeTab = 'lesson';
                  _currentPage = 1;
                });
                widget.onTabChanged('Lesson');
              }),
              const SizedBox(width: 4),
              _buildTabPill('Quiz', quizCount, _activeTab == 'quiz', () {
                setState(() {
                  _activeTab = 'quiz';
                  _currentPage = 1;
                });
                widget.onTabChanged('Quiz');
              }),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Search Bar, Filter and Page size controllers
        Row(
          children: [
            // Search Input
            Expanded(
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        onChanged: (val) {
                          setState(() {
                            _currentPage = 1;
                          });
                        },
                        decoration: const InputDecoration(
                          hintText: 'Search by reporter name or reason...',
                          hintStyle: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        style: const TextStyle(fontSize: 14, fontFamily: 'Outfit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Status Filter Dropdown
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _statusFilter,
                  icon: const Icon(Icons.filter_list, color: Color(0xFF4B5563), size: 18),
                  style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14, fontFamily: 'Outfit', fontWeight: FontWeight.w500),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _statusFilter = newValue;
                        _currentPage = 1;
                      });
                    }
                  },
                  items: <String>['All status', 'Pending', 'Approved', 'Rejected']
                      .map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Page Size Selector
            Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFE5E7EB)),
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
                            _currentPage = 1;
                          });
                        }
                      },
                      items: <int>[5, 10, 20, 50]
                          .map<DropdownMenuItem<int>>((int value) {
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
        const SizedBox(height: 20),

        // Table Container
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Table Header Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: const BoxDecoration(
                  color: Color(0xFFF0FDF4), // Soft green tint
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    // Commenter
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: const [
                          Text('COMMENTER', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857), fontFamily: 'Outfit')),
                          SizedBox(width: 4),
                          Icon(Icons.swap_vert, size: 14, color: Color(0xFF047857)),
                        ],
                      ),
                    ),
                    // Comment
                    const Expanded(
                      flex: 4,
                      child: Text('COMMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857), fontFamily: 'Outfit')),
                    ),
                    // Course
                    const Expanded(
                      flex: 2,
                      child: Text('COURSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857), fontFamily: 'Outfit')),
                    ),
                    // Lesson/Quiz
                    const Expanded(
                      flex: 2,
                      child: Text('LESSON/QUIZ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857), fontFamily: 'Outfit')),
                    ),
                    // Status
                    Expanded(
                      flex: 2,
                      child: Row(
                        children: const [
                          Text('STATUS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857), fontFamily: 'Outfit')),
                          SizedBox(width: 4),
                          Icon(Icons.swap_vert, size: 14, color: Color(0xFF047857)),
                        ],
                      ),
                    ),
                    // Created Time
                    const Expanded(
                      flex: 2,
                      child: Text('CREATED', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857), fontFamily: 'Outfit')),
                    ),
                    // Actions
                    const Expanded(
                      flex: 2,
                      child: Text('ACTIONS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Color(0xFF047857), fontFamily: 'Outfit')),
                    ),
                  ],
                ),
              ),

              // Table Rows
              if (_isLoading)
                const SizedBox(
                  height: 200,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF14B8A6)),
                    ),
                  ),
                )
              else if (paginatedList.isEmpty)
                const SizedBox(
                  height: 200,
                  child: Center(
                    child: Text(
                      'No comments found.',
                      style: TextStyle(color: Color(0xFF6B7280), fontSize: 14, fontFamily: 'Outfit'),
                    ),
                  ),
                )
              else
                Column(
                  children: paginatedList.map((c) {
                    final int id = c['id'];
                    final String commenter = c['commenter'];
                    final String comment = c['comment'];
                    final String status = c['status'];
                    final String course = c['course'] ?? 'N/A';
                    final String quizOrLesson = c['quizOrLesson'] ?? 'N/A';
                    final String createdAt = c['createdAt'] ?? '';

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                        ),
                      ),
                      child: Row(
                        children: [
                          // COMMENTER
                          Expanded(
                            flex: 2,
                            child: Text(
                              commenter,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: Color(0xFF1F2937),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                          // COMMENT
                          Expanded(
                            flex: 4,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 16.0),
                              child: Text(
                                comment,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF4B5563),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ),
                          ),
                          // COURSE
                          Expanded(
                            flex: 2,
                            child: Text(
                              course,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontFamily: 'Outfit'),
                            ),
                          ),
                          // LESSON/QUIZ
                          Expanded(
                            flex: 2,
                            child: Text(
                              quizOrLesson,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontFamily: 'Outfit'),
                            ),
                          ),
                          // STATUS
                          Expanded(
                            flex: 2,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildStatusDropdownChip(id, status),
                            ),
                          ),
                          // CREATED
                          Expanded(
                            flex: 2,
                            child: Text(
                              createdAt,
                              style: const TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontFamily: 'Outfit'),
                            ),
                          ),
                          // ACTIONS
                          Expanded(
                            flex: 2,
                            child: Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 18, color: Color(0xFF4B5563)),
                                  tooltip: 'View Detail',
                                  onPressed: () => _showCommentDetailDialog(c),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                                  tooltip: 'Delete',
                                  onPressed: () => _confirmDelete(id),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Pagination row
        if (totalPages > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Back button
              IconButton(
                icon: const Icon(Icons.chevron_left, size: 18),
                onPressed: safeCurrentPage > 1
                    ? () {
                        setState(() {
                          _currentPage--;
                        });
                      }
                    : null,
              ),
              const SizedBox(width: 4),

              // Page numbers
              ...List.generate(totalPages, (index) {
                final pageNum = index + 1;
                final isCurrent = pageNum == safeCurrentPage;

                return InkWell(
                  onTap: () {
                    setState(() {
                      _currentPage = pageNum;
                    });
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isCurrent ? const Color(0xFF047857) : Colors.transparent, // matching mockup dark green/teal
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
              // Next button
              IconButton(
                icon: const Icon(Icons.chevron_right, size: 18),
                onPressed: safeCurrentPage < totalPages
                    ? () {
                        setState(() {
                          _currentPage++;
                        });
                      }
                    : null,
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildTabPill(String title, int count, bool active, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: active ? const Color(0xFF14B8A6) : const Color(0xFF6B7280),
                fontWeight: FontWeight.bold,
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFE6FFFA) : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: active ? const Color(0xFF14B8A6) : const Color(0xFF6B7280),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusDropdownChip(int id, String status) {
    Color bg = const Color(0xFFF3F4F6);
    Color fg = const Color(0xFF4B5563);
    IconData icon = Icons.access_time;

    if (status == 'Approved') {
      bg = const Color(0xFFDEF7EC);
      fg = const Color(0xFF03543F);
      icon = Icons.check_circle_outline;
    } else if (status == 'Rejected') {
      bg = const Color(0xFFFDE8E8);
      fg = const Color(0xFF9B1C1C);
      icon = Icons.cancel_outlined;
    }

    return PopupMenuButton<String>(
      onSelected: (newVal) {
        _updateCommentStatus(id, newVal);
      },
      offset: const Offset(0, 30),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(
                color: fg,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 12, color: fg),
          ],
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'Pending',
          child: Text('Pending', style: TextStyle(fontFamily: 'Outfit')),
        ),
        const PopupMenuItem(
          value: 'Approved',
          child: Text('Approved', style: TextStyle(fontFamily: 'Outfit')),
        ),
        const PopupMenuItem(
          value: 'Rejected',
          child: Text('Rejected', style: TextStyle(fontFamily: 'Outfit')),
        ),
      ],
    );
  }
}
