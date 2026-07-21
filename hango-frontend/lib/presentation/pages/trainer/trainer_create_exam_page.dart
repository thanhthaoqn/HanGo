import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../utils/config.dart';
import '../../../data/services/auth_service.dart';
import '../../../utils/file_picker_helper.dart';
import '../../../utils/toast_helper.dart';
import '../login_page.dart';
import 'trainer_dashboard_page.dart';
import 'trainer_courses_page.dart';
import 'trainer_exams_page.dart';
import 'question_bank/trainer_question_bank_page.dart';
import 'trainer_exam_import_excel_page.dart';
import 'trainer_exam_ai_generate_page.dart';
import 'trainer_exam_matrix_page.dart';

class TrainerCreateExamPage extends StatefulWidget {
  const TrainerCreateExamPage({super.key});

  @override
  State<TrainerCreateExamPage> createState() => _TrainerCreateExamPageState();
}

class _TrainerCreateExamPageState extends State<TrainerCreateExamPage> {
  final _formKey = GlobalKey<FormState>();
  final _authService = AuthService();
  String _trainerName = 'Thảo';
  String _trainerInitials = 'T';
  String _trainerAvatarUrl = '';

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _questionsController = TextEditingController();
  final _dateController = TextEditingController();
  final _passingScoreController = TextEditingController();
  final _durationController = TextEditingController();

  bool _isSubmitting = false;
  String _currentView = 'selection';

