import 'package:flutter/material.dart';
import 'dart:async';
import '../../../services/hango_api.dart';
import '../../../utils/toast_helper.dart';

class MatrixBuilderPage extends StatefulWidget {
  final HangoApi api;
  final VoidCallback onSaved;

  const MatrixBuilderPage({super.key, required this.api, required this.onSaved});

  @override
  State<MatrixBuilderPage> createState() => _MatrixBuilderPageState();
}

class _MatrixBuilderPageState extends State<MatrixBuilderPage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  List<Map<String, dynamic>> _rules = [];
  bool _isSaving = false;

  final List<Map<String, dynamic>> _skills = [
    {'id': 1, 'name': 'Listening'},
    {'id': 2, 'name': 'Reading'},
    {'id': 3, 'name': 'Grammar'},
    {'id': 4, 'name': 'Vocabulary'},
  ];

  final List<Map<String, dynamic>> _difficulties = [
    {'id': 5, 'name': 'Easy'},
    {'id': 6, 'name': 'Medium'},
    {'id': 7, 'name': 'Hard'},
  ];

  final List<Map<String, dynamic>> _categories = [
    {'id': 1, 'name': 'Single Choice'},
    {'id': 2, 'name': 'Fill in Blank'},
    {'id': 3, 'name': 'Group Reading'},
  ];

  void _addRule() {
    setState(() {
      _rules.add({
        'skillId': null,
        'diffId': null,
        'catId': null,
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

  Timer? _debounce;

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
        ToastHelper.show(context, 'Tạo ma trận thành công!');
        widget.onSaved();
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ToastHelper.show(context, 'Lỗi: $e', isError: true);
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
        title: const Text('Tạo Ma Trận Mới', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 1,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Thông tin chung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _titleController,
                      decoration: const InputDecoration(labelText: 'Tên Ma Trận', border: OutlineInputBorder()),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _descController,
                      decoration: const InputDecoration(labelText: 'Mô tả ngắn', border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Cấu trúc Đề thi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
                Chip(
                  label: Text('Tổng: $_totalQuestions câu', style: const TextStyle(fontWeight: FontWeight.bold)),
                  backgroundColor: const Color(0xFFE0F2FE),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ..._rules.asMap().entries.map((entry) {
              int idx = entry.key;
              var rule = entry.value;
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: 'Kỹ năng'),
                          value: rule['skillId'],
                          items: _skills.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                          onChanged: (val) {
                            setState(() => rule['skillId'] = val);
                            _checkAvailable(idx);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: 'Độ khó'),
                          value: rule['diffId'],
                          items: _difficulties.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                          onChanged: (val) {
                            setState(() => rule['diffId'] = val);
                            _checkAvailable(idx);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(labelText: 'Loại câu'),
                          value: rule['catId'],
                          items: _categories.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                          onChanged: (val) {
                            setState(() => rule['catId'] = val);
                            _checkAvailable(idx);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            TextFormField(
                              decoration: const InputDecoration(labelText: 'Số lượng'),
                              keyboardType: TextInputType.number,
                              initialValue: rule['quantity'].toString(),
                              onChanged: (val) {
                                setState(() {
                                  rule['quantity'] = int.tryParse(val) ?? 0;
                                });
                              },
                            ),
                            if (rule['isChecking'])
                              const Padding(padding: EdgeInsets.only(top: 4), child: Text('Đang kiểm tra...', style: TextStyle(fontSize: 12, color: Colors.grey)))
                            else if (rule['available'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 4), 
                                child: Text('Kho: ${rule['available']} câu', style: TextStyle(fontSize: 12, color: rule['available'] < rule['quantity'] ? Colors.red : Colors.green)),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeRule(idx),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
            InkWell(
              onTap: _addRule,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey, style: BorderStyle.none),
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('+ Thêm quy tắc mới', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isValid && !_isSaving ? _saveMatrix : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20B486),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade300,
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Lưu Ma Trận', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
