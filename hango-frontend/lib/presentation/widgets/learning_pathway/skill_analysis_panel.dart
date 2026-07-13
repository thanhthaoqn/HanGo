import 'package:flutter/material.dart';
import '../../../utils/language_manager.dart';

class SkillAnalysisPanel extends StatelessWidget {
  final List<String> weakSkills;
  final int attemptsUsed;
  final bool isDarkMode;

  const SkillAnalysisPanel({
    super.key,
    required this.weakSkills,
    this.attemptsUsed = 0,
    this.isDarkMode = false,
  });

  static Map<String, dynamic> _getSkillMeta(String skill) {
    final lower = skill.toLowerCase();
    if (lower.contains('grammar') || lower.contains('ngữ pháp')) {
      return {'icon': Icons.edit_note_rounded, 'color': const Color(0xFF6366F1)};
    } else if (lower.contains('vocab') || lower.contains('từ vựng')) {
      return {'icon': Icons.local_library_rounded, 'color': const Color(0xFF10B981)};
    } else if (lower.contains('reading') || lower.contains('đọc')) {
      return {'icon': Icons.menu_book_rounded, 'color': const Color(0xFF28B79B)};
    } else if (lower.contains('listen') || lower.contains('nghe')) {
      return {'icon': Icons.headphones_rounded, 'color': const Color(0xFFF59E0B)};
    } else if (lower.contains('writing') || lower.contains('viết')) {
      return {'icon': Icons.draw_rounded, 'color': const Color(0xFFEF4444)};
    } else if (lower.contains('speaking') || lower.contains('nói')) {
      return {'icon': Icons.record_voice_over_rounded, 'color': const Color(0xFF8B5CF6)};
    }
    return {'icon': Icons.school_rounded, 'color': const Color(0xFF64748B)};
  }

  static int _genWeakPercent(int index) {
    return (45 - (index * 7)).clamp(15, 65);
  }

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageManager.isVi;
    final bg = isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final cardBorder = isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final titleColor = isDarkMode ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A);
    final subColor = isDarkMode ? const Color(0xFF8B949E) : const Color(0xFF64748B);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
        border: Border.all(color: cardBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.4 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: isDarkMode ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.analytics_rounded, color: Color(0xFF6366F1), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Phân tích điểm yếu kỹ năng' : 'Skill Weakness Analysis',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: titleColor, fontFamily: 'Outfit'),
                      ),
                      if (attemptsUsed > 0)
                        Text(
                          isVi ? 'Dựa trên $attemptsUsed bài thi gần nhất' : 'Based on $attemptsUsed recent exams',
                          style: TextStyle(fontSize: 12, color: subColor, fontFamily: 'Outfit'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (weakSkills.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.emoji_events_rounded, size: 48, color: Colors.amber.shade400),
                  const SizedBox(height: 12),
                  Text(
                    isVi ? 'Không phát hiện điểm yếu rõ ràng.\nTiếp tục luyện tập để duy trì!' : 'No major weaknesses found!\nKeep practicing to maintain!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: subColor, fontFamily: 'Outfit', height: 1.5),
                  ),
                ],
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Column(
                children: weakSkills.asMap().entries.map((entry) {
                  final meta = _getSkillMeta(entry.value);
                  return _SkillBar(
                    skill: entry.value,
                    percent: _genWeakPercent(entry.key),
                    color: meta['color'] as Color,
                    icon: meta['icon'] as IconData,
                    isDarkMode: isDarkMode,
                    delay: Duration(milliseconds: entry.key * 100),
                  );
                }).toList(),
              ),
            ),
          if (weakSkills.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFF6366F1), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isVi ? 'AI đề xuất tập trung vào: ${weakSkills.first}' : 'AI suggests focusing on: ${weakSkills.first}',
                        style: const TextStyle(color: Color(0xFF6366F1), fontSize: 13, fontWeight: FontWeight.w600, fontFamily: 'Outfit'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SkillBar extends StatefulWidget {
  final String skill;
  final int percent;
  final Color color;
  final IconData icon;
  final bool isDarkMode;
  final Duration delay;

  const _SkillBar({
    required this.skill, required this.percent, required this.color,
    required this.icon, required this.isDarkMode, required this.delay,
  });

  @override
  State<_SkillBar> createState() => _SkillBarState();
}

class _SkillBarState extends State<_SkillBar> with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);
    Future.delayed(widget.delay, () { if (mounted) _ctrl.forward(); });
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final trackColor = widget.isDarkMode ? const Color(0xFF21262D) : const Color(0xFFF1F5F9);
    final labelColor = widget.isDarkMode ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: widget.color.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                child: Icon(widget.icon, color: widget.color, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(widget.skill, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: labelColor, fontFamily: 'Outfit')),
              ),
              Text(
                '${widget.percent}% ${LanguageManager.isVi ? 'yếu' : 'weak'}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.color, fontFamily: 'Outfit'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: AnimatedBuilder(
              animation: _anim,
              builder: (_, __) => LinearProgressIndicator(
                value: widget.percent / 100.0 * _anim.value,
                backgroundColor: trackColor,
                valueColor: AlwaysStoppedAnimation<Color>(widget.color),
                minHeight: 8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
