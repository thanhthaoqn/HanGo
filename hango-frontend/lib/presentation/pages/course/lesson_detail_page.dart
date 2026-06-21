import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../../domain/model/course_detail.dart';
import '../../../domain/model/lesson_detail.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/ai_assistant_drawer.dart';

class LessonDetailPage extends StatefulWidget {
  final int courseId;
  final int lessonId;

  const LessonDetailPage({
    Key? key,
    required this.courseId,
    required this.lessonId,
  }) : super(key: key);

  @override
  State<LessonDetailPage> createState() => _LessonDetailPageState();
}

class _LessonDetailPageState extends State<LessonDetailPage> {
  final CourseRepository _courseRepository = CourseRepository();
  final LessonRepository _lessonRepository = LessonRepository();
  
  late Future<CourseDetail> _courseDetailFuture;
  late Future<LessonDetail> _lessonDetailFuture;
  
  int _currentUserId = 1; // Default
  int? _editingCommentId;
  final TextEditingController _editCommentController = TextEditingController();
  
  bool _isAIAssistantOpen = false;
  final TextEditingController _commentController = TextEditingController();
  bool _isPostingComment = false;

  @override
  void initState() {
    super.initState();
    _courseDetailFuture = _courseRepository.fetchCourseDetail(widget.courseId);
    _lessonDetailFuture = _lessonRepository.fetchLessonDetail(widget.lessonId);
    _loadCurrentUserId();
  }

  Future<void> _loadCurrentUserId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentUserId = prefs.getInt('user_id') ?? 1;
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
      await _lessonRepository.postComment(widget.lessonId, _currentUserId, _commentController.text.trim());
      _commentController.clear();
      setState(() {
        _lessonDetailFuture = _lessonRepository.fetchLessonDetail(widget.lessonId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to post comment: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() {
        _isPostingComment = false;
      });
    }
  }

