import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/learning_pathway.dart';
import '../../domain/entities/learning_pathway_agentic_mocks.dart';

/// FE-only mock behavior for FE-11 (Agentic Upgrade Contract Mock).
///
/// This file extends the existing `PathwayRepository` contract without requiring backend changes.
/// UI reads the extra metadata if present.
class PathwayRepositoryAgenticMockExtension {
  static const String _kMockMode = 'pathway_agentic_mock_mode';
  static const String _kMockPendingRerouteAccepted =
      'pathway_agentic_mock_pending_accepted';

  bool isMockEnabled() {
    // Use a sticky toggle stored in shared preferences.
    // Default: enabled to let developers preview UI.
    // Developers can disable by setting key to false.
    throw UnimplementedError(
      'This class should be wired from PathwayRepository directly.',
    );
  }

  /// Mock pathway generator to simulate API response shape.
  LearningPathway buildMockPathway({required bool includePendingReroute}) {
    final now = DateTime.now();
    final nodes = <Map<String, dynamic>>[
      {
        'step': 1,
        'course_id': 101,
        'course_title': 'Grammar Foundations',
        'tags': ['basic grammar', 'tenses'],
        'status': 'COMPLETED',
        'reason_why': 'Strong performance on the entry assessment.',
        'progress_percent': 100,
        'skill_type': 'GRAMMAR',
        'total_lessons': 8,
        'completed_lessons': 8,
        'node_type': 'NORMAL',
        'schedule_status': 'ON_TRACK',
        'estimated_hours': 4,
        'deadline': now.subtract(const Duration(days: 2)).toIso8601String(),
      },
      {
        'step': 2,
        'course_id': 202,
        'course_title': 'Intermediate Grammar Practice',
        'tags': ['practice', 'error correction'],
        'status': includePendingReroute ? 'LOCKED' : 'IN_PROGRESS',
        'reason_why': includePendingReroute
            ? 'Fast-track opportunity detected.'
            : 'Continue practice.',
        'progress_percent': 0,
        'skill_type': 'GRAMMAR',
        'total_lessons': 10,
        'completed_lessons': 0,
        'node_type': includePendingReroute ? 'FAST_TRACK_SKIPPED' : 'NORMAL',
        'is_optional': true,
        'reroute_reason': includePendingReroute
            ? 'Suggested to skip step 2 due to excellent Step 1 results.'
            : null,
        'schedule_status': 'AT_RISK',
        'estimated_hours': 5,
        'deadline': now.add(const Duration(days: 3)).toIso8601String(),
      },
      {
        // Detour step 2.5 (detour remedial) - inserted between Step 2 and Step 3
        'step': 3,
        'course_id': 2025,
        'course_title': 'Detour: Targeted Remedial Drill',
        'tags': ['remediation', 'timed drills'],
        'status': 'LOCKED',
        'reason_why': 'Remedial content to close detected weak sub-skills.',
        'progress_percent': 0,
        'skill_type': 'GRAMMAR_REMEDIAL',
        'total_lessons': 6,
        'completed_lessons': 0,
        'node_type': 'DETOUR_REMEDIAL',
        'parent_node_id': 2,
        'is_optional': false,
        'schedule_status': 'ON_TRACK',
        'estimated_hours': 3,
        'deadline': now.add(const Duration(days: 6)).toIso8601String(),
      },
      {
        'step': 4,
        'course_id': 303,
        'course_title': 'Communication Skills (Applied English)',
        'tags': ['communication', 'speaking'],
        'status': 'LOCKED',
        'reason_why': 'Unlock after grammar practice is stabilized.',
        'progress_percent': 0,
        'skill_type': 'COMMUNICATION',
        'total_lessons': 9,
        'completed_lessons': 0,
        'node_type': 'MERGED',
        'schedule_status': 'ON_TRACK',
        'estimated_hours': 5,
        'deadline': now.add(const Duration(days: 10)).toIso8601String(),
      },
    ];

    // Note: LearningPathway.fromJson currently ignores extra fields.
    // We will extend models in the next step to read them.
    return LearningPathway.fromJson({
      'pathway_id': 1,
      'roadmap_id': 'mock-roadmap',
      'mentor_summary': 'Mock mentor summary for FE-11 agentic UI preview.',
      'nodes': nodes,
      'weak_skills': ['Grammar accuracy', 'Timed practice'],
      'total_steps': nodes.length,
      'completed_steps': 1,
      if (includePendingReroute) ...{
        // UI will ignore unless model is extended.
        'pending_reroute_suggestion': {
          'node_type': 'FAST_TRACK_SKIPPED',
          'reroute_reason': 'Skip Step 2 suggested after excellent Step 1.',
          'can_skip': true,
          'blocked_reason': null,
        },
      },
    });
  }

  /// Mock “pending suggestion” toggling state.
  Future<bool> shouldShowPendingReroute() async {
    final prefs = await SharedPreferences.getInstance();
    final accepted = prefs.getBool(_kMockPendingRerouteAccepted) ?? false;
    return !accepted;
  }

  Future<void> acceptMockSuggestion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMockPendingRerouteAccepted, true);
  }

  Future<void> declineMockSuggestion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMockPendingRerouteAccepted, false);
  }

  /// Mock refresh: after accept, we’ll mark Step 2 as completed/in-progress and keep detour locked.
  LearningPathway buildMockPathwayAfterAccept() {
    return buildMockPathway(includePendingReroute: false);
  }
}
