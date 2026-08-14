import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../../utils/file_picker_helper.dart';
import '../../../utils/toast_helper.dart';

class EditExamMetadataDialog extends StatefulWidget {
  final Map<String, dynamic> initialData;
  final Future<void> Function(Map<String, dynamic> newData) onSave;

  const EditExamMetadataDialog({
    super.key,
    required this.initialData,
    required this.onSave,
  });

  @override
  State<EditExamMetadataDialog> createState() => _EditExamMetadataDialogState();
}

class _EditExamMetadataDialogState extends State<EditExamMetadataDialog> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _durationController;
  late TextEditingController _passingScoreController;
  late TextEditingController _expectedCountController;

  String? _uploadedImageUrl;
  bool _isUploadingImage = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialData['title']?.toString() ?? '');
    _descriptionController = TextEditingController(text: widget.initialData['description']?.toString() ?? '');
    _durationController = TextEditingController(text: widget.initialData['durationMinutes']?.toString() ?? '');
    _passingScoreController = TextEditingController(text: widget.initialData['passingScore']?.toString() ?? '');
    _expectedCountController = TextEditingController(text: widget.initialData['expectedQuestionCount']?.toString() ?? '');
    _uploadedImageUrl = widget.initialData['thumbnailUrl']?.toString();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _passingScoreController.dispose();
    _expectedCountController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final picked = await pickImage();
      if (picked == null) return;

      setState(() {
        _isUploadingImage = true;
      });

      final url = Uri.parse('https://api.cloudinary.com/v1_1/diqekap4o/image/upload');
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = 'hango_preset'
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            picked.bytes!,
            filename: picked.name,
          ),
        );

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
      setState(() {
        _isUploadingImage = false;
      });
      if (mounted) {
        ToastHelper.show(context, 'Error uploading image: $e', isError: true);
      }
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final data = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'durationMinutes': int.parse(_durationController.text.trim()),
        'passingScore': double.parse(_passingScoreController.text.trim()),
        'expectedQuestionCount': int.parse(_expectedCountController.text.trim()),
        'thumbnailUrl': _uploadedImageUrl,
      };

      await widget.onSave(data);

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Error saving exam info: $e', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Edit Exam Basic Info',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _titleController,
                          decoration: const InputDecoration(
                            labelText: 'Exam Title',
                            border: OutlineInputBorder(),
                          ),
                          validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descriptionController,
                          decoration: const InputDecoration(
                            labelText: 'Description',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (val) => val == null || val.isEmpty ? 'Required field' : null,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _durationController,
                                decoration: const InputDecoration(
                                  labelText: 'Duration (minutes)',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Required';
                                  if (int.tryParse(val) == null) return 'Must be a number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _passingScoreController,
                                decoration: const InputDecoration(
                                  labelText: 'Passing Score',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Required';
                                  if (double.tryParse(val) == null) return 'Must be a number';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextFormField(
                                controller: _expectedCountController,
                                decoration: const InputDecoration(
                                  labelText: 'Expected Questions',
                                  border: OutlineInputBorder(),
                                ),
                                keyboardType: TextInputType.number,
                                validator: (val) {
                                  if (val == null || val.isEmpty) return 'Required';
                                  if (int.tryParse(val) == null) return 'Must be a number';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Exam Thumbnail',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit'),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: _isUploadingImage ? null : _pickAndUploadImage,
                          child: Container(
                            height: 160,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                                width: 2,
                                style: BorderStyle.solid,
                              ),
                              image: _uploadedImageUrl != null && _uploadedImageUrl!.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(_uploadedImageUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: _isUploadingImage
                                ? const Center(child: CircularProgressIndicator())
                                : _uploadedImageUrl == null || _uploadedImageUrl!.isEmpty
                                    ? Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: const [
                                          Icon(Icons.cloud_upload_outlined, size: 40, color: Color(0xFF94A3B8)),
                                          SizedBox(height: 8),
                                          Text('Click to upload image', style: TextStyle(color: Color(0xFF64748B))),
                                        ],
                                      )
                                    : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: _isSaving ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF20B486),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Changes', style: TextStyle(color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
