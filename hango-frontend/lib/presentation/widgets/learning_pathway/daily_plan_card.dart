import 'package:flutter/material.dart';
import '../../../domain/entities/learning_pathway.dart';

class DailyPlanCard extends StatelessWidget {
  final LearningPathway pathway;
  final bool isDarkMode;
  final Function(PathwayNode) onStartLearning;
  final Function(PathwayNode) onTakeMastery;
  final Function(PathwayNode) onReview;

  const DailyPlanCard({
    Key? key,
    required this.pathway,
    required this.isDarkMode,
    required this.onStartLearning,
    required this.onTakeMastery,
    required this.onReview,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final reviewNodes = pathway.nodes.where((n) => n.isMastered && n.isReviewDue).toList();
    final learnNodes = pathway.nodes.where((n) => n.status == NodeStatus.inProgress || n.status == NodeStatus.locked).toList();
    final unmasteredNodes = pathway.nodes.where((n) => n.status == NodeStatus.completed && !n.isMastered).toList();

    // Pick 1 review, 1 learn, 1 mastery task if available
    PathwayNode? reviewTask = reviewNodes.isNotEmpty ? reviewNodes.first : null;
    PathwayNode? masteryTask = unmasteredNodes.isNotEmpty ? unmasteredNodes.first : null;
    PathwayNode? learnTask = learnNodes.isNotEmpty ? learnNodes.first : null;

    if (reviewTask == null && learnTask == null && masteryTask == null) {
      return const SizedBox.shrink(); // Nothing to do today!
    }

    int totalMinutes = 0;
    if (reviewTask != null) totalMinutes += 10;
    if (masteryTask != null) totalMinutes += 15;
    if (learnTask != null) totalMinutes += 20;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDarkMode ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDarkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.wb_sunny_rounded, color: Color(0xFF6366F1), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today\'s Plan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    Text(
                      '~ $totalMinutes mins of learning',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          if (reviewTask != null)
            _PlanItem(
              title: reviewTask.courseTitle,
              subtitle: 'Review due',
              icon: Icons.replay_rounded,
              color: const Color(0xFFF59E0B),
              buttonText: 'Review Now',
              isDarkMode: isDarkMode,
              onTap: () => onReview(reviewTask),
            ),
            
          if (masteryTask != null) ...[
            if (reviewTask != null) const SizedBox(height: 12),
            _PlanItem(
              title: masteryTask.courseTitle,
              subtitle: 'Mastery required',
              icon: Icons.workspace_premium_rounded,
              color: const Color(0xFFEC4899),
              buttonText: 'Take Mastery Quiz',
              isDarkMode: isDarkMode,
              onTap: () => onTakeMastery(masteryTask),
            ),
          ],
            
          if (learnTask != null) ...[
            if (reviewTask != null || masteryTask != null) const SizedBox(height: 12),
            _PlanItem(
              title: learnTask.courseTitle,
              subtitle: 'Continue learning',
              icon: Icons.play_arrow_rounded,
              color: const Color(0xFF10B981),
              buttonText: 'Start Learning',
              isDarkMode: isDarkMode,
              onTap: () => onStartLearning(learnTask),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlanItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String buttonText;
  final bool isDarkMode;
  final VoidCallback onTap;

  const _PlanItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.buttonText,
    required this.isDarkMode,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(isDarkMode ? 0.1 : 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(isDarkMode ? 0.2 : 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDarkMode ? Colors.white : const Color(0xFF0F172A),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(buttonText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
