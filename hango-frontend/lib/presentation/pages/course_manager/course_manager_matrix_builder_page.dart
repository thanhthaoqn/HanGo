import 'package:flutter/material.dart';
import 'dart:async';
import '../../../data/services/course_manager_api.dart';
import '../../../utils/toast_helper.dart';

class CourseManagerMatrixBuilderPage extends StatefulWidget {
  final CourseManagerApi api;
  final VoidCallback onSaved;

  const CourseManagerMatrixBuilderPage({
    super.key,
    required this.api,
    required this.onSaved,
  });

  @override
  State<CourseManagerMatrixBuilderPage> createState() => _CourseManagerMatrixBuilderPageState();
}

class _CourseManagerMatrixBuilderPageState extends State<CourseManagerMatrixBuilderPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  final List<Map<String, dynamic>> _rules = [];
  bool _isSaving = false;
  Timer? _debounce;

  final List<Map<String, dynamic>> _skills = [
    {'id': 1, 'name': 'Conversation/Short Sentences'},
    {'id': 2, 'name': 'Synonym'},
    {'id': 3, 'name': 'Antonym'},
    {'id': 4, 'name': 'Pronunciation'},
    {'id': 5, 'name': 'Grammar'},
    {'id': 6, 'name': 'Sentence Meaning'},
    {'id': 7, 'name': 'Sentence Combining'},
    {'id': 8, 'name': 'Fill in Blank'},
    {'id': 9, 'name': 'Reading Comprehension'},
    {'id': 10, 'name': 'Arrangement'},
  ];

  final List<Map<String, dynamic>> _difficulties = [
    {'id': 1, 'name': 'Easy'},
    {'id': 2, 'name': 'Medium'},
    {'id': 3, 'name': 'Hard'},
  ];

  final List<Map<String, dynamic>> _categories = [
    {'id': 1, 'name': 'SingleChoice'},
    // Will map to valid categories if needed. Assuming 1 is default.
  ];

  void _addRule() {
    setState(() {
      _rules.add({
        'skillId': null,
        'diffId': null,
        'catId': _categories[0]['id'], // Default to SingleChoice
        'quantity': 1,
        'available': null,
        'isChecking': false,
      });
    });
  }

  void _removeRule(int index) {
    setState(() {
      _rules.removeAt(index);
    });
  }

  void _checkAvailable(int index) {
    final rule = _rules[index];
    if (rule['skillId'] != null && rule['diffId'] != null && rule['catId'] != null) {
      if (_debounce?.isActive ?? false) _debounce!.cancel();

      setState(() {
        rule['isChecking'] = true;
      });

      _debounce = Timer(const Duration(milliseconds: 500), () async {
        try {
          final count = await widget.api.countAvailableQuestions(
            rule['skillId'],
            rule['diffId'],
            rule['catId'],
          );
          if (mounted) {
            setState(() {
              rule['available'] = count;
              rule['isChecking'] = false;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              rule['available'] = -1;
              rule['isChecking'] = false;
            });
          }
        }
      });
    }
  }

  int get _totalQuestions {
    return _rules.fold(0, (sum, rule) => sum + (rule['quantity'] as int));
  }

  bool get _isValid {
    if (_titleController.text.trim().isEmpty) return false;
    if (_rules.isEmpty) return false;
    for (var r in _rules) {
      if (r['skillId'] == null || r['diffId'] == null || r['catId'] == null || r['quantity'] <= 0) {
        return false;
      }
      if (r['available'] != null && r['available'] < r['quantity']) {
        return false; // Cannot save if requesting more than available
      }
    }
    return true;
  }

  Future<void> _saveMatrix() async {
    if (!_isValid) return;

    setState(() => _isSaving = true);

    try {
      final data = {
        'title': _titleController.text.trim(),
        'description': _descController.text.trim(),
        'details': _rules.map((r) => {
          'skillParamId': r['skillId'],
          'difficultyParamId': r['diffId'],
          'categoryId': r['catId'],
          'quantity': r['quantity'],
        }).toList(),
      };

      await widget.api.createExamMatrix(data);
      if (mounted) {
        ToastHelper.showSuccess(context, 'Tạo ma trận thành công!');
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.showError(context, 'Lỗi tạo ma trận: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Tạo Ma Trận Mới', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Color(0xFF4B5563)),
        centerTitle: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildGeneralInfoCard(),
                const SizedBox(height: 32),
                _buildRulesSection(),
                const SizedBox(height: 32),
                _buildActionButtons(),
                const SizedBox(height: 64),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGeneralInfoCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 10,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF20B486), size: 20),
              SizedBox(width: 8),
              Text(
                'Thông tin chung',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit', color: Color(0xFF0F172A)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _titleController,
            decoration: _inputDecoration('Tên Ma Trận *', 'Ví dụ: Ma trận Đề thi Thử THPT QG 2026'),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descController,
            decoration: _inputDecoration('Mô tả ngắn', 'Nhập mô tả cho ma trận này'),
            maxLines: 3,
          ),
        ],
      ),
    );
  }

  Widget _buildRulesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Cấu trúc Đề thi',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, fontFamily: 'Outfit', color: Color(0xFF0F172A)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFE6FFFA),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF20B486).withOpacity(0.3)),
              ),
              child: Text(
                'Tổng: $_totalQuestions / 40 câu',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _totalQuestions == 40 ? const Color(0xFF20B486) : const Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_rules.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Center(
              child: Text(
                'Chưa có quy tắc nào.\nBấm "Thêm quy tắc mới" để bắt đầu thiết lập cấu trúc.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _rules.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return _buildRuleCard(index);
            },
          ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _addRule,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              border: Border.all(color: const Color(0xFFCBD5E1), style: BorderStyle.solid),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_circle_outline, color: Color(0xFF4B5563), size: 20),
                SizedBox(width: 8),
                Text(
                  'Thêm quy tắc mới',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563), fontFamily: 'Outfit'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRuleCard(int index) {
    final rule = _rules[index];
    final bool hasError = (rule['available'] != null && rule['available'] < rule['quantity']);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: hasError ? Colors.red.shade300 : const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.02),
            blurRadius: 10,
            offset: Offset(0, 2),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quy tắc #${index + 1}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4B5563), fontFamily: 'Outfit'),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'Xóa quy tắc',
                onPressed: () => _removeRule(index),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<int>(
                  decoration: _inputDecoration('Kỹ năng', null),
                  value: rule['skillId'],
                  items: _skills.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name'], overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    setState(() => rule['skillId'] = val);
                    _checkAvailable(index);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: DropdownButtonFormField<int>(
                  decoration: _inputDecoration('Độ khó', null),
                  value: rule['diffId'],
                  items: _difficulties.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                  onChanged: (val) {
                    setState(() => rule['diffId'] = val);
                    _checkAvailable(index);
                  },
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 1,
                child: TextFormField(
                  decoration: _inputDecoration('Số lượng', null),
                  keyboardType: TextInputType.number,
                  initialValue: rule['quantity'].toString(),
                  onChanged: (val) {
                    setState(() {
                      rule['quantity'] = int.tryParse(val) ?? 0;
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildAvailabilityStatus(rule),
        ],
      ),
    );
  }

  Widget _buildAvailabilityStatus(Map<String, dynamic> rule) {
    if (rule['isChecking']) {
      return const Row(
        children: [
          SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF64748B))),
          SizedBox(width: 8),
          Text('Đang kiểm tra kho câu hỏi...', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit')),
        ],
      );
    } else if (rule['available'] != null) {
      final isEnough = rule['available'] >= rule['quantity'];
      return Row(
        children: [
          Icon(
            isEnough ? Icons.check_circle : Icons.warning_amber_rounded,
            size: 16,
            color: isEnough ? const Color(0xFF20B486) : Colors.red,
          ),
          const SizedBox(width: 6),
          Text(
            'Kho: ${rule['available']} câu ${isEnough ? '(Hợp lệ)' : '(Không đủ câu hỏi)'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isEnough ? const Color(0xFF20B486) : Colors.red,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      );
    }
    return const Text('Vui lòng chọn Kỹ năng và Độ khó', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'Outfit'));
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          child: const Text(
            'Hủy',
            style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton(
          onPressed: _isValid && !_isSaving ? _saveMatrix : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF20B486),
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFCBD5E1),
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            elevation: 0,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Lưu Ma Trận',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label, String? hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontFamily: 'Outfit', fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
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
        borderSide: const BorderSide(color: Color(0xFF20B486), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }
}
