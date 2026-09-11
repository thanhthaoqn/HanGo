import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:hango/domain/model/ai_health.dart';
import 'package:hango/domain/model/ai_models.dart';
import 'package:hango/services/app_state.dart';
import 'package:hango/utils/app_theme.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

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

  /// Loads the AI chat history (up to max limit) from the local device cache (SharedPreferences).
  /// This prevents the user from losing their chat context when they navigate away and return.
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

  /// Saves the current chat history to the local device cache.
  /// To optimize storage, it trims the history and only saves the last [_maxCacheMessages] messages.
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

  /// Clears the chat history from both the local device cache and the UI state.
  /// Allows the user to start a fresh conversation with the AI Assistant.
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

  /// Handles the process of sending a user's message to the backend AI service.
  /// It updates the UI optimistically, calls the provider, and handles any network errors gracefully.
  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    // Optimistic UI: them tin nhan user vao man hinh NGAY truoc khi goi API
    setState(() {
      _sending = true;
      _error = null;
      _messages.add(AiMessage(role: 'USER', content: text));
      _messageController.clear();
    });
    _scrollToEnd();

    try {
      // Goi qua AppState -> HTTP POST /api/v1/ai-assistant/messages
      final response = await context.read<AppState>().sendAiMessage(
        lessonId: widget.lessonId,
        conversationId: _conversationId,
        message: text,
      );

      // Them tin nhan ASSISTANT vao UI va luu cache local (SharedPreferences)
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
      // Neu loi: hien thong bao va RUT lai tin nhan user vua gui (roll-back optimistic UI)
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
      elevation: 16,
      shadowColor: Colors.black.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        ),
        child: Column(
          children: [
            // 1. HEADER: Contains the top decorative gradient line
            // Top Accent Gradient Line
            Container(
              height: 4,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF28B79B), Color(0xFF0D9488)],
                ),
              ),
            ),
            // 2. HEADER CONTENT: Contains AI Logo, Lesson Title, Health Status, and Clear History Button
            // Header
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
              decoration: const BoxDecoration(
                color: Color(0xFFFCFDFE),
                border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF28B79B), Color(0xFF0D9488)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.emerald.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.psychology_alt_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'HanGo AI Assistant',
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE6F7F4),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'ACTIVE',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF28B79B),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lessonTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
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
                                  size: 11,
                                  color: waiting
                                      ? const Color(0xFF94A3B8)
                                      : available
                                      ? const Color(0xFF10B981)
                                      : const Color(0xFFE11D48),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    waiting
                                        ? 'Connecting AI...'
                                        : snapshot.data?.message ??
                                              'Ready to answer',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: waiting
                                          ? const Color(0xFF94A3B8)
                                          : available
                                          ? const Color(0xFF10B981)
                                          : const Color(0xFFE11D48),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
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
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: IconButton(
                      tooltip: 'Clear chat history (local only)',
                      onPressed: sending
                          ? null
                          : () async {
                              final ok =
                                  await showDialog<bool>(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        title: const Row(
                                          children: [
                                            Icon(
                                              Icons.delete_sweep_rounded,
                                              color: Color(0xFFE11D48),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Clear chat history?',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        content: const Text(
                                          'All AI conversation history for this lesson on this device will be cleared so you can start fresh.',
                                          style: TextStyle(
                                            color: Color(0xFF475569),
                                            height: 1.5,
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(
                                              context,
                                            ).pop(false),
                                            child: const Text(
                                              'Cancel',
                                              style: TextStyle(
                                                color: Color(0xFF64748B),
                                              ),
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFE11D48,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onPressed: () =>
                                                Navigator.of(context).pop(true),
                                            child: const Text('Clear history'),
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
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Color(0xFF94A3B8),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. MESSAGES AREA: The central chat view.
            // Uses Expanded to automatically fill the remaining space between the Header and the Input Bar.
            // Messages Area
            Expanded(
              child: Container(
                color: const Color(0xFFFAFCFF),
                child: messages.isEmpty
                    // 3A. IF NO MESSAGES YET: Show the Empty State screen with 3 random suggested prompts.
                    ? LessonAiChatboxEmptyState(
                        title:
                            'Select a suggested prompt below or ask any question to get detailed answers about this lesson.',
                        questions: defaultLessonAiSuggestedQuestions(),
                        onTapQuestion: (q) {
                          controller.text = q;
                          controller.selection = TextSelection.collapsed(
                            offset: q.length,
                          );
                          onSend();
                        },
                      )
                    // 3B. IF MESSAGES EXIST: Use ListView.builder to render the chat history vertically.
                    : ListView.builder(
                        controller: scroll,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final msg = messages[index];
                          return Column(
                            // Alignment: User messages on the Right (end), AI messages on the Left (start).
                            crossAxisAlignment: msg.role == 'USER'
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              // Render the chat bubble (Contains text and Markdown styling).
                              _ChatBubble(message: msg),
                              // 3C. SUGGESTED QUESTIONS: If it's an AI message and contains suggestions, render the quick questions row below it.
                              if (msg.role != 'USER' &&
                                  msg.suggestedQuestions.isNotEmpty)
                                QuickQuestionsRow(
                                  questions: msg.suggestedQuestions,
                                  onTapQuestion: (q) {
                                    controller.text = q;
                                    controller.selection =
                                        TextSelection.collapsed(
                                          offset: q.length,
                                        );
                                    onSend();
                                  },
                                ),
                            ],
                          );
                        },
                      ),
              ),
            ),

            // 4. ERROR BANNER: Only displays when the error variable is not null (e.g., Network failure, Server down).
            if (error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: _InlineError(message: error!),
              ),
            // 5. BOTTOM INPUT BAR: The bottom chat area.
            // Contains the TextField for user input and a rounded square Send button.
            // Bottom Input Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: TextField(
                        controller: controller,
                        minLines: 1,
                        maxLines: 4,
                        maxLength: 500,
                        onSubmitted: (_) => onSend(),
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1E293B),
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Ask AI about this lesson...',
                          hintStyle: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 13,
                          ),
                          counterText: '',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  MouseRegion(
                    cursor: sending
                        ? SystemMouseCursors.basic
                        : SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: sending ? null : onSend,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: sending
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF94A3B8),
                                    Color(0xFF64748B),
                                  ],
                                )
                              : const LinearGradient(
                                  colors: [
                                    Color(0xFF28B79B),
                                    Color(0xFF0D9488),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                          shape: BoxShape.circle,
                          boxShadow: sending
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppTheme.emerald.withOpacity(0.35),
                                    blurRadius: 10,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: sending
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(
                                  Icons.send_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                        ),
                      ),
                    ),
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

    if (mine) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 320),
          margin: const EdgeInsets.only(bottom: 12, left: 32),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF28B79B), Color(0xFF0D9488)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(18),
              topRight: Radius.circular(18),
              bottomLeft: Radius.circular(18),
              bottomRight: Radius.circular(4),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.emerald.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: MarkdownBody(
            data: message.content,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: const TextStyle(
                    color: Colors.white,
                    height: 1.45,
                    fontSize: 13.5,
                  ),
                  strong: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  em: const TextStyle(
                    color: Colors.white,
                    fontStyle: FontStyle.italic,
                  ),
                  listBullet: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  code: const TextStyle(
                    color: Colors.white,
                    backgroundColor: Color(0x33000000),
                    fontSize: 12.5,
                  ),
                ),
          ),
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 360),
        margin: const EdgeInsets.only(bottom: 14, right: 24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(right: 10, top: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFFE6F7F4),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF28B79B).withOpacity(0.3),
                ),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                size: 14,
                color: Color(0xFF28B79B),
              ),
            ),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  border: Border.all(
                    color: message.wasOutOfScope
                        ? const Color(0xFFE11D48)
                        : const Color(0xFFE2E8F0),
                    width: message.wasOutOfScope ? 1.5 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.wasOutOfScope) ...[
                      Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: Color(0xFFE11D48),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Off-topic question',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFE11D48).withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                    ],
                    MarkdownBody(
                      data: message.content,
                      selectable: true,
                      styleSheet:
                          MarkdownStyleSheet.fromTheme(
                            Theme.of(context),
                          ).copyWith(
                            p: const TextStyle(
                              color: Color(0xFF1E293B),
                              height: 1.5,
                              fontSize: 13.5,
                            ),
                            strong: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontWeight: FontWeight.bold,
                            ),
                            em: const TextStyle(
                              color: Color(0xFF1E293B),
                              fontStyle: FontStyle.italic,
                            ),
                            h1: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                            h2: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 15.5,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                            h3: const TextStyle(
                              color: Color(0xFF0F172A),
                              fontSize: 14.5,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                            ),
                            listBullet: const TextStyle(
                              color: Color(0xFF28B79B),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            code: const TextStyle(
                              color: Color(0xFF0D9488),
                              backgroundColor: Color(0xFFF1F5F9),
                              fontSize: 12.5,
                            ),
                            codeblockPadding: const EdgeInsets.all(10),
                            codeblockDecoration: BoxDecoration(
                              color: const Color(0xFFF8FAFC),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFE2E8F0),
                              ),
                            ),
                            blockquoteDecoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                              border: const Border(
                                left: BorderSide(
                                  color: Color(0xFF28B79B),
                                  width: 3,
                                ),
                              ),
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        border: Border.all(color: const Color(0xFFFECACA)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFBE123C),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Color(0xFF9F1239),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
