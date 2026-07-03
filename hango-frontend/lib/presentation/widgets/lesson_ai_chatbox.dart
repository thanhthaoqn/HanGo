import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hango/domain/model/ai_health.dart';
import 'package:hango/domain/model/ai_models.dart';
import 'package:hango/services/app_state.dart';
import 'package:hango/utils/app_theme.dart';

import 'lesson_ai_chatbox_quick_questions.dart';
import 'lesson_ai_chatbox_default_questions.dart';
import 'lesson_ai_chatbox_empty_state.dart';

class LessonAiChatbox extends StatefulWidget {
  const LessonAiChatbox({
    super.key,
    required this.lessonId,
    required this.lessonTitle,
  });

  final int lessonId;
  final String lessonTitle;

  @override
  State<LessonAiChatbox> createState() => _LessonAiChatboxState();
}

class _LessonAiChatboxState extends State<LessonAiChatbox> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  final List<AiMessage> _messages = [];
  Future<AiHealth>? _health;

  int? _conversationId;
  bool _sending = false;
  String? _error;

  static const int _maxCacheMessages = 200;

  String get _cacheKey => 'ai_chat_lesson_${widget.lessonId}';

  @override
  void initState() {
    super.initState();
    _health = context.read<AppState>().checkAiStatus();
    _loadFromCache().then((_) {
      // Khi mở chatbox: nếu cache có tin nhắn assistant kèm suggestedQuestions
      // thì UI sẽ tự render 3 câu gợi ý.
      // Nếu cache rỗng (đang chưa hỏi gì hoặc vừa xóa), messages sẽ rỗng
      // => UI hiển thị dòng hướng dẫn.
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant LessonAiChatbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lessonId != widget.lessonId) {
      setState(() {
        _conversationId = null;
        _messages.clear();
        _error = null;
      });
      _loadFromCache();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null || raw.trim().isEmpty) return;

      final data = jsonDecode(raw) as Map<String, dynamic>;
      final conversationId = (data['conversationId'] as num?)?.toInt();
      final messagesJson = (data['messages'] as List?) ?? const [];

      final loadedMessages = messagesJson
          .whereType<Map<String, dynamic>>()
          .map(AiMessage.fromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        _conversationId = conversationId;
        _messages
          ..clear()
          ..addAll(loadedMessages);
      });

      _scrollToEnd();
      _saveToCache();
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> _saveToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final trimmed = _messages.length <= _maxCacheMessages
          ? _messages
          : _messages.sublist(_messages.length - _maxCacheMessages);

      final payload = {
        'conversationId': _conversationId,
        'messages': trimmed
            .map(
              (m) => {
                'role': m.role,
                'content': m.content,
                'createdAt': m.createdAt?.toIso8601String(),
                'wasOutOfScope': m.wasOutOfScope,
                'suggestedQuestions': m.suggestedQuestions,
              },
            )
            .toList(),
      };

      await prefs.setString(_cacheKey, jsonEncode(payload));
    } catch (_) {
      // ignore cache errors
    }
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    if (!mounted) return;
    setState(() {
      _conversationId = null;
      _messages.clear();
      _error = null;
      _messageController.clear();
    });

    // Sau khi xóa, nếu không có tin nhắn nào thì không có suggestedQuestions.
    // UX sẽ hiển thị lại dòng hướng dẫn hiện có.
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() {
      _sending = true;
      _error = null;
      _messages.add(AiMessage(role: 'USER', content: text));
      _messageController.clear();
    });
    _scrollToEnd();

    try {
      final response = await context.read<AppState>().sendAiMessage(
        lessonId: widget.lessonId,
        conversationId: _conversationId,
        message: text,
      );

      setState(() {
        _conversationId = response.conversationId;
        _messages.add(
          AiMessage(
            role: 'ASSISTANT',
            content: response.reply,
            wasOutOfScope: response.wasOutOfScope,
            suggestedQuestions: response.suggestedQuestions,
          ),
        );
      });

      _scrollToEnd();
      _saveToCache();
    } catch (e) {
      setState(() {
        _error = e.toString();
        if (_messages.isNotEmpty && _messages.last.role == 'USER') {
          _messages.removeLast();
        }
      });
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final panelWidth = constraints.maxWidth;
        final panelHeight = MediaQuery.sizeOf(context).height;

        return SizedBox(
          width: panelWidth,
          height: panelHeight,
          child: _ChatPanel(
            width: panelWidth,
            height: panelHeight,
            lessonTitle: widget.lessonTitle,
            messages: _messages,
            error: _error,
            sending: _sending,
            controller: _messageController,
            scroll: _scrollController,
            health: _health ?? context.read<AppState>().checkAiStatus(),
            onSend: _send,
            onClearHistory: _clearHistory,
          ),
        );
      },
    );
  }
}

