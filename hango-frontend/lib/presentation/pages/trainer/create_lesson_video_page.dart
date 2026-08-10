import 'dart:ui';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hango/presentation/widgets/internal_app_header.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart' as dio;
import '../../../utils/file_picker_helper.dart';
import '../../../data/repositories/lesson_repository.dart';
import '../../widgets/trainer_action_required_card.dart';
import '../../../utils/toast_helper.dart';

class CreateLessonVideoPage extends StatefulWidget {
  final int courseId;
  final String courseTitle;
  final String trainerName;
  final String trainerInitials;
  final List<dynamic> sections;
  final int sectionIndex;
  final Future<void> Function(List<dynamic> updatedSections) onSectionsChanged;
  final int? lessonIndex;
  final String? courseStatus;
  final String? rejectionReason;

  const CreateLessonVideoPage({
    super.key,
    required this.courseId,
    required this.courseTitle,
    required this.trainerName,
    required this.trainerInitials,
    required this.sections,
    required this.sectionIndex,
    required this.onSectionsChanged,
    this.lessonIndex,
    this.courseStatus,
    this.rejectionReason,
  });

  @override
  State<CreateLessonVideoPage> createState() => _CreateLessonVideoPageState();
}

class _CreateLessonVideoPageState extends State<CreateLessonVideoPage> {
  late List<dynamic> _localSections;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _learningObjectivesController = TextEditingController();
  final TextEditingController _mediaDurationController = TextEditingController();
  final TextEditingController _mediaSizeController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _videoUrlController = TextEditingController();
  final TextEditingController _estimatedTimeController =
      TextEditingController();

  String? _currentVideoUrl;
  YoutubePlayerController? _youtubeController;
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;

  bool _isUploadingVideo = false;
  String _uploadStatusText = '';
  double _uploadProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _localSections = List.from(widget.sections);

    if (widget.lessonIndex != null &&
        widget.lessonIndex! <
            (_localSections[widget.sectionIndex]['lessons'] ?? []).length) {
      final lesson =
          _localSections[widget.sectionIndex]['lessons'][widget.lessonIndex!];
      _titleController.text = lesson['title'] ?? '';
      _codeController.text = lesson['lessonCode'] ?? '';
      _learningObjectivesController.text = lesson['learningObjectives'] ?? '';
      _mediaDurationController.text = lesson['mediaDurationSeconds']?.toString() ?? '';
      _mediaSizeController.text = lesson['mediaSizeBytes']?.toString() ?? '';
      _descController.text = lesson['description'] ?? '';
      _videoUrlController.text = lesson['videoUrl'] ?? lesson['content'] ?? '';
      _estimatedTimeController.text =
          lesson['estimatedTimeMinutes']?.toString() ?? '';

      final lessonId = lesson['id'];
      final isLocallyModified = lesson['isLocallyModified'] == true;
      if (lessonId is num && lessonId < 1000000000000 && !isLocallyModified) {
        _loadLessonDetailFromApi(lessonId.toInt());
      }
    }