  // Image Upload state variables
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;
  String _uploadStatusText = '';

  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    // Initialize current date
    final now = DateTime.now();
    _dateController.text = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    _loadTrainerInfo();
  }

  Future<void> _loadTrainerInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final fullName = prefs.getString('user_fullname') ?? 'Thảo';
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _questionsController.dispose();
    _dateController.dispose();
    _passingScoreController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picked = await pickImage();
      if (picked == null) return;

      setState(() {
        _isUploadingImage = true;
        _uploadStatusText = 'Uploading...';
      });

      final url = Uri.parse('https://api.cloudinary.com/v1_1/diqekap4o/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'hango_preset'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          picked.bytes!,
          filename: picked.name,
        ));

      final response = await request.send();
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(responseBody);
        setState(() {
          _uploadedImageUrl = data['secure_url'] ?? data['url'];
          _isUploadingImage = false;
        });
      } else {
        throw Exception('Cloudinary upload failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      setState(() {
        _isUploadingImage = false;
        _uploadStatusText = 'Upload failed';
      });
      if (mounted) {
        ToastHelper.show(context, 'Error uploading image: $e', isError: true);
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) throw Exception('No token found');

      final payload = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'expectedQuestionCount': int.tryParse(_questionsController.text.trim()) ?? 0,
        'passingScore': double.tryParse(_passingScoreController.text.trim()) ?? 0.0,
        'durationMinutes': int.tryParse(_durationController.text.trim()) ?? 0,
        'thumbnailUrl': _uploadedImageUrl ?? '',
      };

      final response = await http.post(
        Uri.parse('$apiBaseUrl/trainer/exams'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (!mounted) return;
        ToastHelper.show(context, 'Exam created successfully in DRAFT status');
        Navigator.pop(context);
      } else {
        throw Exception('Failed to create exam: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (!mounted) return;
      ToastHelper.show(context, 'Error creating exam: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: !isDesktop ? Drawer(child: _buildSidebar(context)) : null,
      body: Row(
        children: [
          if (isDesktop) SizedBox(width: 240, child: _buildSidebar(context)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context, !isDesktop, _currentView),
                Expanded(
                  child: Align(
                    alignment: const Alignment(0, -0.3),
                    child: _buildCurrentView(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentView() {
    final onBack = () {
      setState(() {
        _currentView = 'selection';
      });
    };

    switch (_currentView) {
      case 'form':
        return _buildExamForm();
      case 'import':
        return TrainerExamImportExcelPage(onBack: onBack);
      case 'matrix':
        return TrainerExamMatrixPage(onBack: onBack);
      case 'ai':
        return TrainerExamAiGeneratePage(onBack: onBack);
      case 'selection':
      default:
        return _buildMethodSelection();
    }
  }

  Widget _buildMethodSelection() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          const Text(
            'Choose Creation Method',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Select how you want to build your new exam.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 24,
            runSpacing: 24,
            alignment: WrapAlignment.center,
            children: [
              _buildMethodCard(
                title: 'Import by Excel',
                description: 'Upload an Excel file containing questions and answers based on our template.',
                icon: Icons.table_chart_outlined,
                color: const Color(0xFF3B82F6),
                onTap: () {
                  setState(() => _currentView = 'import');
                },
              ),
              _buildMethodCard(
                title: 'Create by Exam Matrix',
                description: 'Define an exam matrix structure and pick questions manually from bank.',
                icon: Icons.grid_view_outlined,
                color: const Color(0xFF20B486),
                onTap: () {
                  setState(() => _currentView = 'matrix');
                },
              ),
              _buildMethodCard(
                title: 'Generate with AI',
                description: 'Use AI to automatically generate a complete exam based on your criteria.',
                icon: Icons.auto_awesome_outlined,
                color: const Color(0xFF8B5CF6),
                isDisabled: true,
                onTap: () {
                  setState(() => _currentView = 'ai');
                },
              ),
            ],
          ),

        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isDisabled = false,
  }) {
    return MouseRegion(
      cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
      child: GestureDetector(
        onTap: isDisabled ? null : onTap,
        child: Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: Container(
            width: 300,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExamForm() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 800),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      padding: const EdgeInsets.all(32.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Color(0xFF64748B)),
                      onPressed: () => setState(() => _currentView = 'selection'),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      'Select Creation Method',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () {
                    setState(() => _currentView = 'selection');
                  },
                ),
              ],
            ),
            const SizedBox(height: 32),
            _buildLabel('EXAM THUMBNAIL'),
            InkWell(
              onTap: _isUploadingImage ? null : _pickAndUploadImage,
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
                  child: _isUploadingImage
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF20B486)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _uploadStatusText,
                              style: const TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ],
                        )
                      : _uploadedImageUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                _uploadedImageUrl!,
                                width: double.infinity,
                                height: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
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
            const SizedBox(height: 24),
            _buildLabel('EXAM TITLE'),
            _buildTextField(
              controller: _titleController,
              hintText: 'Đề thi THPTQG môn tiếng anh năm 2025',
              validator: (val) => val == null || val.isEmpty ? 'Title is required' : null,
            ),
            const SizedBox(height: 24),
            _buildLabel('EXAM DESCRIPTION'),
            _buildTextField(
              controller: _descriptionController,
              hintText: 'Briefly describe what this quiz covers...',
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('NUMBER OF QUESTION'),
                      _buildTextField(
                        controller: _questionsController,
                        hintText: '50',
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('CREATE DATE'),
                      _buildTextField(
                        controller: _dateController,
                        readOnly: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('PASSING SCORE (%)'),
                      _buildTextField(
                        controller: _passingScoreController,
                        hintText: '70',
                        keyboardType: TextInputType.number,
                        suffixText: '%',
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('TIME LIMIT (MINUTES)'),
                      _buildTextField(
                        controller: _durationController,
                        hintText: '60',
                        keyboardType: TextInputType.number,
                        suffixText: 'min',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isSubmitting ? null : () => setState(() => _currentView = 'selection'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF64748B),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Outfit')),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20B486),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create Exam', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF64748B),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? hintText,
    int maxLines = 1,
    bool readOnly = false,
    TextInputType? keyboardType,
    String? suffixText,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      readOnly: readOnly,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(
        color: Color(0xFF1E293B),
        fontSize: 14,
        fontFamily: 'Outfit',
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
        suffixText: suffixText,
        suffixStyle: const TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500),
        filled: true,
        fillColor: readOnly ? const Color(0xFFF8FAFC) : Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
    );
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    color: Color(0xFF38C9A6),
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
          _buildSidebarItem(
            Icons.dashboard_outlined,
            'Dashboard',
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const TrainerDashboardPage(),
                ),
              );
            },
          ),
          _buildSidebarItem(Icons.book_outlined, 'Courses', onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TrainerCoursesPage(),
              ),
            );
          }),
          _buildSidebarItem(Icons.assignment_outlined, 'Exam', isActive: true),
          _buildSidebarItem(Icons.people_outline, 'Learner'),
          _buildSidebarItem(Icons.question_answer_outlined, 'Question Bank', onTap: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => const TrainerQuestionBankPage(),
              ),
            );
          }),
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
    final activeColor = const Color(0xFF38C9A6);
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

  Widget _buildHeader(BuildContext context, bool showMenuButton, String currentView) {
    String subTitle = '';
    if (currentView == 'import') subTitle = ' > Import Exam by Excel';
    if (currentView == 'matrix') subTitle = ' > Import by Matrix';
    if (currentView == 'ai') subTitle = ' > Generate with AI';
    if (currentView == 'form') subTitle = ' > Manual Create';

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
            children: [
              const Icon(Icons.chevron_right, size: 16, color: Color(0xFF38C9A6)),
              const SizedBox(width: 4),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    color: Color(0xFF38C9A6),
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                  children: [
                    const TextSpan(
                      text: 'Exam > ',
                      style: TextStyle(fontWeight: FontWeight.normal),
                    ),
                    TextSpan(
                      text: 'Create New Exam',
                      style: TextStyle(fontWeight: subTitle.isEmpty ? FontWeight.bold : FontWeight.normal),
                    ),
                    if (subTitle.isNotEmpty)
                      TextSpan(
                        text: subTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
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
                  ToastHelper.show(context, 'No new notifications');
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
                child: _trainerAvatarUrl.isNotEmpty
                    ? ClipOval(
                        child: Image.network(
                          _trainerAvatarUrl,
                          width: 32,
                          height: 32,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Text(
                            _trainerInitials,
                            style: const TextStyle(
                              color: Color(0xFF38C9A6),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                      )
                    : Text(
                        _trainerInitials,
                        style: const TextStyle(
                          color: Color(0xFF38C9A6),
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
                  color: Color(0xFF38C9A6),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ],
      ),
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
    this.color = Colors.black,
    this.strokeWidth = 1.0,
    this.dashWidth = 5.0,
    this.dashSpace = 3.0,
    this.borderRadius = 0.0,
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