class _ChatPanel extends StatelessWidget {
  const _ChatPanel({
    required this.width,
    required this.height,
    required this.lessonTitle,
    required this.messages,
    required this.error,
    required this.sending,
    required this.controller,
    required this.scroll,
    required this.health,
    required this.onSend,
    required this.onClearHistory,
  });

  final double width;
  final double height;
  final String lessonTitle;
  final List<AiMessage> messages;
  final String? error;
  final bool sending;
  final TextEditingController controller;
  final ScrollController scroll;
  final Future<AiHealth> health;
  final Future<void> Function() onSend;
  final Future<void> Function() onClearHistory;

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(8),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: width,
        height: height,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.line)),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.emerald,
                    child: Icon(
                      Icons.psychology_alt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lessonTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        FutureBuilder<AiHealth>(
                          future: health,
                          builder: (context, snapshot) {
                            final available = snapshot.data?.available == true;
                            final waiting =
                                snapshot.connectionState ==
                                ConnectionState.waiting;
                            return Row(
                              children: [
                                Icon(
                                  waiting
                                      ? Icons.sync_rounded
                                      : available
                                      ? Icons.check_circle_rounded
                                      : Icons.error_outline_rounded,
                                  size: 14,
                                  color: waiting
                                      ? AppTheme.muted
                                      : available
                                      ? AppTheme.emerald
                                      : const Color(0xFFE11D48),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    waiting
                                        ? 'Đang kiểm tra AI...'
                                        : snapshot.data?.message ??
                                              'Chưa kiểm tra AI',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppTheme.muted,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Xóa lịch sử chat (chỉ trên thiết bị)',
                    onPressed: sending
                        ? null
                        : () async {
                            final ok =
                                await showDialog<bool>(
                                  context: context,
                                  builder: (context) {
                                    return AlertDialog(
                                      title: const Text('Xác nhận xóa lịch sử'),
                                      content: const Text(
                                        'Bạn có chắc muốn xóa lịch sử chat này không?\n\nThao tác này chỉ xóa dữ liệu trên thiết bị.',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(false);
                                          },
                                          child: const Text('Hủy'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            Navigator.of(context).pop(true);
                                          },
                                          child: const Text('Xóa'),
                                        ),
                                      ],
                                    );
                                  },
                                ) ??
                                false;

                            if (ok) {
                              await onClearHistory();
                            }
                          },
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ),
            Expanded(
              child: messages.isEmpty
                  ? LessonAiChatboxEmptyState(
                      title: 'Gợi ý câu hỏi để bắt đầu học',
                      questions: defaultLessonAiSuggestedQuestions(),
                      onTapQuestion: (q) {
                        controller.text = q;
                        controller.selection =
                            TextSelection.collapsed(offset: q.length);
                        onSend();
                      },
                    )
                  : ListView.builder(
                      controller: scroll,
                      padding: const EdgeInsets.all(14),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg = messages[index];
                        return Column(
                          crossAxisAlignment: msg.role == 'USER'
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            _ChatBubble(message: msg),
                            if (msg.role != 'USER' &&
                                msg.suggestedQuestions.isNotEmpty)
                              QuickQuestionsRow(
                                questions: msg.suggestedQuestions,
                                onTapQuestion: (q) {
                                  controller.text = q;
                                  controller.selection =
                                      TextSelection.collapsed(offset: q.length);
                                  onSend();
                                },
                              ),
                          ],
                        );
                      },
                    ),
            ),

            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: _InlineError(message: error!),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 500,
                      onSubmitted: (_) => onSend(),
                      decoration: const InputDecoration(
                        hintText: 'Nhập câu hỏi trong bài học...',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF28B79B),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.all(Radius.circular(10)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    tooltip: 'Gửi',
                    onPressed: sending ? null : onSend,
                    icon: sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final AiMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == 'USER';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1e9),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? AppTheme.emerald : const Color(0xFFEAF3EE),
          borderRadius: BorderRadius.circular(8),
          border: message.wasOutOfScope
              ? Border.all(color: const Color(0xFFE11D48))
              : null,
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: mine ? Colors.white : AppTheme.ink,
            height: 1.42,
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFBE123C)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFF9F1239), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
