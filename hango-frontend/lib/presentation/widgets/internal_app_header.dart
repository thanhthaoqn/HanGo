import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../../../domain/model/notification_item.dart';
import '../../../data/repositories/notification_repository.dart';
import '../pages/login_page.dart';
import '../pages/learner/learner_home_page.dart';
import '../pages/trainer/trainer_profile_page.dart';
import '../pages/trainer/trainer_shell_page.dart';
import '../pages/course_manager/course_manager_my_information_page.dart';
import '../pages/trainer/onboarding/trainer_onboarding_shell_page.dart';
import '../pages/trainer/onboarding/trainer_onboarding_details_page.dart';
import '../pages/trainer/onboarding/trainer_onboarding_agreement_page.dart';
import '../pages/trainer/onboarding/trainer_type_selection_page.dart';
import '../pages/trainer/onboarding/trainer_onboarding_status_page.dart';
import '../../../data/services/trainer_onboarding_service.dart';
import '../../utils/toast_helper.dart';
import '../../utils/language_manager.dart';

class InternalAppHeader extends StatefulWidget implements PreferredSizeWidget {
  final bool isMobile;
  final VoidCallback? onMenuPressed;
  final String activeTab; // Kept for compatibility if needed
  final bool showLogo;

  const InternalAppHeader({
    Key? key,
    this.isMobile = false,
    this.onMenuPressed,
    this.activeTab = '',
    this.showLogo = true,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(70);

  @override
  State<InternalAppHeader> createState() => _InternalAppHeaderState();
}

class _InternalAppHeaderState extends State<InternalAppHeader> {
  final _authService = AuthService();
  final _notificationRepository = NotificationRepository();

  bool _isLoggedIn = false;
  String _userFullName = 'User';
  String _userInitials = 'U';
  String _userAvatarUrl = '';
  List<String> _userRoles = [];
  
  List<NotificationItem> _notifications = [];
  int _unreadNotificationCount = 0;
  bool _isLoadingNotifications = false;
  StateSetter? _popupSetState;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token');

    if (token == null) {
      if (mounted) setState(() => _isLoggedIn = false);
      return;
    }

    final fullName = prefs.getString('user_fullname') ?? 'User';
    final avatarUrl = prefs.getString('user_avatar_url') ?? '';
    final roles = prefs.getStringList('user_roles') ?? [];

    String initials = 'U';
    if (fullName.trim().isNotEmpty) {
      final parts = fullName.trim().split(' ');
      if (parts.isNotEmpty) {
        initials = parts.last[0].toUpperCase();
      }
    }

    if (mounted) {
      setState(() {
        _isLoggedIn = true;
        _userFullName = fullName;
        _userInitials = initials;
        _userAvatarUrl = avatarUrl;
        _userRoles = roles;
      });
      _loadNotifications();
    }
  }

  String get _displayRole {
    if (_userRoles.contains('ROLE_ADMINISTRATOR') || _userRoles.contains('ADMINISTRATOR')) return 'Admin';
    if (_userRoles.contains('ROLE_TRAINER') || _userRoles.contains('TRAINER')) return 'Trainer';
    if (_userRoles.contains('ROLE_COURSE_MANAGER') || _userRoles.contains('COURSE_MANAGER')) return 'Course Manager';
    if (_userRoles.contains('ROLE_LEARNER') || _userRoles.contains('LEARNER')) return 'Learner';
    return 'Staff';
  }

  void _updatePopup() {
    if (_popupSetState == null) return;
    try {
      _popupSetState!(() {});
    } catch (_) {
      _popupSetState = null;
    }
  }

  Future<void> _loadNotifications() async {
    if (_isLoadingNotifications) return;
    setState(() => _isLoadingNotifications = true);
    _updatePopup();
    try {
      final notifications = await _notificationRepository.getNotifications();
      final unreadCount = await _notificationRepository.getUnreadCount();
      if (!mounted) return;
      setState(() {
        _notifications = notifications;
        _unreadNotificationCount = unreadCount;
        _isLoadingNotifications = false;
      });
      _updatePopup();
    } catch (_) {
      if (mounted) setState(() => _isLoadingNotifications = false);
      _updatePopup();
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
        _unreadNotificationCount =
            _unreadNotificationCount > 0 ? _unreadNotificationCount - 1 : 0;
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

  void _navigateToProfile() async {
    if (TrainerOnboardingShellPage.of(context) != null) {
      ToastHelper.showInfo(
        context,
        LanguageManager.isVi
            ? 'Vui lòng hoàn tất nộp hồ sơ Trainer trước khi truy cập trang Profile chính thức.'
            : 'Please complete your Trainer onboarding application before accessing the full Profile.',
      );
      return;
    }

    if (_userRoles.contains('ROLE_COURSE_MANAGER') || _userRoles.contains('COURSE_MANAGER')) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
            builder: (context) => const CourseManagerMyInformationPage()),
      );
    } else if (_userRoles.contains('ROLE_TRAINER') || _userRoles.contains('TRAINER')) {
      final onboardingService = TrainerOnboardingService();
      final res = await onboardingService.getTrainerProfile();
      if (res['success'] == true) {
        final data = res['data'] ?? {};
        final status = (data['status'] ?? '').toString().toUpperCase();
        final agreementSigned = data['agreementSigned'] ?? false;
        final trainerType = data['trainerType'];

        if (status == 'ONBOARDING' || status == 'DRAFT' || status == 'REJECTED' || status == 'PENDING_VERIFICATION' || status.isEmpty) {
          if (mounted) {
            Widget initialBody;
            if (trainerType == null) {
              initialBody = const TrainerTypeSelectionPage(isEmbedded: true);
            } else if (agreementSigned != true) {
              initialBody = TrainerOnboardingAgreementPage(
                profilePayload: data,
                trainerType: trainerType,
                isEmbedded: true,
              );
            } else {
              initialBody = TrainerOnboardingDetailsPage(initialProfile: data, isEmbedded: true);
            }

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TrainerOnboardingShellPage(
                  initialBody: initialBody,
                ),
              ),
            );
          }
          return;
        } else if (status == 'AWAITING_APPROVAL' || status == 'PENDING_REVIEW' || status == 'SUSPENDED') {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TrainerOnboardingShellPage(
                  initialBody: TrainerOnboardingStatusPage(initialProfile: data, isEmbedded: true),
                ),
              ),
            );
          }
          return;
        }
      }

      if (mounted) {
        final shell = TrainerShellPage.of(context);
        if (shell != null) {
          shell.selectTab(5);
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const TrainerProfilePage()),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.preferredSize.height,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
      ),
      child: Row(
        children: [
          if (widget.isMobile) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: Color(0xFF64748B)),
              onPressed: widget.onMenuPressed ?? () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 8),
          ],
          if (widget.showLogo)
            InkWell(
              onTap: () {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LearnerHomePage()),
                  (route) => false,
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.network(
                    'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
                    height: 36,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE6FFFA),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.school,
                              size: 18,
                              color: Color(0xFF28B79B),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'HanGo',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          const Spacer(),
          // Notification Bell
          Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              PopupMenuButton<void>(
                offset: const Offset(0, 50),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                onOpened: _loadNotifications,
                icon: const Icon(
                  Icons.notifications_none_outlined,
                  color: Color(0xFF4B5563),
                  size: 26,
                ),
                itemBuilder: (context) => [
                  PopupMenuItem<void>(
                    enabled: false,
                    child: StatefulBuilder(
                      builder: (context, setMenuState) {
                        _popupSetState = setMenuState;
                        return Container(
                          width: 320,
                          constraints: const BoxConstraints(maxHeight: 420),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
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
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF20B486),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_isLoadingNotifications)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(
                                        color: Color(0xFF20B486)),
                                  ),
                                )
                              else if (_notifications.isEmpty)
                                const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24.0),
                                    child: Text(
                                      'No notifications',
                                      style: TextStyle(color: Color(0xFF64748B)),
                                    ),
                                  ),
                                )
                              else
                                Flexible(
                                  child: ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: _notifications.length,
                                    itemBuilder: (context, index) {
                                      final notif = _notifications[index];
                                      return ListTile(
                                        contentPadding: const EdgeInsets.symmetric(
                                            horizontal: 8),
                                        leading: CircleAvatar(
                                          backgroundColor: notif.read
                                              ? const Color(0xFFF1F5F9)
                                              : const Color(0xFFE6F7F2),
                                          child: Icon(
                                            Icons.notifications_active_outlined,
                                            color: notif.read
                                                ? const Color(0xFF94A3B8)
                                                : const Color(0xFF20B486),
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(
                                          notif.title,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: notif.read
                                                ? FontWeight.normal
                                                : FontWeight.w600,
                                            color: const Color(0xFF0F172A),
                                          ),
                                        ),
                                        subtitle: Text(
                                          '${notif.message}\n${_formatNotificationTime(notif.createdAt)}',
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF64748B)),
                                        ),
                                        onTap: () {
                                          _markNotificationAsRead(notif);
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (_unreadNotificationCount > 0)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                    alignment: Alignment.center,
                    child: Text(
                      _unreadNotificationCount > 99
                          ? '99+'
                          : '$_unreadNotificationCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          // User Profile Pill Button
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'profile') {
                _navigateToProfile();
              } else if (val == 'logout') {
                _handleLogout();
              }
            },
            offset: const Offset(0, 56),
            color: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Row(
                  children: const [
                    Icon(Icons.person_outline,
                        size: 18, color: Color(0xFF64748B)),
                    SizedBox(width: 10),
                    Text('My Profile',
                        style: TextStyle(
                            fontFamily: 'Outfit', fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: const [
                    Icon(Icons.logout, size: 18, color: Colors.redAccent),
                    SizedBox(width: 10),
                    Text('Logout',
                        style: TextStyle(
                            fontFamily: 'Outfit',
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE2E8F0)),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF20B486),
                    backgroundImage: _userAvatarUrl.isNotEmpty
                        ? NetworkImage(_userAvatarUrl)
                        : null,
                    child: _userAvatarUrl.isEmpty
                        ? Text(
                            _userInitials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _userFullName,
                        style: const TextStyle(
                          color: Color(0xFF1E293B),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F7F2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _displayRole,
                          style: const TextStyle(
                            color: Color(0xFF20B486),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Color(0xFF64748B),
                    size: 18,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