    _videoUrlController.addListener(_onVideoUrlChanged);
    _onVideoUrlChanged();
  }

  void _onVideoUrlChanged() {
    final url = _videoUrlController.text.trim();
    if (url != _currentVideoUrl) {
      _currentVideoUrl = url;
      _initializePlayer(url);
    }
  }

  Future<void> _initializePlayer(String url) async {
    _disposePlayers();

    if (url.isEmpty) {
      setState(() {});
      return;
    }

    final youtubeId = _extractYouTubeVideoId(url);
    if (youtubeId != null) {
      _youtubeController = YoutubePlayerController.fromVideoId(
        videoId: youtubeId,
        autoPlay: false,
        params: const YoutubePlayerParams(showFullscreenButton: true),
      );
      setState(() {});
      return;
    }

    if (_isDirectVideoUrl(url)) {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(url));
      try {
        await _videoPlayerController!.initialize();
        _chewieController = ChewieController(
          videoPlayerController: _videoPlayerController!,
          autoPlay: false,
          looping: false,
        );
        setState(() {});
      } catch (e) {
        debugPrint('Error initializing video player: $e');
        _disposePlayers();
        setState(() {});
      }
      return;
    }

    setState(() {});
  }

  void _disposePlayers() {
    _youtubeController?.close();
    _youtubeController = null;
    _chewieController?.dispose();
    _chewieController = null;
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
  }

  void _loadLessonDetailFromApi(int lessonId) async {
    try {
      final repo = LessonRepository();
      final detail = await repo.fetchLessonDetail(lessonId);
      if (mounted) {
        setState(() {
          _titleController.text = detail.title;
          _videoUrlController.text = detail.content;
          if (detail.lessonCode != null) _codeController.text = detail.lessonCode!;
          if (detail.learningObjectives != null) _learningObjectivesController.text = detail.learningObjectives!;
          if (detail.mediaDurationSeconds != null) _mediaDurationController.text = detail.mediaDurationSeconds.toString();
          if (detail.mediaSizeBytes != null) _mediaSizeController.text = detail.mediaSizeBytes.toString();
          if (detail.estimatedTimeMinutes != null) _estimatedTimeController.text = detail.estimatedTimeMinutes.toString();
        });
      }
    } catch (e) {
      debugPrint(
        'Error loading lesson detail from API in CreateLessonVideoPage: $e',
      );
    }
  }

  @override
  void dispose() {
    _videoUrlController.removeListener(_onVideoUrlChanged);
    _disposePlayers();
    _titleController.dispose();
    _codeController.dispose();
    _learningObjectivesController.dispose();
    _mediaDurationController.dispose();
    _mediaSizeController.dispose();
    _descController.dispose();
    _videoUrlController.dispose();
    _estimatedTimeController.dispose();
    super.dispose();
  }

  Future<void> _notifyParent() async {
    await widget.onSectionsChanged(_localSections);
  }

  Future<void> _pickAndUploadVideo() async {
    try {
      final picked = await pickVideo();
      if (picked == null) return;

      setState(() {
        _uploadProgress = 0.0;
        _isUploadingVideo = true;
        _uploadStatusText = 'Uploading... 0%';
      });

      final formData = dio.FormData.fromMap({
        'upload_preset': 'hango_preset',
        'file': dio.MultipartFile.fromBytes(
          picked.bytes,
          filename: picked.name,
        ),
      });

      final dioClient = dio.Dio();
      final response = await dioClient.post(
        'https://api.cloudinary.com/v1_1/diqekap4o/video/upload',
        data: formData,
        onSendProgress: (int sent, int total) {
          if (total > 0 && mounted) {
            setState(() {
              _uploadProgress = sent / total;
              final percent = (_uploadProgress * 100).toStringAsFixed(0);
              _uploadStatusText = 'Uploading... $percent%';
            });
          }
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = response.data is String ? jsonDecode(response.data) : response.data;
        
        final String videoUrl = data['secure_url'] ?? data['url'] ?? '';
        final double durationDouble = (data['duration'] as num?)?.toDouble() ?? 0.0;
        final int durationSec = durationDouble.round();
        final int bytes = (data['bytes'] as num?)?.toInt() ?? 0;
        final int estimatedMins = (durationSec / 60).ceil();
        
        setState(() {
          _videoUrlController.text = videoUrl;
          if (durationSec > 0) {
            _mediaDurationController.text = durationSec.toString();
          }
          if (bytes > 0) {
            _mediaSizeController.text = bytes.toString();
          }
          if (estimatedMins > 0) {
            _estimatedTimeController.text = estimatedMins.toString();
          }
          
          _isUploadingVideo = false;
          _uploadProgress = 0.0;
        });
        
        if (mounted) {
          ToastHelper.showSuccess(context, 'Video uploaded successfully!');
        }
      } else {
        throw Exception(
          'Upload failed with status: ${response.statusCode} - ${response.data}',
        );
      }
    } catch (e) {
      debugPrint('Error uploading video: $e');
      if (mounted) {
        setState(() {
          _isUploadingVideo = false;
          _uploadStatusText = 'Upload failed';
        });
        ToastHelper.showError(context, 'Error uploading video: $e');
      }
    }
  }

  void _saveLesson() async {
    final title = _titleController.text.trim();
    final code = _codeController.text.trim();
    final objectives = _learningObjectivesController.text.trim();
    final mediaDuration = int.tryParse(_mediaDurationController.text.trim()) ?? 0;
    final mediaSize = int.tryParse(_mediaSizeController.text.trim()) ?? 0;
    final desc = _descController.text.trim();
    final videoUrl = _videoUrlController.text.trim();
    final estimatedTimeText = _estimatedTimeController.text.trim();
    final estimatedTimeMinutes = int.tryParse(estimatedTimeText) ?? 0;

    if (title.isEmpty) {
      ToastHelper.showError(context, 'Please enter a lesson title');
      return;
    }
    if (title.length > 100) {
      ToastHelper.showError(context, 'Lesson title cannot exceed 100 characters');
      return;
    }
    if (code.length > 20) {
      ToastHelper.showError(context, 'Lesson code cannot exceed 20 characters');
      return;
    }
    if (desc.length > 500) {
      ToastHelper.showError(context, 'Description cannot exceed 500 characters');
      return;
    }
    if (objectives.length > 1000) {
      ToastHelper.showError(context, 'Learning objectives cannot exceed 1000 characters');
      return;
    }

    if (videoUrl.isEmpty) {
      ToastHelper.showError(context, 'Please enter the video URL');
      return;
    }
    
    final uri = Uri.tryParse(videoUrl);
    if (uri == null || !uri.isAbsolute || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      ToastHelper.showError(context, 'Please enter a valid video URL (e.g., https://youtube.com/...)');
      return;
    }

    if (mediaDuration <= 0) {
      ToastHelper.showError(context, 'Please enter a valid video duration (> 0 seconds)');
      return;
    }
    if (estimatedTimeMinutes <= 0) {
      ToastHelper.showError(context, 'Please enter a valid estimated time (> 0 minutes)');
      return;
    }

    setState(() {
      final lessons = List.from(
        _localSections[widget.sectionIndex]['lessons'] ?? [],
      );

      final int displayOrder = widget.lessonIndex != null
          ? (lessons[widget.lessonIndex!]['displayOrder'] as num?)?.toInt() ??
                (lessons.length + 1)
          : (lessons.length + 1);

      final lessonData = {
        'id': widget.lessonIndex != null
            ? lessons[widget.lessonIndex!]['id']
            : DateTime.now().millisecondsSinceEpoch,

        // Must match backend/template key
        'lessonType': 'video',
        'displayOrder': displayOrder,

        // Template/common fields
        'lessonCode': code,

        'title': title,
        'description': desc,

        // Video lesson content fields (backend/template convention)
        'content': videoUrl,
        'mediaFileUrl': videoUrl,
        'mediaType': 'video',
        'mediaDurationSeconds': mediaDuration,
        'mediaSizeBytes': mediaSize,

        'learningObjectives': objectives,
        'estimatedTimeMinutes': estimatedTimeMinutes,
        'estimatedTime': estimatedTimeMinutes,
        'textContentMarkdown': '',
        'textContentHtml': '',
        'version': 'v1.0',
        'isLocallyModified': true,

        // Keep old keys (compatibility)
        'itemType': 'video',
        'videoUrl': videoUrl,
        'questionText': videoUrl,
      };

      if (widget.lessonIndex != null) {
        lessons[widget.lessonIndex!] = lessonData;
      } else {
        lessons.add(lessonData);
      }
      _localSections[widget.sectionIndex]['lessons'] = lessons;
    });

    await _notifyParent();
    if (!mounted) return;
    ToastHelper.showSuccess(
      context,
      widget.lessonIndex != null
          ? 'Lesson updated successfully'
          : 'Lesson added successfully',
    );

    // Pop back to CreateLessonPage
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final section = _localSections[widget.sectionIndex];

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InternalAppHeader(isMobile: false),
          Expanded(
            child: isDesktop
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                        child: _buildTitleSection(),
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 280,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(24, 0, 0, 24),
                                child: _buildLeftPanel(context),
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.fromLTRB(0, 0, 24, 24),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildMainFormCard(section),
                                    const SizedBox(height: 24),
                                    _buildActionsRow(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildTitleSection(),
                        const SizedBox(height: 24),
                        _buildLeftPanel(context),
                        const SizedBox(height: 24),
                        _buildMainFormCard(section),
                        const SizedBox(height: 24),
                        _buildActionsRow(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _unusedLegacyHeader([bool isMobile = false]) {
    return Container(
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFEFF2F5))),
      ),
      child: Row(
        children: [
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
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                child: Text(
                  widget.courseTitle,
                  style: const TextStyle(
                    color: Color(0xFF20B486),
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
                'Create New Lesson',
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
          IconButton(
            icon: const Icon(
              Icons.notifications_none_outlined,
              color: Color(0xFF4B5563),
              size: 24,
            ),
            onPressed: () {},
          ),
          const SizedBox(width: 16),
          Row(
            children: [
              Text(
                widget.trainerName,
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
                  widget.trainerInitials,
                  style: const TextStyle(
                    color: Color(0xFF20B486),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleSection() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            '${widget.courseTitle} (Edit mode)',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLeftPanel(BuildContext context) {
    final activeColor = const Color(0xFF20B486);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFF2F5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'COURSE CONTENT MANAGEMENT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF94A3B8),
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 16),
              // Item 1: Introduction
              InkWell(
                onTap: () {
                  Navigator.pop(context, 'goToIntroduction');
                },
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFEFF2F5)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF94A3B8),
                                width: 1.5,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              '1',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF94A3B8),
                                fontFamily: 'Outfit',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Introduction',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF94A3B8),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Item 2: Syllabus
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFEFF2F5)),
                    ),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(width: 4, color: activeColor),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: activeColor,
                                    width: 1.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Text(
                                  '2',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: activeColor,
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Syllabus',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E293B),
                                  fontFamily: 'Outfit',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        TrainerActionRequiredCard(
          courseStatus: widget.courseStatus,
          rejectionReason: widget.rejectionReason,
        ),
        const SizedBox(height: 20),
        // Trainer Tips Card
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEFF2F5)),
          ),
          child: Stack(
            children: [
              // Background Watermark
              Positioned(
                right: -24,
                bottom: -24,
                child: Icon(
                  Icons.lightbulb_outline,
                  size: 120,
                  color: const Color(0xFF20B486).withOpacity(0.05),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF20B486).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.lightbulb_outline,
                            color: Color(0xFF20B486),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Trainer Insights',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E293B),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Engaging videos and clear syllabus help students stay motivated. Consider adding short quizzes after each section to reinforce learning.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        height: 1.5,
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () {},
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Explore more tips',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF20B486),
                              fontFamily: 'Outfit',
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Color(0xFF20B486),
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMainFormCard(dynamic section) {
    final lessons = section['lessons'] as List<dynamic>? ?? [];

    return Container(
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
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Expanded Section Header Box
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6FFFA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                // Folder icon
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFF20B486),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.folder_open,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        section['title'] ?? 'Untitled Section',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Color(0xFF1E293B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${lessons.length} ${lessons.length == 1 ? "item" : "items"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.edit, color: Color(0xFFF59E0B), size: 20),
                const SizedBox(width: 12),
                const Icon(
                  Icons.delete_outline,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Lesson Code field
          const Text(
            'Lesson Code',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _codeController,
            decoration: InputDecoration(
              hintText: 'e.g. L01',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          // Lesson Title field
          const Text(
            'Lesson Title',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: 'Enter lesson title',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          // Lesson Description field
          const Text(
            'Lesson Description',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _descController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter lesson description.....',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          // Learning Objectives field
          const Text(
            'Learning Objectives',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _learningObjectivesController,
            maxLines: 4,
            decoration: InputDecoration(
              hintText: 'Enter learning objectives (one per line).....',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 20),
          // Content Type field (Pre-filled Video)
          const Text(
            'Content Type',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9), // light grey pre-filled
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              'Video',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 14,
                color: Color(0xFF475569),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Video URL input
          const Text(
            'Video URL *',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _videoUrlController,
            decoration: InputDecoration(
              hintText: 'Enter YouTube or Vimeo URL',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: const Icon(Icons.link, color: Color(0xFF94A3B8)),
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 12),
          // Upload Video Button
          ElevatedButton.icon(
            onPressed: _isUploadingVideo ? null : _pickAndUploadVideo,
            icon: _isUploadingVideo 
                ? const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                  )
                : const Icon(Icons.upload_file, size: 18),
            label: Text(
              _isUploadingVideo ? _uploadStatusText : 'Upload Video File',
              style: const TextStyle(
                fontFamily: 'Outfit',
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF20B486),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Video Preview section
          _buildVideoPreview(),
          const SizedBox(height: 24),
          // Estimated Time input
          const Text(
            'Estimated Time (Minutes)',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4B5563),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _estimatedTimeController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: 'e.g. 15',
              hintStyle: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontFamily: 'Outfit',
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              prefixIcon: const Icon(
                Icons.timer_outlined,
                color: Color(0xFF94A3B8),
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
                borderSide: const BorderSide(
                  color: Color(0xFF20B486),
                  width: 1.5,
                ),
              ),
            ),
            style: const TextStyle(
              fontFamily: 'Outfit',
              fontSize: 14,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          // Media Duration & Size fields
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Duration (Seconds)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B5563),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _mediaDurationController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 120',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                          fontFamily: 'Outfit',
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
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
                          borderSide: const BorderSide(
                            color: Color(0xFF20B486),
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
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
                      'Size (Bytes)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B5563),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _mediaSizeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        hintText: 'e.g. 102400',
                        hintStyle: const TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                          fontFamily: 'Outfit',
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
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
                          borderSide: const BorderSide(
                            color: Color(0xFF20B486),
                            width: 1.5,
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  // ---- Video URL helpers ----

  String? _extractYouTubeVideoId(String url) {
    // Supports youtube.com/watch?v=ID, youtu.be/ID, youtube.com/embed/ID, youtube.com/shorts/ID
    final patterns = [
      RegExp(r'(?:youtube\.com\/watch\?.*v=)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:youtu\.be\/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:youtube\.com\/embed\/)([a-zA-Z0-9_-]{11})'),
      RegExp(r'(?:youtube\.com\/shorts\/)([a-zA-Z0-9_-]{11})'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  String? _extractVimeoVideoId(String url) {
    final match = RegExp(r'vimeo\.com\/(\d+)').firstMatch(url);
    return match?.group(1);
  }

  bool _isDirectVideoUrl(String url) {
    final lowerUrl = url.toLowerCase();
    return lowerUrl.endsWith('.mp4') ||
        lowerUrl.endsWith('.webm') ||
        lowerUrl.endsWith('.mov') ||
        lowerUrl.endsWith('.avi') ||
        lowerUrl.endsWith('.mkv') ||
        lowerUrl.contains('.mp4?') ||
        lowerUrl.contains('.webm?');
  }

  Future<void> _openVideoUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        debugPrint('Could not launch URL: $e');
      }
    }
  }

  Widget _buildVideoPreview() {
    final videoUrl = _videoUrlController.text.trim();
    if (videoUrl.isEmpty) {
      return const SizedBox.shrink();
    }

    final youtubeId = _extractYouTubeVideoId(videoUrl);
    final vimeoId = _extractVimeoVideoId(videoUrl);
    final isDirect = _isDirectVideoUrl(videoUrl);

    if (youtubeId != null && _youtubeController != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: YoutubePlayer(
            controller: _youtubeController!,
          ),
        ),
      );
    } else if (isDirect && _chewieController != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: AspectRatio(
          aspectRatio: _videoPlayerController?.value.aspectRatio ?? 16 / 9,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Chewie(
              controller: _chewieController!,
            ),
          ),
        ),
      );
    } else if (youtubeId != null || isDirect) {
      // Loading state for video players
      return Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: const Center(
            child: CircularProgressIndicator(
              color: Color(0xFF20B486),
              strokeWidth: 2,
            ),
          ),
        ),
      );
    } else if (vimeoId != null) {
      return _buildVimeoPreview(vimeoId, videoUrl);
    } else if (videoUrl.startsWith('http')) {
      return _buildGenericVideoPreview(videoUrl);
    }

    return const SizedBox.shrink();
  }

  Widget _buildVimeoPreview(String vimeoId, String originalUrl) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GestureDetector(
        onTap: () => _openVideoUrl(originalUrl),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.04),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1AB7EA), Color(0xFF00B2FF)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1AB7EA).withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VIMEO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1AB7EA),
                          fontFamily: 'Outfit',
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Video ID: $vimeoId',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Click to play in browser',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, color: Color(0xFF94A3B8), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGenericVideoPreview(String videoUrl) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: GestureDetector(
        onTap: () => _openVideoUrl(videoUrl),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(0, 0, 0, 0.04),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF20B486), Color(0xFF059669)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.smart_display_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF20B486).withAlpha(20),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'VIDEO LINK',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF20B486),
                          fontFamily: 'Outfit',
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      videoUrl,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                        fontFamily: 'Outfit',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Click to play in browser',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.open_in_new, color: Color(0xFF94A3B8), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionsRow() {
    return Row(
      children: [
        const Text(
          'Draft saved automatically just now',
          style: TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 12,
            fontStyle: FontStyle.italic,
            fontFamily: 'Outfit',
          ),
        ),
        const Spacer(),
        OutlinedButton(
          onPressed: () {
            Navigator.pop(context);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF4B5563),
            side: const BorderSide(color: Color(0xFFCBD5E1)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Back',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _saveLesson,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF20B486),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 0,
          ),
          child: Text(
            widget.lessonIndex != null ? 'Save Changes' : 'Add Lesson +',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
          ),
        ),
      ],
    );
  }
}

class DashedRoundedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double dashWidth;
  final double dashSpace;
  final double borderRadius;

  DashedRoundedBorderPainter({
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

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(borderRadius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashedPath = Path();

    for (final PathMetric metric in path.computeMetrics()) {
      double distance = 0.0;
      while (distance < metric.length) {
        final double len = dashWidth;
        if (distance + len > metric.length) {
          dashedPath.addPath(
            metric.extractPath(distance, metric.length),
            Offset.zero,
          );
        } else {
          dashedPath.addPath(
            metric.extractPath(distance, distance + len),
            Offset.zero,
          );
        }
        distance += len + dashSpace;
      }
    }

    canvas.drawPath(dashedPath, paint);
  }

  @override
  bool shouldRepaint(DashedRoundedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.dashWidth != dashWidth ||
        oldDelegate.dashSpace != dashSpace ||
        oldDelegate.borderRadius != borderRadius;
  }
}