  Future<void> _updateComment(int commentId) async {
    if (_editCommentController.text.trim().isEmpty) return;
    
    try {
      await _lessonRepository.updateComment(commentId, _currentUserId, _editCommentController.text.trim());
      setState(() {
        _editingCommentId = null;
        _lessonDetailFuture = _lessonRepository.fetchLessonDetail(widget.lessonId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update comment: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      await _lessonRepository.deleteComment(commentId, _currentUserId);
      setState(() {
        _lessonDetailFuture = _lessonRepository.fetchLessonDetail(widget.lessonId);
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete comment: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showDeleteConfirmation(int commentId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Comment'),
        content: const Text('Are you sure you want to delete this comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteComment(commentId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
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

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: SharedHeader(isDesktop: isDesktop, activeTab: 'Courses'),
      body: FutureBuilder(
        future: Future.wait([_courseDetailFuture, _lessonDetailFuture]),
        builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF28B79B)));
          } else if (snapshot.hasError) {
            return Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text('An error occurred: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(child: Text('Data not found.'));
          }

          final CourseDetail course = snapshot.data![0];
          final LessonDetail lesson = snapshot.data![1];

          // Determine current session title for breadcrumbs
          String? sessionTitle;
          for (final s in course.sessions) {
            if (s.lessons.any((l) => l.id == lesson.id)) {
              sessionTitle = s.title;
              break;
            }
          }

          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Sidebar
                  if (isDesktop)
                    Container(
                      width: 320,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(right: BorderSide(color: Colors.grey.shade200)),
                      ),
                      child: _buildSidebar(course),
                    ),
                    
                  // Main Content
                  Expanded(
                    child: Column(
                      children: [
                        // Sub-header Breadcrumb
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
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
                                  child: const Icon(Icons.arrow_back, size: 16, color: Color(0xFF475569)),
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
                        
                        // Scrollable Content
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(32.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildLessonContent(course, lesson),
                                      const SizedBox(height: 32),
                                      _buildCommentsSection(lesson),
                                    ],
                                  ),
                                ),
                                // Spacer if AI Assistant is open on smaller screen
                                if (_isAIAssistantOpen && !isDesktop) 
                                  const SizedBox(width: 320),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // AI Assistant Drawer (Inline for Desktop if opened)
                  if (isDesktop && _isAIAssistantOpen)
                    AIAssistantDrawer(onClose: _toggleAIAssistant),
                ],
              ),
              
              // Floating AI Button
              if (!_isAIAssistantOpen)
                Positioned(
                  right: 24,
                  bottom: 24,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF28B79B).withOpacity(0.3),
                          blurRadius: 16,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: FloatingActionButton(
                      onPressed: _toggleAIAssistant,
                      backgroundColor: Colors.white,
                      elevation: 4,
                      shape: const CircleBorder(),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/images/robot_logo.png',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const CircleAvatar(
                                backgroundColor: Color(0xFF28B79B),
                                child: Icon(Icons.smart_toy_outlined, color: Colors.white),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
              // Overlay AI Drawer for Mobile/Tablet
              if (!isDesktop && _isAIAssistantOpen)
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: _toggleAIAssistant,
                        child: Container(
                          width: MediaQuery.of(context).size.width - 320,
                          color: Colors.black12,
                        ),
                      ),
                      AIAssistantDrawer(onClose: _toggleAIAssistant),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
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
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: course.sessions.length,
      itemBuilder: (context, index) {
        final session = course.sessions[index];
        return Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: session.lessons.any((l) => l.id == widget.lessonId),
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
              final isCurrent = l.id == widget.lessonId;
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent ? const Color(0xFFE6F7F4) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(
                    _getLessonIcon(l.itemType),
                    color: isCurrent ? const Color(0xFF28B79B) : const Color(0xFF94A3B8),
                    size: 20,
                  ),
                  title: Text(
                    l.title,
                    style: TextStyle(
                      fontSize: 13,
                      color: isCurrent ? const Color(0xFF28B79B) : const Color(0xFF475569),
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                  onTap: () {
                    if (!isCurrent) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LessonDetailPage(
                            courseId: widget.courseId,
                            lessonId: l.id,
                          ),
                        ),
                      );
                    }
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
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
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                // HTML Content Rendering
                lesson.content.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            'Lesson content is currently being updated...',
                            style: TextStyle(fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
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
                          "li": Style(
                            margin: Margins.only(bottom: 8.0),
                          ),
                          "blockquote": Style(
                            backgroundColor: const Color(0xFFF8FAFC),
                            border: const Border(left: BorderSide(color: Color(0xFF28B79B), width: 4)),
                            padding: HtmlPaddings.symmetric(horizontal: 16, vertical: 12),
                            margin: Margins.only(bottom: 16),
                          ),
                          "code": Style(
                            backgroundColor: const Color(0xFFF1F5F9),
                            color: const Color(0xFFE11D48),
                            padding: HtmlPaddings.symmetric(horizontal: 6, vertical: 2),
                          ),
                        },
                      ),
                if (nextLessonId != null) ...[
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
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => LessonDetailPage(
              courseId: widget.courseId,
              lessonId: nextLessonId,
            ),
          ),
        );
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
              const Icon(Icons.forum_outlined, color: Color(0xFF28B79B), size: 24),
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
                child: const Icon(Icons.person_outline, color: Color(0xFF64748B)),
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
                        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
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
                          borderSide: const BorderSide(color: Color(0xFF28B79B), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      maxLines: null,
                    ),
                    const SizedBox(height: 12),
                    ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _commentController,
                      builder: (context, value, child) {
                        if (value.text.trim().isEmpty) return const SizedBox.shrink();
                        return ElevatedButton(
                          onPressed: _isPostingComment ? null : _postComment,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: _isPostingComment
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Text(
                                  'Post comment',
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
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
                  style: TextStyle(color: Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lesson.comments.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final comment = lesson.comments[index];
                final isOwnComment = comment.userId == _currentUserId;

                return Container(
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
                        backgroundColor: isOwnComment ? const Color(0xFF28B79B) : const Color(0xFFE2E8F0),
                        backgroundImage: comment.userAvatar != null ? NetworkImage(comment.userAvatar!) : null,
                        child: comment.userAvatar == null
                            ? Text(
                                comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: isOwnComment ? Colors.white : const Color(0xFF64748B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  comment.userName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: isOwnComment ? const Color(0xFF28B79B) : const Color(0xFF1E293B),
                                  ),
                                ),
                                if (isOwnComment) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE6F7F4),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'You',
                                      style: TextStyle(fontSize: 9, color: Color(0xFF28B79B), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                if (isOwnComment)
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_horiz, size: 16, color: Color(0xFF94A3B8)),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onSelected: (value) {
                                      if (value == 'edit') {
                                        setState(() {
                                          _editingCommentId = comment.id;
                                          _editCommentController.text = comment.content;
                                        });
                                      } else if (value == 'delete') {
                                        _showDeleteConfirmation(comment.id);
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Row(
                                          children: [
                                            Icon(Icons.edit_outlined, size: 16, color: Colors.blue),
                                            SizedBox(width: 8),
                                            Text('Edit', style: TextStyle(fontSize: 13)),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: Row(
                                          children: [
                                            Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Delete', style: TextStyle(fontSize: 13)),
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
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(color: Color(0xFF28B79B)),
                                  ),
                                  contentPadding: const EdgeInsets.all(12),
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
                                    child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 13)),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () => _updateComment(comment.id),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF28B79B),
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    ),
                                    child: const Text('Save', style: TextStyle(color: Colors.white, fontSize: 13)),
                                  ),
                                ],
                              )
                            ] else
                              Text(
                                comment.content,
                                style: const TextStyle(color: Color(0xFF334155), fontSize: 13.5, height: 1.4),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
