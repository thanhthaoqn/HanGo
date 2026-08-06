import 'package:flutter/material.dart';
import '../../../domain/entities/learning_pathway.dart';
import '../../pages/course/course_detail_page.dart';

class InteractiveNodeTree extends StatelessWidget {
  final List<PathwayNode> nodes;
  final Function(PathwayNode) onNodeTap;
  final PathwayNode? selectedNode;
  final bool isDarkMode;
  final EdgeInsetsGeometry? contentPadding;

  const InteractiveNodeTree({
    super.key,
    required this.nodes,
    required this.onNodeTap,
    this.selectedNode,
    this.isDarkMode = false,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: contentPadding ?? const EdgeInsets.fromLTRB(22, 18, 22, 28),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        final isLast = index == nodes.length - 1;
        final alignLeft = index.isEven;

        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Duration(milliseconds: 280 + index * 70),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 18 * (1 - value)),
                child: child,
              ),
            );
          },
          child: _NodeRow(
            node: node,
            isLast: isLast,
            alignLeft: alignLeft,
            isSelected: selectedNode?.step == node.step,
            isDarkMode: isDarkMode,
            onTap: () => onNodeTap(node),
          ),
        );
      },
    );
  }
}
class _NodeRow extends StatelessWidget {
  final PathwayNode node;
  final bool isLast;
  final bool alignLeft;
  final bool isSelected;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _NodeRow({
    required this.node,
    required this.isLast,
    required this.alignLeft,
    required this.isSelected,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 720;
    final cardWidth = isCompact ? double.infinity : 310.0;
    final connectorColor = node.status == NodeStatus.completed
        ? const Color(0xFF10B981)
        : isDarkMode
        ? const Color(0xFF30363D)
        : const Color(0xFFD7DEE8);

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 168),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          Positioned(
            top: 36,
            bottom: isLast ? null : -8,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 3,
              height: isLast ? 44 : null,
              decoration: BoxDecoration(
                color: connectorColor,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          Align(
            alignment: isCompact
                ? Alignment.center
                : alignLeft
                ? Alignment.centerLeft
                : Alignment.centerRight,
            child: Padding(
              padding: isCompact
                  ? const EdgeInsets.only(bottom: 38)
                  : EdgeInsets.only(
                      left: alignLeft ? 28 : 96,
                      right: alignLeft ? 96 : 28,
                      bottom: 24,
                    ),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: onTap,
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    scale: isSelected ? 1.025 : 1,
                    child: SizedBox(
                      width: cardWidth,
                      child: _NodeCard(
                        node: node,
                        isSelected: isSelected,
                        isDarkMode: isDarkMode,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          _StepBadge(node: node, isDarkMode: isDarkMode),
        ],
      ),
    );
  }
}

class _NodeCard extends StatelessWidget {
  final PathwayNode node;
  final bool isSelected;
  final bool isDarkMode;

  const _NodeCard({
    required this.node,
    required this.isSelected,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final palette = _NodePalette.forStatus(node.status, isDarkMode);
    final effectiveProgress = node.status == NodeStatus.completed
        ? 100
        : node.progressPercent.clamp(0, 100);
    final lessonText = node.totalLessons > 0
        ? '${node.completedLessons}/${node.totalLessons} lessons'
        : 'Course step';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: palette.gradient,
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? const Color(0xFF28B79B) : palette.border,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isSelected ? const Color(0xFF28B79B) : palette.glow)
                .withOpacity(isSelected ? 0.28 : 0.14),
            blurRadius: isSelected || node.status == NodeStatus.inProgress
                ? 22
                : 10,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _StatusPill(status: node.status, isDarkMode: isDarkMode),
              const Spacer(),
              Text(
                'Step ${node.step}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: palette.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            node.courseTitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              height: 1.25,
              color: palette.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            lessonText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: palette.muted,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...node.tags
                  .take(3)
                  .map(
                    (tag) => _SkillTag(
                      label: tag,
                      status: node.status,
                      isDarkMode: isDarkMode,
                    ),
                  ),
              if (node.skillType != null && node.tags.isEmpty)
                _SkillTag(
                  label: node.skillType!,
                  status: node.status,
                  isDarkMode: isDarkMode,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _ScheduleChip(node: node, isDarkMode: isDarkMode),
          const SizedBox(height: 10),
          _ProgressBar(
            percent: effectiveProgress,
            status: node.status,
            isDarkMode: isDarkMode,
          ),
          if (node.status != NodeStatus.locked && node.courseId > 0) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => CourseDetailPage(courseId: node.courseId),
                    ),
                  );
                },
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Vào học'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDarkMode ? const Color(0xFF6366F1) : const Color(0xFF4F46E5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  final PathwayNode node;
  final bool isDarkMode;

  const _StepBadge({required this.node, required this.isDarkMode});

  String _nodeTypeLabel(NodeType type) {
    switch (type) {
      case NodeType.fastTrackSkipped:
        return 'Fast-track';
      case NodeType.detourRemedial:
        return 'Detour';
      case NodeType.merged:
        return 'Merged';
      case NodeType.normal:
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final nodeTypeLabel = _nodeTypeLabel(node.nodeType);
    final color = switch (node.status) {
      NodeStatus.completed => const Color(0xFF10B981),
      NodeStatus.inProgress => const Color(0xFF28B79B),
      NodeStatus.locked =>
        isDarkMode ? const Color(0xFF30363D) : const Color(0xFFCBD5E1),
    };
    final icon = switch (node.status) {
      NodeStatus.completed => Icons.check_rounded,
      NodeStatus.inProgress => Icons.play_arrow_rounded,
      NodeStatus.locked => Icons.lock_rounded,
    };

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          color: isDarkMode ? const Color(0xFF0D1117) : Colors.white,
          width: 4,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.28),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: nodeTypeLabel.isEmpty
          ? Icon(icon, color: Colors.white, size: 22)
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 3),
                Text(
                  nodeTypeLabel,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
              ],
            ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final NodeStatus status;
  final bool isDarkMode;

  const _StatusPill({required this.status, required this.isDarkMode});

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final IconData icon;
    late final Color color;
    switch (status) {
      case NodeStatus.completed:
        label = 'Completed';
        icon = Icons.check_circle_rounded;
        color = const Color(0xFF10B981);
        break;
      case NodeStatus.inProgress:
        label = 'In Progress';
        icon = Icons.play_circle_fill_rounded;
        color = const Color(0xFF28B79B);
        break;
      case NodeStatus.locked:
        label = 'Locked';
        icon = Icons.lock_rounded;
        color = const Color(0xFF94A3B8);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDarkMode ? 0.18 : 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillTag extends StatelessWidget {
  final String label;
  final NodeStatus status;
  final bool isDarkMode;

  const _SkillTag({
    required this.label,
    required this.status,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final locked = status == NodeStatus.locked;
    final color = locked ? const Color(0xFF94A3B8) : const Color(0xFF6366F1);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(isDarkMode ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ScheduleChip extends StatelessWidget {
  final PathwayNode node;
  final bool isDarkMode;

  const _ScheduleChip({required this.node, required this.isDarkMode});

  String _formatDate(DateTime d) {
    final day = d.day.toString().padLeft(2, '0');
    final month = d.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  @override
  Widget build(BuildContext context) {
    final startDate = node.startDate;
    final deadline = node.deadline;
    if (startDate == null && deadline == null) return const SizedBox.shrink();

    final status = node.scheduleStatus ?? ScheduleStatus.onTrack;

    Color bg;
    Color fg;
    String label;

    switch (status) {
      case ScheduleStatus.behind:
        bg = const Color(0xFFDC2626);
        fg = Colors.white;
        label = 'Behind';
        break;
      case ScheduleStatus.atRisk:
        bg = const Color(0xFFF59E0B);
        fg = Colors.black;
        label = 'At risk';
        break;
      case ScheduleStatus.completed:
        bg = const Color(0xFF10B981);
        fg = Colors.white;
        label = 'Completed';
        break;
      case ScheduleStatus.onTrack:
      default:
        bg = const Color(0xFF28B79B);
        fg = Colors.white;
        label = 'On track';
        break;
    }

    final hours = node.estimatedHours;
    final dateText = startDate != null && deadline != null
        ? '${_formatDate(startDate)} - ${_formatDate(deadline)}'
        : _formatDate(startDate ?? deadline!);
    final hoursText = hours != null ? ' | ${hours}h' : '';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg.withOpacity(isDarkMode ? 0.26 : 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: bg.withOpacity(0.45)),
        ),
        child: Text(
          '$label | $dateText$hoursText',
          style: TextStyle(
            color: fg,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final int percent;
  final NodeStatus status;
  final bool isDarkMode;

  const _ProgressBar({
    required this.percent,
    required this.status,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final color = status == NodeStatus.completed
        ? const Color(0xFF10B981)
        : const Color(0xFF28B79B);
    final track = isDarkMode
        ? const Color(0xFF30363D)
        : const Color(0xFFE2E8F0);

    // Keep the progress height controlled via a parent SizedBox/ClipRRect instead.

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$percent%',
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: percent / 100),
            duration: const Duration(milliseconds: 520),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => SizedBox(
              height: 7,
              child: LinearProgressIndicator(
                value: value,
                backgroundColor: track,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _NodePalette {
  final Color surface;
  final Color border;
  final Color text;
  final Color muted;
  final Color glow;
  final Gradient? gradient;

  const _NodePalette({
    required this.surface,
    required this.border,
    required this.text,
    required this.muted,
    required this.glow,
    this.gradient,
  });

  static _NodePalette forStatus(NodeStatus status, bool dark) {
    if (status == NodeStatus.completed) {
      return _NodePalette(
        surface: const Color(0xFF063F32),
        border: const Color(0xFF10B981),
        text: Colors.white,
        muted: const Color(0xFFD1FAE5),
        glow: const Color(0xFF10B981),
        gradient: const LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF10B981)],
        ),
      );
    }
    if (status == NodeStatus.inProgress) {
      return _NodePalette(
        surface: dark ? const Color(0xFF12332F) : Colors.white,
        border: const Color(0xFF28B79B),
        text: dark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A),
        muted: dark ? const Color(0xFFB7C4D3) : const Color(0xFF64748B),
        glow: const Color(0xFF28B79B),
        gradient: dark
            ? const LinearGradient(
                colors: [Color(0xFF12332F), Color(0xFF161B22)],
              )
            : null,
      );
    }
    return _NodePalette(
      surface: dark ? const Color(0xFF161B22) : Colors.white,
      border: dark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0),
      text: dark ? const Color(0xFF8B949E) : const Color(0xFF64748B),
      muted: const Color(0xFF94A3B8),
      glow: dark ? Colors.black : const Color(0xFFCBD5E1),
    );
  }
}
