import 'package:flutter/material.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'trainer_dashboard_page.dart';
import 'trainer_courses_page.dart';
import 'trainer_exams_page.dart';
import 'question_bank/trainer_question_bank_page.dart';
import 'trainer_revenue_page.dart';
import 'trainer_profile_page.dart';
import 'trainer_tickets_page.dart';
import '../../widgets/trainer/trainer_sidebar.dart';
import '../../../domain/model/notification_item.dart';
import '../../../data/repositories/notification_repository.dart';

class TrainerShellPage extends StatefulWidget {
  final int initialIndex;
  const TrainerShellPage({super.key, this.initialIndex = 0});

  static TrainerShellPageState? of(BuildContext context) {
    return context.findAncestorStateOfType<TrainerShellPageState>();
  }

  @override
  State<TrainerShellPage> createState() => TrainerShellPageState();
}

class TrainerShellPageState extends State<TrainerShellPage> {
  late int _currentIndex;

  String _trainerName = 'Trainer';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  final _notificationRepository = NotificationRepository();
  List<NotificationItem> _notifications = [];
  int _unreadNotificationCount = 0;
  bool _isLoadingNotifications = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _loadHeaderInfo();
    _loadNotifications();
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
    if (mounted) {
      setState(() {
        _trainerName = fullName;
        _trainerInitials = initials;
        _trainerAvatarUrl = avatarUrl;
      });
    }
  }

  void selectTab(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  Future<void> _loadNotifications() async {
    try {
      final notifications = await _notificationRepository.getNotifications();
      final unreadCount = await _notificationRepository.getUnreadCount();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _unreadNotificationCount = unreadCount;
      });
    } catch (_) {
    }
  }

  Future<void> _markNotificationAsRead(NotificationItem notification) async {
    if (notification.read) return;
    try {
      await _notificationRepository.markAsRead(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => n.id == notification.id
                ? NotificationItem(
                    id: n.id,
                    type: n.type,
                    title: n.title,
                    message: n.message,
                    courseId: n.courseId,
                    courseTitle: n.courseTitle,
                    read: true,
                    createdAt: n.createdAt,
                  )
                : n)
            .toList();
        _unreadNotificationCount = _unreadNotificationCount > 0 ? _unreadNotificationCount - 1 : 0;
      });
    } catch (_) {}
  }

  Future<void> _markAllNotificationsAsRead() async {
    try {
      await _notificationRepository.markAllAsRead();
      if (!mounted) return;
      setState(() {
        _notifications = _notifications
            .map((n) => NotificationItem(
                  id: n.id,
                  type: n.type,
                  title: n.title,
                  message: n.message,
                  courseId: n.courseId,
                  courseTitle: n.courseTitle,
                  read: true,
                  createdAt: n.createdAt,
                ))
            .toList();
        _unreadNotificationCount = 0;
      });
    } catch (_) {}
  }

  String _formatNotificationTime(DateTime? createdAt) {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }

  IconData _notificationIcon(String type) {
    switch (type) {
      case 'PurchaseSuccess': return Icons.shopping_bag_outlined;
      case 'NewEnrollment': return Icons.school_outlined;
      case 'CommentReply': return Icons.chat_bubble_outline;
      case 'ContentApproved': return Icons.check_circle_outline;
      case 'ContentRejected': return Icons.cancel_outlined;
      case 'CourseUpdated': return Icons.upgrade_outlined;
      default: return Icons.notifications_outlined;
    }
  }

  Widget _buildNotificationItem({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String description,
    required String time,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFF1E293B)),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? Drawer(child: TrainerSidebar(activeIndex: _currentIndex, onTabSelect: (idx) => selectTab(idx))) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 250, child: TrainerSidebar(activeIndex: _currentIndex, onTabSelect: (idx) => selectTab(idx))),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InternalAppHeader(isMobile: !isDesktop, showLogo: !isDesktop),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: const [
                      TrainerDashboardPage(isEmbedded: true),
                      TrainerCoursesPage(isEmbedded: true),
                      TrainerExamsPage(isEmbedded: true),
                      TrainerQuestionBankPage(isEmbedded: true),
                      TrainerRevenuePage(isEmbedded: true),
                      TrainerProfilePage(isEmbedded: true),
                      TrainerTicketsPage(isEmbedded: true),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _unusedLegacyHeader(bool isMobile) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0), width: 1)),
      ),
      child: Row(
        children: [
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF64748B)),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          const Spacer(),
          // Notification Bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              PopupMenuButton<void>(
                offset: const Offset(0, 50),
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                onOpened: _loadNotifications,
                icon: const Icon(
                  Icons.notifications_none_outlined,
                  color: Color(0xFF4B5563),
                  size: 24,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem<void>(
                    enabled: false,
                    child: StatefulBuilder(
                      builder: (context, setMenuState) => Container(
                        width: 320,
                        constraints: const BoxConstraints(maxHeight: 420),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Notifications',
                                    style: TextStyle(
                                      fontFamily: 'Outfit',
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                  if (_unreadNotificationCount > 0)
                                    InkWell(
                                      onTap: () async {
                                        await _markAllNotificationsAsRead();
                                        setMenuState(() {});
                                      },
                                      child: const Text(
                                        'Mark all as read',
                                        style: TextStyle(fontSize: 12, color: Color(0xFF28B79B), fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            const Divider(height: 1, color: Color(0xFFE2E8F0)),
                            if (_isLoadingNotifications)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 32),
                                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            else if (_notifications.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 24),
                                child: Column(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: const BoxDecoration(color: Color(0xFFF8FAFC), shape: BoxShape.circle),
                                      child: const Icon(Icons.notifications_off_outlined, size: 40, color: Color(0xFF94A3B8)),
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No new notifications',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: 'Outfit',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Flexible(
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  padding: const EdgeInsets.only(top: 12),
                                  itemCount: _notifications.length,
                                  separatorBuilder: (_, __) => const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 10),
                                    child: Divider(height: 1, color: Color(0xFFF1F5F9)),
                                  ),
                                  itemBuilder: (context, index) {
                                    final n = _notifications[index];
                                    return InkWell(
                                      onTap: () async {
                                        await _markNotificationAsRead(n);
                                        setMenuState(() {});
                                      },
                                      child: Container(
                                        color: n.read ? Colors.transparent : const Color(0xFFF0FDFA),
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                        child: _buildNotificationItem(
                                          icon: _notificationIcon(n.type),
                                          iconColor: const Color(0xFF28B79B),
                                          bgColor: const Color(0xFFE6FBF7),
                                          title: n.title,
                                          description: n.message,
                                          time: _formatNotificationTime(n.createdAt),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
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
}
