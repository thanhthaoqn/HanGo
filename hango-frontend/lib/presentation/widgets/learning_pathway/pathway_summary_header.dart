import 'package:flutter/material.dart';
import '../../../domain/entities/learning_pathway.dart';
import '../../../utils/language_manager.dart';

class PathwaySummaryHeader extends StatelessWidget {
  final LearningPathway pathway;
  final bool isDarkMode;
  final VoidCallback? onAnalysisPressed;
  final VoidCallback? onReroutePressed;
  final VoidCallback? onThemeToggle;
  final VoidCallback? onEditGoalPressed;

  const PathwaySummaryHeader({
    super.key,
    required this.pathway,
    this.isDarkMode = false,
    this.onAnalysisPressed,
    this.onReroutePressed,
    this.onThemeToggle,
    this.onEditGoalPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isVi = LanguageManager.isVi;
    final overall = pathway.overallProgressPercent;
    final hasBadge =
        overall >= 100 ||
        (pathway.completedSteps > 0 &&
            pathway.completedSteps == pathway.totalSteps);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: BoxDecoration(
        gradient: isDarkMode
            ? const LinearGradient(
                colors: [Color(0xFF172033), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF28B79B), Color(0xFF1B8B75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withOpacity(0.25)
                : const Color(0xFF28B79B).withOpacity(0.20),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final showMetrics = constraints.maxWidth >= 560;
            final showGoalTime = constraints.maxWidth >= 680;
            final showWeakSkill =
                constraints.maxWidth >= 760 && pathway.weakSkills.isNotEmpty;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(
                  hasBadge ? Icons.emoji_events_rounded : Icons.route_rounded,
                  color: hasBadge ? Colors.amber : Colors.white,
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isVi ? 'Lộ trình học tập' : 'Learning Journey',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Outfit',
                        ),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: overall / 100.0,
                          backgroundColor: Colors.white.withOpacity(0.18),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                          minHeight: 4,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showMetrics) ...[
                  const SizedBox(width: 12),
                  _Metric(
                    value: '${pathway.completedSteps}/${pathway.totalSteps}',
                    label: isVi ? 'bước' : 'steps',
                  ),
                  const SizedBox(width: 8),
                  _Metric(value: '$overall%', label: isVi ? 'tiến độ' : 'done'),
                ],
                if (showGoalTime) ...[
                  const SizedBox(width: 8),
                  Flexible(child: _GoalTimeChip(pathway: pathway)),
                ],
                if (pathway.goalName != null && pathway.goalName!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: _GoalNameChip(goalName: pathway.goalName!),
                  ),
                ],
                if (showWeakSkill) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: _WeakSkillChip(skill: pathway.weakSkills.first),
                  ),
                ],
                const SizedBox(width: 8),
                if (onEditGoalPressed != null) ...[
                  _HeaderIconButton(
                    tooltip: isVi ? 'Chỉnh sửa mục tiêu' : 'Edit goal',
                    icon: Icons.edit_calendar_rounded,
                    color: Colors.white,
                    onPressed: onEditGoalPressed,
                  ),
                  const SizedBox(width: 6),
                ],
                _HeaderIconButton(
                  tooltip: isVi ? 'Phân tích kỹ năng' : 'Skill analysis',
                  icon: Icons.analytics_outlined,
                  color: Colors.white,
                  onPressed: onAnalysisPressed,
                ),
                const SizedBox(width: 6),
                _HeaderIconButton(
                  tooltip: isDarkMode
                      ? (isVi
                            ? 'Chuyển sang chế độ sáng'
                            : 'Switch to light mode')
                      : (isVi
                            ? 'Chuyển sang chế độ tối'
                            : 'Switch to dark mode'),
                  icon: isDarkMode
                      ? Icons.light_mode_rounded
                      : Icons.dark_mode_rounded,
                  color: isDarkMode ? const Color(0xFFFCD34D) : Colors.white,
                  onPressed: onThemeToggle,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GoalTimeChip extends StatelessWidget {
  final LearningPathway pathway;

  const _GoalTimeChip({required this.pathway});

  DateTime? _goalStart() {
    if (pathway.nodes.isEmpty) return null;
    final firstNode = pathway.nodes.first;
    if (firstNode.startDate != null) return firstNode.startDate;

    return pathway.nodes
        .map((node) => node.startDate)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (earliest, date) =>
              earliest == null || date.isBefore(earliest) ? date : earliest,
        );
  }

  DateTime? _goalEnd() {
    final target = pathway.targetDate;
    if (target != null && target.isNotEmpty) {
      final parsed = DateTime.tryParse(target);
      if (parsed != null) return parsed;
    }

    return pathway.nodes
        .map((node) => node.deadline)
        .whereType<DateTime>()
        .fold<DateTime?>(
          null,
          (latest, date) =>
              latest == null || date.isAfter(latest) ? date : latest,
        );
  }

  String _format(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  @override
  Widget build(BuildContext context) {
    final start = _goalStart();
    final end = _goalEnd();
    if (start == null && end == null) return const SizedBox.shrink();

    final label = start != null && end != null
        ? '${_format(start)} - ${_format(end)}'
        : _format(start ?? end!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_available_rounded,
            color: Colors.white.withOpacity(0.9),
            size: 15,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalNameChip extends StatelessWidget {
  final String goalName;

  const _GoalNameChip({required this.goalName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.flag_circle_rounded,
            color: Colors.amberAccent.withOpacity(0.9),
            size: 15,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              goalName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;

  const _Metric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }
}

class _WeakSkillChip extends StatelessWidget {
  final String skill;

  const _WeakSkillChip({required this.skill});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.lightbulb_outline_rounded,
            color: Colors.amber.withOpacity(0.95),
            size: 15,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              skill,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'Outfit',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _HeaderIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: color,
        iconSize: 20,
        visualDensity: VisualDensity.compact,
        style: IconButton.styleFrom(
          backgroundColor: Colors.white.withOpacity(0.12),
          minimumSize: const Size(36, 36),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
