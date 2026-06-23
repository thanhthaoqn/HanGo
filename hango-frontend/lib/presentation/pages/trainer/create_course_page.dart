// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/services/auth_service.dart';
import '../login_page.dart';
import 'trainer_courses_page.dart';
import 'trainer_dashboard_page.dart';

class CreateCoursePage extends StatefulWidget {
  const CreateCoursePage({super.key});

  @override
  State<CreateCoursePage> createState() => _CreateCoursePageState();
}

class _CreateCoursePageState extends State<CreateCoursePage> {
  final _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  
  String _trainerName = 'Thảo';
  String _trainerInitials = 'T';

  // Form values
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedCategory = 'Grammar';
  String _selectedLevel = 'Beginner';
  bool _isSaving = false;

  final List<String> _categories = ['Grammar', 'Vocabulary', 'Listening', 'Reading', 'Writing', 'Speaking'];
  final List<String> _levels = ['Beginner', 'Intermediate', 'Advanced'];

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadTrainerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Thảo';
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
    });
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

  void _saveCourse() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Simulate saving delay
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        
        // Show success Snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course created successfully! (Mocked)'),
            backgroundColor: Color(0xFF20B486),
          ),
        );
        
        // Navigate back to Courses list
        Navigator.pop(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 240, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildTitleSection(),
                          const SizedBox(height: 24),
                          if (isDesktop)
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(flex: 2, child: _buildGeneralInfoCard()),
                                const SizedBox(width: 24),
                                Expanded(flex: 1, child: _buildMediaCard()),
                              ],
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _buildGeneralInfoCard(),
                                const SizedBox(height: 24),
                                _buildMediaCard(),
                              ],
                            ),
                          const SizedBox(height: 32),
                          _buildActionsRow(),
                        ],
                      ),
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

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: Row(
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
                    color: Color(0xFF20B486),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'HanGo',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
          // Sidebar menu items
          _buildSidebarItem(Icons.dashboard_outlined, 'Dashboard', onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerDashboardPage()),
            );
          }),
          _buildSidebarItem(Icons.book_outlined, 'Courses', isActive: true, onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const TrainerCoursesPage()),
            );
          }),
          _buildSidebarItem(Icons.assignment_outlined, 'Exam'),
          _buildSidebarItem(Icons.people_outline, 'Learner'),
          _buildSidebarItem(Icons.question_answer_outlined, 'Question Bank'),
          _buildSidebarItem(Icons.task_alt_outlined, 'Task'),
          const Spacer(),
          const Divider(color: Color(0xFFE2E8F0)),
          const SizedBox(height: 12),
          _buildSidebarItem(Icons.help_outline, 'Help Center', onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Help Center is under construction')),
            );
          }),
          _buildSidebarItem(Icons.logout, 'Logout', color: Colors.redAccent, onTap: _handleLogout),
        ],
      ),
    );
  }

  Widget _buildSidebarItem(IconData icon, String title, {bool isActive = false, Color? color, VoidCallback? onTap}) {
    final activeColor = const Color(0xFF20B486);
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
              Icon(
                icon,
                color: isActive ? Colors.white : (color ?? const Color(0xFF4B5563)),
                size: 20,
              ),
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
          // Breadcrumb
          Row(
            children: [
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: const Text(
                  'Courses',
                  style: TextStyle(
                    color: Color(0xFF20B486),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF94A3B8)),
              const SizedBox(width: 4),
              const Text(
                'Create New Course',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const Spacer(),
          // Notifications
          Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(
                  Icons.notifications_none_outlined,
                  color: Color(0xFF4B5563),
                  size: 24,
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications')),
                  );
                },
              ),
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          // User Profile Info
          Row(
            children: [
              Text(
                _trainerName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                  fontSize: 14,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2F9F3),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _trainerInitials,
                  style: const TextStyle(
                    color: Color(0xFF20B486),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF20B486),
                  shape: BoxShape.circle,
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return const Text(
      'Create New Course',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: Color(0xFF1E293B),
        fontFamily: 'Outfit',
      ),
    );
  }

  Widget _buildGeneralInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.01),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: const [
              Icon(Icons.info_outline, color: Color(0xFF20B486), size: 20),
              SizedBox(width: 8),
              Text(
                'General Information',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF20B486),
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Course Title Field
          const Text(
            'Course Title',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter title of course....',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF20B486)),
              ),
            ),
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a course title';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          // Category & Academic Level side-by-side
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Category',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF20B486)),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF1E293B)),
                      items: _categories.map((String category) {
                        return DropdownMenuItem<String>(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCategory = newValue;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Academic Level',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B5563),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _selectedLevel,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Color(0xFF20B486)),
                        ),
                      ),
                      style: const TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF1E293B)),
                      items: _levels.map((String level) {
                        return DropdownMenuItem<String>(
                          value: level,
                          child: Text(level),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedLevel = newValue;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Course Description
          const Text(
            'Course Description',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descriptionController,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: 'Enter course description......',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF20B486)),
              ),
            ),
            style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a course description';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMediaCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFF2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.01),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Row(
            children: const [
              Icon(Icons.photo_library_outlined, color: Color(0xFF20B486), size: 20),
              SizedBox(width: 8),
              Text(
                'Course Media',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF20B486),
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Course Thumbnail Label
          const Text(
            'Course Thumbnail',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 12),
          // Dotted Upload Box
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Media picker is under construction (Mocked)')),
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: CustomPaint(
              painter: DashedBorderPainter(
                color: const Color(0xFFCBD5E1),
                borderRadius: 12,
              ),
              child: Container(
                width: double.infinity,
                height: 180,
                padding: const EdgeInsets.all(20),
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.cloud_upload_outlined,
                      color: Color(0xFF64748B),
                      size: 40,
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Click to upload or drag & drop',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                        fontFamily: 'Outfit',
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Recommended: 1280x720\n(PNG/JPG)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                        fontFamily: 'Outfit',
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        ElevatedButton(
          onPressed: _isSaving ? null : _saveCourse,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF20B486),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Save',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    fontFamily: 'Outfit',
                  ),
                ),
        ),
      ],
    );
  }
}

class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.dashWidth = 6.0,
    this.dashSpace = 4.0,
    this.borderRadius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final double w = size.width;
    final double h = size.height;

    // Top border
    double x = 0;
    while (x < w) {
      canvas.drawLine(Offset(x, 0), Offset(x + dashWidth > w ? w : x + dashWidth, 0), paint);
      x += dashWidth + dashSpace;
    }

    // Bottom border
    x = 0;
    while (x < w) {
      canvas.drawLine(Offset(x, h), Offset(x + dashWidth > w ? w : x + dashWidth, h), paint);
      x += dashWidth + dashSpace;
    }

    // Left border
    double y = 0;
    while (y < h) {
      canvas.drawLine(Offset(0, y), Offset(0, y + dashWidth > h ? h : y + dashWidth), paint);
      y += dashWidth + dashSpace;
    }

    // Right border
    y = 0;
    while (y < h) {
      canvas.drawLine(Offset(w, y), Offset(w, y + dashWidth > h ? h : y + dashWidth), paint);
      y += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace;
  }
}
