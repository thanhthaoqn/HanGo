import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../domain/model/course_detail.dart';
import '../../../domain/model/lesson_detail.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/ai_assistant_drawer.dart';
import '../../../utils/fullscreen_helper.dart';
import '../../../utils/toast_helper.dart';
import '../../../utils/string_utils.dart';
import '../../widgets/lesson_ai_chatbox.dart';
import 'package:provider/provider.dart';

class LessonDetailPage extends StatefulWidget {
  final int courseId;
  final int lessonId;
  final bool startQuizImmediately;

  const LessonDetailPage({
    Key? key,
    required this.courseId,
    required this.lessonId,
    this.startQuizImmediately = false,
  }) : super(key: key);

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> {
  final CourseRepository _courseRepository = CourseRepository();
  final LessonRepository _lessonRepository = LessonRepository();

  CourseDetail? _courseDetail;
  LessonDetail? _lessonDetail;
  String? _errorMessage;
  bool _isLoading = true;
  bool _isNavigatingLesson = false;
  bool _isMarkingCompleted = false;
  late int _currentLessonId;

  int _currentUserId = 1; // Default
  String _currentUserAvatar = '';
  String _currentUserInitials = '';
  int? _editingCommentId;
  final TextEditingController _editCommentController = TextEditingController();
  int? _replyingToCommentId;
  final TextEditingController _replyCommentController = TextEditingController();
  bool _isPostingReply = false;

  bool _isAIAssistantOpen = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isPostingComment = false;

  bool _isDoingQuiz = false;
  bool _isQuizMaximized = true;
  int _activeQuestionIndex = 0;
  int? _reviewAttemptIndex;
  final Map<int, int> _selectedAnswers = {};

  List<QuizAttempt> _quizAttempts = [];
  List<Map<int, int>> _attemptsAnswers = [];

  Future<void> _loadQuizAttempts() async {
    try {
      final attemptsData = await _lessonRepository.fetchQuizAttempts(_currentLessonId, _currentUserId);
      final List<QuizAttempt> loadedAttempts = [];
      final List<Map<int, int>> loadedAnswers = [];

      for (var item in attemptsData) {
        loadedAttempts.add(QuizAttempt(
          attemptNumber: item['attemptNumber'] ?? 1,
          state: item['state'] ?? 'Finished',
          grade: item['grade'] ?? '0.0 / 10.0',
          submittedTime: item['submittedTime'] ?? '',
        ));

        final rawAnswers = item['answers'];
        final Map<int, int> attemptMap = {};
        if (rawAnswers is Map) {
          rawAnswers.forEach((k, v) {
            final intKey = int.tryParse(k.toString());
            final intVal = int.tryParse(v.toString());
            if (intKey != null && intVal != null) {
              attemptMap[intKey] = intVal;
            }
          });
        }
        loadedAnswers.add(attemptMap);
      }

      setState(() {
        _quizAttempts = loadedAttempts;
        _attemptsAnswers = loadedAnswers;
      });
    } catch (e) {
      print('Error loading quiz attempts: $e');
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      final course = await _courseRepository.fetchCourseDetail(widget.courseId);
      final lesson = await _lessonRepository.fetchLessonDetail(
        _currentLessonId,
      );
      setState(() {
        _courseDetail = course;
        _lessonDetail = lesson;
      });
      await _loadQuizAttempts();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _navigateToLesson(int lessonId, {bool startQuiz = false}) async {
    if (lessonId == _currentLessonId) return;
    setState(() {
      _isNavigatingLesson = true;
      _isDoingQuiz = startQuiz;
      _isQuizMaximized = true;
      _activeQuestionIndex = 0;
      _selectedAnswers.clear();
      _reviewAttemptIndex = null;
    });
    try {
      final newLesson = await _lessonRepository.fetchLessonDetail(lessonId);
      setState(() {
        _currentLessonId = lessonId;
        _lessonDetail = newLesson;
      });
      await _loadQuizAttempts();
      setState(() {
        _isNavigatingLesson = false;
      });
      if (startQuiz) {
        toggleFullscreen(true);
      } else {
        toggleFullscreen(false);
      }
    } catch (e) {
      setState(() {
        _isNavigatingLesson = false;
      });
      ToastHelper.showError(context, 'Failed to load lesson: $e');
    }
  }

  Future<void> _initData() async {
    await _loadCurrentUserId();
    await _loadData();
  }

  @override
  void initState() {
    super.initState();
    _currentLessonId = widget.lessonId;
    _isDoingQuiz = widget.startQuizImmediately;
    _isQuizMaximized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final totalWidth = MediaQuery.of(context).size.width;
      final availableWidth = totalWidth - 320; // Trừ đi 320px của Left Sidebar
      setState(() {
        // Cho phần bài học bên trái chiếm 65% không gian khả dụng, chatbox chiếm 35% còn lại
        _leftPaneWidth = availableWidth * 0.65;
        _hasInitializedSplit = true;
      });
    });

    _initData();
    if (widget.startQuizImmediately) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        toggleFullscreen(true);
      });
    }
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final avatar = prefs.getString('user_avatar_url') ?? '';
    final fullName = prefs.getString('user_fullname') ?? '';
    String initials = 'U';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }
    setState(() {
      _currentUserId = prefs.getInt('user_id') ?? 1;
      _currentUserAvatar = avatar;
      _currentUserInitials = initials;
    });
  }

  @override
  void dispose() {
    _commentController.dispose();
    _editCommentController.dispose();
    super.dispose();
  }

  void _toggleAIAssistant() {
    setState(() {
      _isAIAssistantOpen = !_isAIAssistantOpen;
    });
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isPostingComment = true;
    });

    try {
      await _lessonRepository.postComment(
        _currentLessonId,
        _currentUserId,
        _commentController.text.trim(),
      );
      _commentController.clear();
      final updatedLesson = await _lessonRepository.fetchLessonDetail(
        _currentLessonId,
      );
      setState(() {
        _lessonDetail = updatedLesson;
      });
    } catch (e) {
      ToastHelper.showError(context, 'Failed to post comment: $e');
    } finally {
      setState(() {
        _isPostingComment = false;
      });
    }
  }

  Future<void> _updateComment(int commentId) async {
    if (_editCommentController.text.trim().isEmpty) return;

    try {
      await _lessonRepository.updateComment(
        commentId,
        _currentUserId,
        _editCommentController.text.trim(),
      );
      final updatedLesson = await _lessonRepository.fetchLessonDetail(
        _currentLessonId,
      );
      setState(() {
        _editingCommentId = null;
        _lessonDetail = updatedLesson;
      });
    } catch (e) {
      ToastHelper.showError(context, 'Failed to update comment: $e');
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      await _lessonRepository.deleteComment(commentId, _currentUserId);
      final updatedLesson = await _lessonRepository.fetchLessonDetail(
        _currentLessonId,
      );
      setState(() {
        _lessonDetail = updatedLesson;
      });
    } catch (e) {
      ToastHelper.showError(context, 'Failed to delete comment: $e');
    }
  }

  Future<void> _toggleLikeComment(LessonComment comment) async {
    try {
      if (comment.isLiked) {
        await _lessonRepository.unlikeComment(comment.id, _currentUserId);
      } else {
        await _lessonRepository.likeComment(comment.id, _currentUserId);
      }
      final updatedLesson = await _lessonRepository.fetchLessonDetail(
        _currentLessonId,
      );
      setState(() {
        _lessonDetail = updatedLesson;
      });
    } catch (e) {
      ToastHelper.showError(context, 'Failed to update like: $e');
    }
  }

  Future<void> _postReply(int parentCommentId) async {
    if (_replyCommentController.text.trim().isEmpty) return;

    setState(() {
      _isPostingReply = true;
    });

    try {
      await _lessonRepository.postComment(
        _currentLessonId,
        _currentUserId,
        _replyCommentController.text.trim(),
        parentCommentId: parentCommentId,
      );
      _replyCommentController.clear();
      setState(() {
        _replyingToCommentId = null;
      });
      final updatedLesson = await _lessonRepository.fetchLessonDetail(
        _currentLessonId,
      );
      setState(() {
        _lessonDetail = updatedLesson;
      });
    } catch (e) {
      ToastHelper.showError(context, 'Failed to post reply: $e');
    } finally {
      setState(() {
        _isPostingReply = false;
      });
    }
  }

  void _showModernConfirmDialog({
    required String title,
    required Widget content,
    required String confirmText,
    required Color confirmColor,
    required VoidCallback onConfirm,
    IconData? icon,
    Color? iconBgColor,
    Color? iconColor,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 10,
        backgroundColor: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor ?? const Color(0xFFE6F7F4),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: iconColor ?? const Color(0xFF28B79B),
                    size: 28,
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 12),
              DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
                child: content,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFFCBD5E1)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        onConfirm();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: confirmColor,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(int commentId) {
    _showModernConfirmDialog(
      title: 'Delete Comment',
      content: const Text(
        'Are you sure you want to delete this comment? This action cannot be undone.',
      ),
      confirmText: 'Delete',
      confirmColor: const Color(0xFFEF4444),
      icon: Icons.delete_outline_rounded,
      iconBgColor: const Color(0xFFFEE2E2),
      iconColor: const Color(0xFFEF4444),
      onConfirm: () => _deleteComment(commentId),
    );
  }

  int? _getNextLessonId(CourseDetail course, int currentLessonId) {
    for (int i = 0; i < course.sessions.length; i++) {
      final session = course.sessions[i];
      for (int j = 0; j < session.lessons.length; j++) {
        if (session.lessons[j].id == currentLessonId) {
          if (j + 1 < session.lessons.length) {
            return session.lessons[j + 1].id;
          }
          for (int k = i + 1; k < course.sessions.length; k++) {
            if (course.sessions[k].lessons.isNotEmpty) {
              return course.sessions[k].lessons.first.id;
            }
          }
          return null;
        }
      }
    }
    return null;
  }

  int get _answeredCount => _selectedAnswers.length;

  // Resizable split between lesson and AI chat
  double _leftPaneWidth = 0; // computed on first layout
  bool _hasInitializedSplit = false;
  static const double _minLeftPaneWidth = 520;
  static const double _minRightPaneWidth = 320;

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final showHideNavLinks = _isDoingQuiz && _isQuizMaximized;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(
        isDesktop: isDesktop,
        activeTab: 'Courses',
        hideNavLinks: showHideNavLinks,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF28B79B)),
            )
          : (_errorMessage != null)
          ? Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'An error occurred: $_errorMessage',
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            )
          : _buildPageContent(isDesktop, showHideNavLinks),
    );
  }

  Widget _buildPageContent(bool isDesktop, bool showHideNavLinks) {
    final CourseDetail course = _courseDetail!;
    final LessonDetail lesson = _lessonDetail!;
    final activeQuestions = lesson.questions;

    if (_isDoingQuiz && _isQuizMaximized) {
      return _buildMaximizedQuizLayout(
        course,
        lesson,
        activeQuestions,
        isDesktop,
      );
    }

    // Determine current session title for breadcrumbs
    String? sessionTitle;
    for (final s in course.sessions) {
      if (s.lessons.any((l) => l.id == lesson.id)) {
        sessionTitle = s.title;
        break;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Sidebar (desktop only)
        if (isDesktop)
          Material(
            color: Colors.white,
            child: Container(
              width: 320,
              decoration: BoxDecoration(
                border: Border(right: BorderSide(color: Colors.grey.shade200)),
              ),
              child: _buildSidebar(course),
            ),
          ),

        // Main Content
        Expanded(
          child: Column(
            children: [
              if (_isNavigatingLesson)
                const LinearProgressIndicator(
                  color: Color(0xFF28B79B),
                  backgroundColor: Color(0xFFE6F7F4),
                  minHeight: 3,
                ),

              // Sub-header Breadcrumb
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                ),
                child: Row(
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: const Icon(
                          Icons.arrow_back,
                          size: 16,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${course.title}  /  ${sessionTitle ?? "Section"}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            lesson.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Content (lesson left scrolls, AI chat stays fixed)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Left column: scrollable only
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildLessonContent(course, lesson),
                            if (!_isDoingQuiz) ...[
                              const SizedBox(height: 32),
                              _buildCommentsSection(lesson),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Right column: resizable AI chat (no scrolling with lesson)
                    if (!_isDoingQuiz) ...[
                      const SizedBox(width: 12),

                      // Divider draggable between lesson and chat
                      MouseRegion(
                        cursor: SystemMouseCursors.resizeLeftRight,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onHorizontalDragUpdate: (details) {
                            if (!isDesktop) return;
                            final totalWidth = MediaQuery.of(
                              context,
                            ).size.width;
                            // subtract left sidebar width (320) if present
                            final availableWidth =
                                totalWidth - (isDesktop ? 320 : 0);
                            // also subtract breadcrumb padding-ish: we only approximate with availableWidth
                            // Clamp within min widths.
                            final dx = details.delta.dx;
                            setState(() {
                              _leftPaneWidth = (_leftPaneWidth + dx).clamp(
                                _minLeftPaneWidth,
                                availableWidth - _minRightPaneWidth,
                              );
                              _hasInitializedSplit = true;
                            });
                          },
                          child: Container(
                            width: 10,
                            height: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border(
                                left: BorderSide(color: Colors.grey.shade200),
                                right: BorderSide(color: Colors.grey.shade200),
                              ),
                            ),
                            child: const Align(
                              alignment: Alignment.center,
                              child: Icon(
                                Icons.drag_handle,
                                size: 18,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Chat width driven by _leftPaneWidth
                      SizedBox(
                        width: isDesktop
                            ? (MediaQuery.of(context).size.width -
                                      320 -
                                      _leftPaneWidth -
                                      12)
                                  .clamp(_minRightPaneWidth, 800)
                            : 320,
                        child: LessonAiChatbox(
                          key: ValueKey<int>(_currentLessonId),
                          lessonId: _currentLessonId,
                          lessonTitle: lesson.title,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData _getLessonIcon(String? itemType) {
    if (itemType == null) return Icons.menu_book_rounded;
    switch (itemType.toLowerCase()) {
      case 'learning':
        return Icons.menu_book_rounded;
      case 'practice':
        return Icons.assignment_rounded;
      case 'quiz':
        return Icons.quiz_rounded;
      default:
        return Icons.menu_book_rounded;
    }
  }

  Widget _buildSidebar(CourseDetail course) {
    // THÊM: Bọc Material transparent ở đây để sửa lỗi Ink Splashes
    return Material(
      color: Colors.transparent,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12),
        itemCount: course.sessions.length,
        itemBuilder: (context, index) {
          final session = course.sessions[index];
          return Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              initiallyExpanded: session.lessons.any(
                (l) => l.id == _currentLessonId,
              ),
              title: Text(
                'SECTION ${index + 1}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF28B79B),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              subtitle: Text(
                session.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              childrenPadding: const EdgeInsets.symmetric(vertical: 4),
              children: session.lessons.map((l) {
                final isCurrent = l.id == _currentLessonId;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Material(
                    color: isCurrent
                        ? const Color(0xFFE6F7F4)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: Icon(
                        _getLessonIcon(l.itemType),
                        color: isCurrent
                            ? const Color(0xFF28B79B)
                            : const Color(0xFF94A3B8),
                        size: 20,
                      ),
                      title: Text(
                        l.title,
                        style: TextStyle(
                          fontSize: 13,
                          color: isCurrent
                              ? const Color(0xFF28B79B)
                              : const Color(0xFF475569),
                          fontWeight: isCurrent
                              ? FontWeight.bold
                              : FontWeight.w500,
                        ),
                      ),
                      trailing: l.isCompleted
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: Color(0xFF28B79B),
                              size: 16,
                            )
                          : null,
                      onTap: () {
                        _navigateToLesson(l.id);
                      },
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLessonContent(CourseDetail course, LessonDetail lesson) {
    final nextLessonId = _getNextLessonId(course, lesson.id);

    CourseLesson? currentCourseLesson;
    for (final s in course.sessions) {
      for (final l in s.lessons) {
        if (l.id == lesson.id) {
          currentCourseLesson = l;
          break;
        }
      }
    }
    final itemType = currentCourseLesson?.itemType?.toLowerCase() ?? 'learning';
    String badgeText = 'LESSON';
    IconData badgeIcon = Icons.menu_book_rounded;
    if (itemType == 'practice') {
      badgeText = 'PRACTICE';
      badgeIcon = Icons.assignment_rounded;
    } else if (itemType == 'quiz') {
      badgeText = 'QUIZ';
      badgeIcon = Icons.quiz_rounded;
    }

    final isQuizOrPractice = itemType == 'quiz' || itemType == 'practice';

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Elegant top bar indicator
          Container(
            height: 6,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF28B79B), Color(0xFF0D9488)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Lesson badge and icon
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE6F7F4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF28B79B),
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(badgeIcon, size: 16, color: const Color(0xFF64748B)),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  lesson.title,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 24),
                const Divider(color: Color(0xFFF1F5F9), height: 1),
                const SizedBox(height: 24),

                if (isQuizOrPractice)
                  _buildQuizContent(lesson, currentCourseLesson)
                else ...[
                  _buildHtmlContent(lesson),
                  const SizedBox(height: 32),
                  _buildMarkAsCompletedButton(lesson, nextLessonId, course),
                ],

                if (nextLessonId != null &&
                    !_isDoingQuiz &&
                    _reviewAttemptIndex == null) ...[
                  const SizedBox(height: 32),
                  _buildNextLessonButton(nextLessonId, course),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHtmlContent(LessonDetail lesson) {
    return lesson.content.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Lesson content is currently being updated...',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ),
          )
        : Html(
            data: lesson.content,
            style: {
              "h1": Style(
                color: const Color(0xFF1E293B),
                fontSize: FontSize(22),
                fontWeight: FontWeight.bold,
                margin: Margins.only(top: 24, bottom: 12),
              ),
              "h2": Style(
                color: const Color(0xFF1E293B),
                fontSize: FontSize(18),
                fontWeight: FontWeight.bold,
                margin: Margins.only(top: 20, bottom: 10),
              ),
              "p": Style(
                color: const Color(0xFF475569),
                fontSize: FontSize(15),
                lineHeight: LineHeight.number(1.7),
                margin: Margins.only(bottom: 16),
              ),
              "ul": Style(
                color: const Color(0xFF475569),
                fontSize: FontSize(15),
                margin: Margins.only(bottom: 16),
              ),
              "ol": Style(
                color: const Color(0xFF475569),
                fontSize: FontSize(15),
                margin: Margins.only(bottom: 16),
              ),
              "li": Style(margin: Margins.only(bottom: 8.0)),
              "blockquote": Style(
                backgroundColor: const Color(0xFFF8FAFC),
                border: const Border(
                  left: BorderSide(color: Color(0xFF28B79B), width: 4),
                ),
                padding: HtmlPaddings.symmetric(horizontal: 16, vertical: 12),
                margin: Margins.only(bottom: 16),
              ),
              "code": Style(
                backgroundColor: const Color(0xFFF1F5F9),
                color: const Color(0xFFE11D48),
                padding: HtmlPaddings.symmetric(horizontal: 6, vertical: 2),
              ),
            },
          );
  }

  Widget _buildQuizContent(
    LessonDetail lesson,
    CourseLesson? currentCourseLesson,
  ) {
    final activeQuestions = lesson.questions;

    if (_reviewAttemptIndex != null) {
      return _buildQuizReview(activeQuestions);
    }

    if (_isDoingQuiz) {
      return _buildQuizTaking(activeQuestions);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Start Box
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.01),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${activeQuestions.length} question',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF28B79B),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _selectedAnswers.clear();
                    _activeQuestionIndex = 0;
                    _isDoingQuiz = true;
                    _isQuizMaximized = true;
                  });
                  toggleFullscreen(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28B79B),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: const Text(
                  'Start',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // 2. Attempts Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFFF4FBF9),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE6F4F1)),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: const [
                    Expanded(
                      flex: 2,
                      child: Text(
                        'Attempt',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Text(
                        'State',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Grade',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Submitted Time',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          'Review',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Divider(color: Color(0xFFE2E8F0), height: 1),
                const SizedBox(height: 12),

                if (_quizAttempts.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No attempts yet. Click Start to try!',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _quizAttempts.length,
                    separatorBuilder: (context, index) =>
                        const Divider(color: Color(0xFFF1F5F9), height: 1),
                    itemBuilder: (context, index) {
                      final attempt = _quizAttempts[index];
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                '${attempt.attemptNumber}',
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Row(
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    attempt.state,
                                    style: const TextStyle(
                                      color: Color(0xFF22C55E),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  attempt.grade,
                                  style: const TextStyle(
                                    color: Color(0xFF1E293B),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 3,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Text(
                                  attempt.submittedTime,
                                  style: const TextStyle(
                                    color: Color(0xFF64748B),
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.click,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _reviewAttemptIndex = index;
                                      });
                                    },
                                    child: const Text(
                                      'Review',
                                      style: TextStyle(
                                        color: Color(0xFF28B79B),
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
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
  }

  void _showExitQuizConfirmation() {
    _showModernConfirmDialog(
      title: 'Exit Quiz',
      content: const Text(
        'Are you sure you want to exit? Your progress on this attempt will be lost.',
      ),
      confirmText: 'Exit',
      confirmColor: const Color(0xFF28B79B),
      icon: Icons.warning_amber_rounded,
      iconBgColor: const Color(0xFFFEF3C7),
      iconColor: const Color(0xFFD97706),
      onConfirm: () {
        setState(() {
          _isDoingQuiz = false;
        });
        toggleFullscreen(false);
      },
    );
  }

  Widget _buildExitQuizHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: _showExitQuizConfirmation,
              child: Row(
                children: const [
                  Icon(Icons.arrow_back, size: 20, color: Color(0xFF1E293B)),
                  SizedBox(width: 8),
                  Text(
                    'Exit Quiz',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuizTopBar(List<QuizQuestion> activeQuestions) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF28B79B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Question ${_activeQuestionIndex + 1} / ${activeQuestions.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F7F4),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF28B79B).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline_rounded,
                      size: 16,
                      color: Color(0xFF28B79B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$_answeredCount done',
                      style: const TextStyle(
                        color: Color(0xFF28B79B),
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Minimize/Maximize removed as requested
        ],
      ),
    );
  }

  Widget _buildQuizActiveQuestionPane(List<QuizQuestion> activeQuestions) {
    final qIndex = _activeQuestionIndex;
    if (qIndex >= activeQuestions.length) return const SizedBox.shrink();

    final q = activeQuestions[qIndex];
    final passage = q.passage;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (passage != null && passage.trim().isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(maxHeight: 220),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Text(
                    passage,
                    style: const TextStyle(
                      fontSize: 14.5,
                      color: Color(0xFF334155),
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Question badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F4),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '• Questions ${qIndex + 1}   ${qIndex + 1}/${activeQuestions.length}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF28B79B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Question text
            Text(
              '${qIndex + 1}. ${q.questionText}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),

            // Options
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: q.options.length,
              itemBuilder: (context, oIndex) {
                final isSelected = _selectedAnswers[qIndex] == oIndex;
                final optionLetter = String.fromCharCode(
                  65 + oIndex,
                ); // A, B, C, D...

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? const Color(0xFF28B79B) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF28B79B)
                          : const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _selectedAnswers[qIndex] = oIndex;
                      });
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? Colors.white
                                  : const Color(0xFFF1F5F9),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFFE2E8F0),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                optionLetter,
                                style: TextStyle(
                                  color: isSelected
                                      ? const Color(0xFF28B79B)
                                      : const Color(0xFF475569),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              q.options[oIndex],
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(
    String label,
    Color color, {
    bool hasBorder = false,
    Color? borderColor,
  }) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: hasBorder
                ? Border.all(
                    color: borderColor ?? Colors.transparent,
                    width: 1.5,
                  )
                : null,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _showSubmitQuizConfirmation(List<QuizQuestion> activeQuestions) {
    _showModernConfirmDialog(
      title: 'Submit Quiz',
      content: Text(
        'Are you sure you want to submit? You have answered $_answeredCount / ${activeQuestions.length} questions.',
      ),
      confirmText: 'Submit',
      confirmColor: const Color(0xFF28B79B),
      icon: Icons.send_rounded,
      iconBgColor: const Color(0xFFE6F7F4),
      iconColor: const Color(0xFF28B79B),
      onConfirm: () => _submitQuiz(activeQuestions),
    );
  }

  Future<void> _submitQuiz(List<QuizQuestion> activeQuestions) async {
    int correctCount = 0;
    for (int i = 0; i < activeQuestions.length; i++) {
      if (_selectedAnswers[i] == activeQuestions[i].correctIndex) {
        correctCount++;
      }
    }
    final score = (correctCount / activeQuestions.length) * 10.0;

    try {
      await _lessonRepository.postQuizAttempt(
        _currentLessonId,
        _currentUserId,
        score,
        _selectedAnswers,
      );

      await _loadQuizAttempts();

      setState(() {
        _isDoingQuiz = false;
        _reviewAttemptIndex = _quizAttempts.length - 1;
      });

      toggleFullscreen(false);

      ToastHelper.showSuccess(
        context,
        'Quiz submitted! Score: ${score.toStringAsFixed(1)} / 10.0',
      );
    } catch (e) {
      ToastHelper.showError(context, 'Failed to submit quiz attempt: $e');
    }
  }

  Widget _buildQuizRightSidebarPane(List<QuizQuestion> activeQuestions) {
    final progress = activeQuestions.isEmpty
        ? 0.0
        : _answeredCount / activeQuestions.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Process Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Process',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF475569),
                    ),
                  ),
                  Text(
                    '$_answeredCount / ${activeQuestions.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF28B79B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFF1F5F9),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF28B79B),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // List Question Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.list_alt_rounded,
                    size: 20,
                    color: Color(0xFF28B79B),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'List Question',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Legends Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildLegendItem('Present', const Color(0xFF28B79B)),
                  _buildLegendItem(
                    'Done',
                    const Color(0xFFE6F7F4),
                    hasBorder: true,
                    borderColor: const Color(0xFF28B79B),
                  ),
                  _buildLegendItem('Not yet', const Color(0xFFF1F5F9)),
                ],
              ),
              const SizedBox(height: 16),

              // Question Grid
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: _isQuizMaximized ? double.infinity : 240,
                  ),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1,
                        ),
                    itemCount: activeQuestions.length,
                    itemBuilder: (context, gridIndex) {
                      final isCurrent = gridIndex == _activeQuestionIndex;
                      final isAnswered = _selectedAnswers.containsKey(
                        gridIndex,
                      );

                      Color bg;
                      Color text;
                      Border? border;

                      if (isCurrent) {
                        bg = const Color(0xFF28B79B);
                        text = Colors.white;
                      } else if (isAnswered) {
                        bg = const Color(0xFFE6F7F4);
                        text = const Color(0xFF28B79B);
                        border = Border.all(
                          color: const Color(0xFF28B79B),
                          width: 1.5,
                        );
                      } else {
                        bg = const Color(0xFFF1F5F9);
                        text = const Color(0xFF94A3B8);
                      }

                      return MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _activeQuestionIndex = gridIndex;
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: bg,
                              borderRadius: BorderRadius.circular(8),
                              border: border,
                            ),
                            child: Center(
                              child: Text(
                                '${gridIndex + 1}',
                                style: TextStyle(
                                  color: text,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showSubmitQuizConfirmation(activeQuestions),
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text(
                    'SUBMIT',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      letterSpacing: 1.0,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF28B79B),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuizBottomNavBar(List<QuizQuestion> activeQuestions) {
    final hasPrev = _activeQuestionIndex > 0;
    final hasNext = _activeQuestionIndex < activeQuestions.length - 1;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Go to first: <<
          OutlinedButton(
            onPressed: hasPrev
                ? () {
                    setState(() {
                      _activeQuestionIndex = 0;
                    });
                  }
                : null,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: hasPrev
                    ? const Color(0xFF28B79B)
                    : const Color(0xFFCBD5E1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            child: Text(
              '<<',
              style: TextStyle(
                color: hasPrev
                    ? const Color(0xFF28B79B)
                    : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Prev: < Prev
          OutlinedButton.icon(
            onPressed: hasPrev
                ? () {
                    setState(() {
                      _activeQuestionIndex--;
                    });
                  }
                : null,
            icon: Icon(
              Icons.chevron_left_rounded,
              color: hasPrev ? Colors.white : const Color(0xFF94A3B8),
              size: 18,
            ),
            label: Text(
              'Prev',
              style: TextStyle(
                color: hasPrev ? Colors.white : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              backgroundColor: hasPrev
                  ? const Color(0xFF28B79B)
                  : Colors.transparent,
              side: BorderSide(
                color: hasPrev
                    ? const Color(0xFF28B79B)
                    : const Color(0xFFCBD5E1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
          ),
          const SizedBox(width: 16),

          // Next: After >
          OutlinedButton(
            onPressed: hasNext
                ? () {
                    setState(() {
                      _activeQuestionIndex++;
                    });
                  }
                : null,
            style: OutlinedButton.styleFrom(
              backgroundColor: hasNext
                  ? const Color(0xFF28B79B)
                  : Colors.transparent,
              side: BorderSide(
                color: hasNext
                    ? const Color(0xFF28B79B)
                    : const Color(0xFFCBD5E1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            ),
            child: Row(
              children: [
                Text(
                  'After',
                  style: TextStyle(
                    color: hasNext ? Colors.white : const Color(0xFF94A3B8),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  color: hasNext ? Colors.white : const Color(0xFF94A3B8),
                  size: 18,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Go to last: >>
          OutlinedButton(
            onPressed: hasNext
                ? () {
                    setState(() {
                      _activeQuestionIndex = activeQuestions.length - 1;
                    });
                  }
                : null,
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: hasNext
                    ? const Color(0xFF28B79B)
                    : const Color(0xFFCBD5E1),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            child: Text(
              '>>',
              style: TextStyle(
                color: hasNext
                    ? const Color(0xFF28B79B)
                    : const Color(0xFF94A3B8),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaximizedQuizLayout(
    CourseDetail course,
    LessonDetail lesson,
    List<QuizQuestion> activeQuestions,
    bool isDesktop,
  ) {
    return Column(
      children: [
        _buildExitQuizHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                // Top status bar
                _buildQuizTopBar(activeQuestions),
                const SizedBox(height: 16),
                // Main content: split on desktop, scrollable stacked on mobile
                Expanded(
                  child: isDesktop
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 7,
                              child: _buildQuizActiveQuestionPane(
                                activeQuestions,
                              ),
                            ),
                            const SizedBox(width: 24),
                            SizedBox(
                              width: 320,
                              child: _buildQuizRightSidebarPane(
                                activeQuestions,
                              ),
                            ),
                          ],
                        )
                      : SingleChildScrollView(
                          child: Column(
                            children: [
                              _buildQuizActiveQuestionPane(activeQuestions),
                              const SizedBox(height: 24),
                              _buildQuizRightSidebarPane(activeQuestions),
                            ],
                          ),
                        ),
                ),
                const SizedBox(height: 16),
                // Bottom navigation bar
                _buildQuizBottomNavBar(activeQuestions),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuizTaking(List<QuizQuestion> activeQuestions) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuizTopBar(activeQuestions),
        const SizedBox(height: 16),
        SizedBox(
          height: 480,
          child: _buildQuizActiveQuestionPane(activeQuestions),
        ),
        const SizedBox(height: 16),
        _buildQuizRightSidebarPane(activeQuestions),
        const SizedBox(height: 16),
        _buildQuizBottomNavBar(activeQuestions),
      ],
    );
  }

  Widget _buildQuizReview(List<QuizQuestion> activeQuestions) {
    final attemptIndex = _reviewAttemptIndex!;
    final attempt = _quizAttempts[attemptIndex];
    final answers = _attemptsAnswers[attemptIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review Attempt ${attempt.attemptNumber}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Grade: ${attempt.grade}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF28B79B),
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  _reviewAttemptIndex = null;
                });
              },
              icon: const Icon(Icons.arrow_back, size: 16),
              label: const Text('Back to Dashboard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF475569),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activeQuestions.length,
          itemBuilder: (context, qIndex) {
            final q = activeQuestions[qIndex];
            final correctIndex = q.correctIndex;
            final userIndex = answers[qIndex];
            final isCorrect = userIndex == correctIndex;

            return Container(
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCorrect
                      ? const Color(0xFF86EFAC)
                      : const Color(0xFFFCA5A5),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          'Question ${qIndex + 1}: ${q.questionText}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isCorrect ? Icons.check_circle : Icons.cancel,
                        color: isCorrect
                            ? const Color(0xFF22C55E)
                            : const Color(0xFFEF4444),
                        size: 24,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ...List.generate(q.options.length, (oIndex) {
                    final isCorrectOption = oIndex == correctIndex;
                    final isUserChosenOption = oIndex == userIndex;

                    Color bg = const Color(0xFFF8FAFC);
                    Color border = const Color(0xFFE2E8F0);
                    Color text = const Color(0xFF334155);

                    if (isCorrectOption) {
                      bg = const Color(0xFFDCFCE7); // light green
                      border = const Color(0xFF22C55E);
                      text = const Color(0xFF15803D);
                    } else if (isUserChosenOption && !isCorrect) {
                      bg = const Color(0xFFFEE2E2); // light red
                      border = const Color(0xFFEF4444);
                      text = const Color(0xFFB91C1C);
                    }

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: border,
                          width: (isCorrectOption || isUserChosenOption)
                              ? 1.5
                              : 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCorrectOption
                                    ? const Color(0xFF22C55E)
                                    : (isUserChosenOption
                                          ? const Color(0xFFEF4444)
                                          : Colors.white),
                                border: Border.all(
                                  color: isCorrectOption
                                      ? const Color(0xFF22C55E)
                                      : (isUserChosenOption
                                            ? const Color(0xFFEF4444)
                                            : const Color(0xFFCBD5E1)),
                                  width: 1.5,
                                ),
                              ),
                              child: (isCorrectOption || isUserChosenOption)
                                  ? Icon(
                                      isCorrectOption
                                          ? Icons.check
                                          : Icons.close,
                                      color: Colors.white,
                                      size: 14,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                q.options[oIndex],
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight:
                                      (isCorrectOption || isUserChosenOption)
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  color: text,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                  if (q.explanation != null &&
                      q.explanation!.trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFFE2E8F0)),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.lightbulb_outline_rounded,
                          color: Color(0xFF28B79B),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Explanation:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                q.explanation!,
                                style: const TextStyle(
                                  color: Color(0xFF475569),
                                  fontSize: 13.5,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildNextLessonButton(int nextLessonId, CourseDetail course) {
    String nextLessonTitle = 'Next Lesson';
    for (final s in course.sessions) {
      for (final l in s.lessons) {
        if (l.id == nextLessonId) {
          nextLessonTitle = l.title;
          break;
        }
      }
    }

    return InkWell(
      onTap: () {
        _navigateToLesson(nextLessonId);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFE6F7F4), Color(0xFFF0FAF8)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF28B79B).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'NEXT LESSON',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF28B79B),
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    nextLessonTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E293B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: const BoxDecoration(
                color: Color(0xFF28B79B),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsSection(LessonDetail lesson) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.forum_outlined,
                color: Color(0xFF28B79B),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Discussion (${lesson.comments.length})',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Add Comment Input Form
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: const Color(0xFFE2E8F0),
                radius: 20,
                child: _currentUserAvatar.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _currentUserAvatar,
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Text(
                            _currentUserInitials,
                            style: const TextStyle(
                              color: Color(0xFF64748B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      )
                    : Text(
                        _currentUserInitials,
                        style: const TextStyle(
                          color: Color(0xFF64748B),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8FAFC),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: Color(0xFF28B79B),
                            width: 1.5,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      maxLines: null,
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _commentController,
                      builder: (context, value, child) {
                        if (value.text.trim().isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return ElevatedButton(
                          onPressed: _isPostingComment ? null : _postComment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          child: _isPostingComment
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  'Post comment',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Divider(color: Color(0xFFF1F5F9), height: 1),
          const SizedBox(height: 24),

          // Comments List
          if (lesson.comments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'No comments yet. Be the first to start the discussion!',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            )
          else
            () {
              final parentComments = lesson.comments
                  .where((c) => c.parentCommentId == null)
                  .toList();
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: parentComments.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final comment = parentComments[index];
                  final isOwnComment = comment.userId == _currentUserId;
                  final replies = lesson.comments
                      .where((c) => c.parentCommentId == comment.id)
                      .toList();
                  // Sort replies chronologically (oldest first)
                  replies.sort((a, b) => a.id.compareTo(b.id));

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Parent Comment Container
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFF1F5F9)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: isOwnComment
                                  ? const Color(0xFF28B79B)
                                  : const Color(0xFFE2E8F0),
                              child:
                                  comment.userAvatar != null &&
                                      comment.userAvatar!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        comment.userAvatar!,
                                        width: 36,
                                        height: 36,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Text(
                                                  getInitial(
                                                    formatDisplayName(
                                                      comment.userName,
                                                    ),
                                                  ),
                                                  style: TextStyle(
                                                    color: isOwnComment
                                                        ? Colors.white
                                                        : const Color(
                                                            0xFF64748B,
                                                          ),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                      ),
                                    )
                                  : Text(
                                      getInitial(
                                        formatDisplayName(comment.userName),
                                      ),
                                      style: TextStyle(
                                        color: isOwnComment
                                            ? Colors.white
                                            : const Color(0xFF64748B),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Text(
                                        formatDisplayName(comment.userName),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: isOwnComment
                                              ? const Color(0xFF28B79B)
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                      if (isOwnComment) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 1.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE6F7F4),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'You',
                                            style: TextStyle(
                                              fontSize: 9,
                                              color: Color(0xFF28B79B),
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                      const Spacer(),
                                      if (isOwnComment)
                                        PopupMenuButton<String>(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            side: const BorderSide(
                                              color: Color(0xFFF1F5F9),
                                              width: 1,
                                            ),
                                          ),
                                          color: Colors.white,
                                          elevation: 4,
                                          shadowColor: Colors.black.withOpacity(
                                            0.08,
                                          ),
                                          offset: const Offset(0, 24),
                                          icon: const Icon(
                                            Icons.more_horiz,
                                            size: 18,
                                            color: Color(0xFF94A3B8),
                                          ),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              setState(() {
                                                _editingCommentId = comment.id;
                                                _editCommentController.text =
                                                    comment.content;
                                              });
                                            } else if (value == 'delete') {
                                              _showDeleteConfirmation(
                                                comment.id,
                                              );
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'edit',
                                              height: 38,
                                              child: Row(
                                                children: const [
                                                  Icon(
                                                    Icons.edit_outlined,
                                                    size: 16,
                                                    color: Color(0xFF2563EB),
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Edit',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF334155),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            PopupMenuItem(
                                              value: 'delete',
                                              height: 38,
                                              child: Row(
                                                children: const [
                                                  Icon(
                                                    Icons.delete_outline,
                                                    size: 16,
                                                    color: Color(0xFFEF4444),
                                                  ),
                                                  SizedBox(width: 10),
                                                  Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Color(0xFF334155),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (_editingCommentId == comment.id) ...[
                                    TextField(
                                      controller: _editCommentController,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF28B79B),
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.all(
                                          12,
                                        ),
                                      ),
                                      maxLines: null,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _editingCommentId = null;
                                            });
                                          },
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () =>
                                              _updateComment(comment.id),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF28B79B,
                                            ),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                          ),
                                          child: const Text(
                                            'Save',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ] else ...[
                                    Text(
                                      comment.content,
                                      style: const TextStyle(
                                        color: Color(0xFF334155),
                                        fontSize: 13.5,
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          onTap: () =>
                                              _toggleLikeComment(comment),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                comment.isLiked
                                                    ? Icons.thumb_up
                                                    : Icons.thumb_up_outlined,
                                                size: 14,
                                                color: comment.isLiked
                                                    ? const Color(0xFF28B79B)
                                                    : const Color(0xFF64748B),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${comment.likeCount}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: comment.isLiked
                                                      ? const Color(0xFF28B79B)
                                                      : const Color(0xFF64748B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        GestureDetector(
                                          onTap: () {
                                            setState(() {
                                              if (_replyingToCommentId ==
                                                  comment.id) {
                                                _replyingToCommentId = null;
                                              } else {
                                                _replyingToCommentId =
                                                    comment.id;
                                                _replyCommentController.clear();
                                              }
                                            });
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.reply_outlined,
                                                size: 14,
                                                color: Color(0xFF28B79B),
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                'Reply',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF28B79B),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (_replyingToCommentId == comment.id) ...[
                                    const SizedBox(height: 10),
                                    TextField(
                                      controller: _replyCommentController,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        hintText: 'Write a reply...',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: const BorderSide(
                                            color: Color(0xFF28B79B),
                                          ),
                                        ),
                                        contentPadding: const EdgeInsets.all(
                                          12,
                                        ),
                                      ),
                                      maxLines: null,
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton(
                                          onPressed: () {
                                            setState(() {
                                              _replyingToCommentId = null;
                                            });
                                          },
                                          child: const Text(
                                            'Cancel',
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        ElevatedButton(
                                          onPressed: () =>
                                              _postReply(comment.id),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF28B79B,
                                            ),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                          ),
                                          child: _isPostingReply
                                              ? const SizedBox(
                                                  width: 14,
                                                  height: 14,
                                                  child: CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                )
                                              : const Text(
                                                  'Reply',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Nested Replies List
                      if (replies.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ...replies.map((reply) {
                          final isOwnReply = reply.userId == _currentUserId;
                          return Container(
                            margin: const EdgeInsets.only(left: 44, bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: const Color(0xFFF1F5F9),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isOwnReply
                                      ? const Color(0xFF28B79B)
                                      : const Color(0xFFE2E8F0),
                                  child:
                                      reply.userAvatar != null &&
                                          reply.userAvatar!.isNotEmpty
                                      ? ClipOval(
                                          child: Image.network(
                                            reply.userAvatar!,
                                            width: 28,
                                            height: 28,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    Text(
                                                      getInitial(
                                                        formatDisplayName(
                                                          reply.userName,
                                                        ),
                                                      ),
                                                      style: TextStyle(
                                                        color: isOwnReply
                                                            ? Colors.white
                                                            : const Color(
                                                                0xFF64748B,
                                                              ),
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        fontSize: 10,
                                                      ),
                                                    ),
                                          ),
                                        )
                                      : Text(
                                          getInitial(
                                            formatDisplayName(reply.userName),
                                          ),
                                          style: TextStyle(
                                            color: isOwnReply
                                                ? Colors.white
                                                : const Color(0xFF64748B),
                                            fontWeight: FontWeight.bold,
                                            fontSize: 10,
                                          ),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            formatDisplayName(reply.userName),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                              color: isOwnReply
                                                  ? const Color(0xFF28B79B)
                                                  : const Color(0xFF1E293B),
                                            ),
                                          ),
                                          if (isOwnReply) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                    vertical: 1,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE6F7F4),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'You',
                                                style: TextStyle(
                                                  fontSize: 8,
                                                  color: Color(0xFF28B79B),
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          if (isOwnReply)
                                            PopupMenuButton<String>(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                side: const BorderSide(
                                                  color: Color(0xFFF1F5F9),
                                                  width: 1,
                                                ),
                                              ),
                                              color: Colors.white,
                                              elevation: 4,
                                              shadowColor: Colors.black
                                                  .withOpacity(0.08),
                                              offset: const Offset(0, 16),
                                              onSelected: (value) {
                                                if (value == 'edit') {
                                                  setState(() {
                                                    _editingCommentId =
                                                        reply.id;
                                                    _editCommentController
                                                            .text =
                                                        reply.content;
                                                  });
                                                } else if (value == 'delete') {
                                                  _showDeleteConfirmation(
                                                    reply.id,
                                                  );
                                                }
                                              },
                                              itemBuilder: (context) => [
                                                PopupMenuItem(
                                                  value: 'edit',
                                                  height: 32,
                                                  child: Text(
                                                    'Edit',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                PopupMenuItem(
                                                  value: 'delete',
                                                  height: 32,
                                                  child: Text(
                                                    'Delete',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.red,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                              icon: const Icon(
                                                Icons.more_horiz,
                                                size: 14,
                                                color: Color(0xFF94A3B8),
                                              ),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      if (_editingCommentId == reply.id) ...[
                                        TextField(
                                          controller: _editCommentController,
                                          decoration: InputDecoration(
                                            filled: true,
                                            fillColor: Colors.white,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: const BorderSide(
                                                color: Color(0xFF28B79B),
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.all(10),
                                          ),
                                          maxLines: null,
                                          style: const TextStyle(fontSize: 12),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.end,
                                          children: [
                                            TextButton(
                                              onPressed: () {
                                                setState(() {
                                                  _editingCommentId = null;
                                                });
                                              },
                                              child: const Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                            ElevatedButton(
                                              onPressed: () =>
                                                  _updateComment(reply.id),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(
                                                  0xFF28B79B,
                                                ),
                                                elevation: 0,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 6,
                                                    ),
                                              ),
                                              child: const Text(
                                                'Save',
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ] else
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              reply.content,
                                              style: const TextStyle(
                                                color: Color(0xFF334155),
                                                fontSize: 12.5,
                                                height: 1.4,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            GestureDetector(
                                              onTap: () =>
                                                  _toggleLikeComment(reply),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    reply.isLiked
                                                        ? Icons.thumb_up
                                                        : Icons
                                                              .thumb_up_outlined,
                                                    size: 13,
                                                    color: reply.isLiked
                                                        ? const Color(
                                                            0xFF28B79B,
                                                          )
                                                        : const Color(
                                                            0xFF64748B,
                                                          ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    '${reply.likeCount}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: reply.isLiked
                                                          ? const Color(
                                                              0xFF28B79B,
                                                            )
                                                          : const Color(
                                                              0xFF64748B,
                                                            ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ],
                    ],
                  );
                },
              );
            }(),
        ],
      ),
    );
  }

  Widget _buildMarkAsCompletedButton(
    LessonDetail lesson,
    int? nextLessonId,
    CourseDetail course,
  ) {
    final bool isCompleted = lesson.isCompleted;

    if (isCompleted) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFFE6F7F4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF28B79B).withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(
              Icons.check_circle_rounded,
              color: Color(0xFF28B79B),
              size: 20,
            ),
            SizedBox(width: 8),
            Text(
              'Completed',
              style: TextStyle(
                color: Color(0xFF28B79B),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isMarkingCompleted
            ? null
            : () => _markLessonAsCompleted(lesson.id, nextLessonId, course),
        icon: _isMarkingCompleted
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.check_rounded, size: 20),
        label: const Text(
          'Mark as Completed',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF28B79B),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Future<void> _markLessonAsCompleted(
    int lessonId,
    int? nextLessonId,
    CourseDetail course,
  ) async {
    setState(() {
      _isMarkingCompleted = true;
    });
    try {
      await _lessonRepository.completeLesson(lessonId, _currentUserId, true);

      // Update local state
      setState(() {
        if (_lessonDetail != null) {
          _lessonDetail = LessonDetail(
            id: _lessonDetail!.id,
            title: _lessonDetail!.title,
            content: _lessonDetail!.content,
            sectionId: _lessonDetail!.sectionId,
            courseId: _lessonDetail!.courseId,
            comments: _lessonDetail!.comments,
            questions: _lessonDetail!.questions,
            isCompleted: true,
          );
        }
        _isMarkingCompleted = false;
      });

      // Update local course details lesson completed status for sidebar
      if (_courseDetail != null) {
        final updatedSessions = _courseDetail!.sessions.map((session) {
          final updatedLessons = session.lessons.map((l) {
            if (l.id == lessonId) {
              return CourseLesson(
                id: l.id,
                title: l.title,
                orderIndex: l.orderIndex,
                itemType: l.itemType,
                examId: l.examId,
                questionCount: l.questionCount,
                isCompleted: true,
              );
            }
            return l;
          }).toList();
          return CourseSession(
            id: session.id,
            title: session.title,
            orderIndex: session.orderIndex,
            lessons: updatedLessons,
          );
        }).toList();

        setState(() {
          _courseDetail = _courseDetail!.copyWith(sessions: updatedSessions);
        });
      }

      // Show success snackbar
      if (mounted) {
        ToastHelper.showSuccess(context, 'Lesson marked as completed!');
      }

      // Auto-navigate to next lesson if available
      if (nextLessonId != null) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          if (mounted) {
            _navigateToLesson(nextLessonId);
          }
        });
      }
    } catch (e) {
      setState(() {
        _isMarkingCompleted = false;
      });
      if (mounted) {
        ToastHelper.showError(context, 'Failed to complete lesson: $e');
      }
    }
  }
}

class QuizAttempt {
  final int attemptNumber;
  final String state;
  final String grade;
  final String submittedTime;

  QuizAttempt({
    required this.attemptNumber,
    required this.state,
    required this.grade,
    required this.submittedTime,
  });
}
