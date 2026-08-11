import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:http/http.dart' as http;
import '../../../utils/config.dart';
import '../../../data/services/auth_service.dart';

/// Read-only timeline of everything that happened to a single exam - from
/// creation through submit/reject/publish cycles and any edits made after
/// publish. Unlike course versioning, this never creates a new exam row;
/// it's an append-only activity log for the one exam.
class ExamHistoryDialog extends StatefulWidget {
  final int examId;
  final String examTitle;

  const ExamHistoryDialog({
    super.key,
    required this.examId,
    required this.examTitle,
  });

  @override
  State<ExamHistoryDialog> createState() => _ExamHistoryDialogState();
}

class _ExamHistoryDialogState extends State<ExamHistoryDialog> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  String? _error;
  List<dynamic> _logs = [];

  String get apiBaseUrl => EnvConfig.v1BaseUrl;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final token = await _authService.getToken();
      if (token == null) {
        throw Exception('Authentication token not found');
      }

      final uri = Uri.parse('$apiBaseUrl/trainer/exams/${widget.examId}/history');
      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _logs = data is List ? data : [];
          _isLoading = false;
        });
      } else if (response.statusCode == 403) {
        setState(() {
          _error = "You are not authorized to view this exam's history.";
          _isLoading = false;
        });
      } else {
        throw Exception('Failed to load history: ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load history: $e';
        _isLoading = false;
      });
    }
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '';
    try {
      final dt = DateTime.parse(value.toString());
      return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return value.toString();
    }
  }

  ({IconData icon, Color color, String label}) _actionMeta(String action) {
    switch (action.toUpperCase()) {
      case 'CREATED':
        return (icon: Icons.add_circle_outline, color: const Color(0xFF64748B), label: 'created this exam');
      case 'EDITED':
        return (icon: Icons.edit_outlined, color: const Color(0xFF3B82F6), label: 'edited the exam content');
      case 'SUBMITTED':
        return (icon: Icons.send_outlined, color: const Color(0xFFD97706), label: 'submitted this exam for review');
      case 'REJECTED':
        return (icon: Icons.cancel_outlined, color: const Color(0xFFEF4444), label: 'rejected this exam');
      case 'PUBLISHED':
        return (icon: Icons.check_circle_outline, color: const Color(0xFF20B486), label: 'published this exam');
      case 'HIDDEN':
        return (icon: Icons.visibility_off_outlined, color: const Color(0xFF94A3B8), label: 'hid this exam');
      case 'UNHIDDEN':
        return (icon: Icons.visibility_outlined, color: const Color(0xFF20B486), label: 'unhid this exam');
      default:
        return (icon: Icons.circle_outlined, color: const Color(0xFF94A3B8), label: action.toLowerCase());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: const Color(0xFFF8FAFC),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 750),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildHeader(),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Exam History',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'Outfit',
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.examTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF64748B)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF20B486)));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFEF4444), fontFamily: 'Outfit'),
          ),
        ),
      );
    }
    if (_logs.isEmpty) {
      return const Center(
        child: Text(
          'No history recorded yet.',
          style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _logs.length,
      itemBuilder: (context, index) {
        final log = _logs[index] as Map<String, dynamic>;
        final isLast = index == _logs.length - 1;
        return _buildLogEntry(log, isLast);
      },
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log, bool isLast) {
    final action = log['action']?.toString() ?? '';
    final meta = _actionMeta(action);
    final actorName = log['actorName']?.toString() ?? 'System';
    final reason = log['reason']?.toString();
    final diffRaw = log['diff']?.toString();

    Map<String, dynamic>? diff;
    if (diffRaw != null && diffRaw.isNotEmpty) {
      try {
        diff = jsonDecode(diffRaw) as Map<String, dynamic>;
      } catch (_) {
        diff = null;
      }
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: meta.color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(meta.icon, size: 18, color: meta.color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(width: 2, color: const Color(0xFFE2E8F0)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                      children: [
                        TextSpan(
                          text: actorName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(text: ' ${meta.label}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDateTime(log['createdAt']),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  if (reason != null && reason.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: MarkdownBody(
                        data: reason.replaceAll('\\n', '\n'),
                        styleSheet: MarkdownStyleSheet(
                          p: const TextStyle(fontSize: 13, color: Color(0xFF7F1D1D)),
                        ),
                      ),
                    ),
                  ],
                  if (diff != null) ...[
                    const SizedBox(height: 8),
                    _buildDiffSummary(diff),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffSummary(Map<String, dynamic> diff) {
    final changed = (diff['changedQuestions'] as List?) ?? [];
    final added = (diff['addedQuestions'] as List?) ?? [];
    final removed = (diff['removedQuestions'] as List?) ?? [];

    if (changed.isEmpty && added.isEmpty && removed.isEmpty) {
      return const Text(
        'No question content changes detected.',
        style: TextStyle(
          fontSize: 12.5,
          fontStyle: FontStyle.italic,
          color: Color(0xFF94A3B8),
          fontFamily: 'Outfit',
        ),
      );
    }

    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: EdgeInsets.zero,
        dense: true,
        title: Text(
          [
            if (changed.isNotEmpty) '${changed.length} question(s) changed',
            if (added.isNotEmpty) '${added.length} added',
            if (removed.isNotEmpty) '${removed.length} removed',
          ].join(', '),
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF3B82F6),
            fontFamily: 'Outfit',
          ),
        ),
        children: [
          ...changed.map((q) => _buildChangedQuestionTile(q as Map<String, dynamic>)),
          ...added.map((q) => _buildSimpleQuestionTile(q as Map<String, dynamic>, 'Added', const Color(0xFF20B486))),
          ...removed.map((q) => _buildSimpleQuestionTile(q as Map<String, dynamic>, 'Removed', const Color(0xFFEF4444))),
        ],
      ),
    );
  }

  Widget _buildChangedQuestionTile(Map<String, dynamic> q) {
    final questionText = q['questionText']?.toString() ?? '';
    final fields = (q['changedFields'] as List?) ?? [];
    final options = (q['changedOptions'] as List?) ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            questionText.isNotEmpty ? questionText : 'Question ${(q['questionIndex'] ?? 0) + 1}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
          ),
          for (final f in fields) _buildChangeLine('${f['field']}', f['before'], f['after']),
          for (final o in options)
            _buildChangeLine('option ${(o['optionIndex'] as int? ?? 0) + 1} (${o['field']})', o['before'], o['after']),
        ],
      ),
    );
  }

  Widget _buildSimpleQuestionTile(Map<String, dynamic> q, String label, Color color) {
    final questionText = q['questionText']?.toString() ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: color)),
          Expanded(
            child: Text(
              questionText.isNotEmpty ? questionText : 'Question ${(q['questionIndex'] ?? 0) + 1}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChangeLine(String field, dynamic before, dynamic after) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '• $field: "${before ?? '-'}" → "${after ?? '-'}"',
        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
      ),
    );
  }
}
