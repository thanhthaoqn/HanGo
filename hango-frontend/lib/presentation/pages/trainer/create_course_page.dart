// ignore_for_file: deprecated_member_use
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../../../data/services/auth_service.dart';
import '../../../utils/file_picker_helper.dart';
import '../../../utils/toast_helper.dart';

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
  String _trainerAvatarUrl = '';

  // Form values
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSaving = false;

  // Dynamic dropdown lists (populated from DB with default fallbacks)
  List<Map<String, dynamic>> _dbCategories = [
    {'paramKey': 'GRAMMAR', 'paramValue': 'Grammar'},
    {'paramKey': 'VOCABULARY', 'paramValue': 'Vocabulary'},
    {'paramKey': 'LISTENING', 'paramValue': 'Listening'},
    {'paramKey': 'READING_COMPREHENSION', 'paramValue': 'Reading Comprehension'},
    {'paramKey': 'WRITING', 'paramValue': 'Writing'},
    {'paramKey': 'PRONUNCIATION', 'paramValue': 'Pronunciation'},
  ];
  List<Map<String, dynamic>> _dbLevels = [
    {'paramKey': 'BASIC', 'paramValue': 'Basic'},
    {'paramKey': 'INTERMEDIATE', 'paramValue': 'Intermediate'},
    {'paramKey': 'ADVANCED', 'paramValue': 'Advanced'},
  ];
  String _selectedCategoryKey = 'GRAMMAR';
  String _selectedLevelKey = 'BASIC';
  final TextEditingController _versionController = TextEditingController(text: 'v1.0');

  // Image Upload state variables
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;
  String _uploadStatusText = '';

  String get apiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8080/api/v1';
    }
    return 'http://localhost:8080/api/v1';
  }

  @override
  void initState() {
    super.initState();
    _loadTrainerInfo();
    _loadSystemParameters();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _versionController.dispose();
    super.dispose();
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

  Future<void> _loadSystemParameters() async {
    try {
      final token = await _authService.getToken();
      if (token == null) return;

      final catUri = Uri.parse('$apiBaseUrl/trainer/system-parameters?type=course_category');
      final catResponse = await http.get(catUri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      final levelUri = Uri.parse('$apiBaseUrl/trainer/system-parameters?type=academic_level');
      final levelResponse = await http.get(levelUri, headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      });

      if (catResponse.statusCode == 200 && levelResponse.statusCode == 200) {
        final List<dynamic> catData = jsonDecode(utf8.decode(catResponse.bodyBytes));
        final List<dynamic> levelData = jsonDecode(utf8.decode(levelResponse.bodyBytes));

        setState(() {
          _dbCategories = catData.map((e) => Map<String, dynamic>.from(e)).toList();
          _dbLevels = levelData.map((e) => Map<String, dynamic>.from(e)).toList();

          if (_dbCategories.isNotEmpty) {
            final hasSelectedCat = _dbCategories.any((e) => e['paramKey'] == _selectedCategoryKey);
            if (!hasSelectedCat) {
              _selectedCategoryKey = _dbCategories.first['paramKey'] ?? 'GRAMMAR';
            }
          }
          if (_dbLevels.isNotEmpty) {
            final hasSelectedLevel = _dbLevels.any((e) => e['paramKey'] == _selectedLevelKey);
            if (!hasSelectedLevel) {
              _selectedLevelKey = _dbLevels.first['paramKey'] ?? 'BASIC';
            }
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading system parameters: $e');
    }
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
          picked.bytes,
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
        ToastHelper.showError(context, 'Error uploading image: $e');
      }
    }
  }

  void _saveCourse() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final uri = Uri.parse('$apiBaseUrl/trainer/courses');
      final body = jsonEncode({
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'categoryKey': _selectedCategoryKey,
        'difficultyKey': _selectedLevelKey,
        'thumbnailUrl': _uploadedImageUrl ?? '',
      });

      final response = await http.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ToastHelper.showSuccess(context, 'Course created successfully as DRAFT!');
          Navigator.pop(context, true); // Return true to refresh list
        }
      } else {
        throw Exception('Failed to create course: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error saving course: $e');
      if (mounted) {
        ToastHelper.showError(context, 'Error saving course: $e');
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, false),
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
                    color: Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                ' › ',
                style: TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 16,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'Create New Course',
                style: TextStyle(
                  color: Color(0xFF20B486),
                  fontWeight: FontWeight.bold,
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
                              color: Color(0xFF20B486),
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
                      value: _selectedCategoryKey,
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
                      items: _dbCategories.map((dynamic item) {
                        return DropdownMenuItem<String>(
                          value: item['paramKey'] as String,
                          child: Text(item['paramValue'] as String),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedCategoryKey = newValue;
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
                      value: _selectedLevelKey,
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
                      items: _dbLevels.map((dynamic item) {
                        return DropdownMenuItem<String>(
                          value: item['paramKey'] as String,
                          child: Text(item['paramValue'] as String),
                        );
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() {
                            _selectedLevelKey = newValue;
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
          // Version
          const Text(
            'Version',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _versionController,
            decoration: InputDecoration(
              hintText: 'Enter version...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontFamily: 'Outfit'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              suffixIcon: PopupMenuButton<String>(
                icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF64748B)),
                onSelected: (value) {
                  _versionController.text = value;
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'v1.0', child: Text('v1.0', style: TextStyle(fontFamily: 'Outfit'))),
                  const PopupMenuItem(value: 'v2.0', child: Text('v2.0', style: TextStyle(fontFamily: 'Outfit'))),
                  const PopupMenuItem(value: 'v3.0', child: Text('v3.0', style: TextStyle(fontFamily: 'Outfit'))),
                ],
              ),
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
