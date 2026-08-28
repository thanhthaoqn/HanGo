import 'package:flutter/material.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/learning_pathway/interactive_node_tree.dart';
import '../../widgets/learning_pathway/ai_mentor_side_panel.dart';
import '../../widgets/learning_pathway/pathway_summary_header.dart';
import '../../widgets/learning_pathway/skill_analysis_panel.dart';
import '../../widgets/learning_pathway/edit_goal_dialog.dart';
import '../../widgets/learning_pathway/daily_plan_card.dart';
import '../../../domain/entities/learning_pathway.dart';
import '../../../data/repositories/pathway_repository.dart';
import '../../../utils/language_manager.dart';
import '../course/course_detail_page.dart';
import 'mastery_quiz_page.dart';

class LearningPathwayPage extends StatefulWidget {
  final bool isEmbedded;
  const LearningPathwayPage({super.key, this.isEmbedded = false});

  @override
  State<LearningPathwayPage> createState() => _LearningPathwayPageState();
}

class _LearningPathwayPageState extends State<LearningPathwayPage> {
  final PathwayRepository _repository = PathwayRepository();
  LearningPathway? _pathway;
  PathwayNode? _selectedNode;
  bool _isLoading = true;
  bool _isDarkMode = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadPathway();
  }

  Future<void> _loadPathway() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // GET /pathways/me - backend tra pathway ACTIVE duy nhat cua user
      final pathway = _preparePathwayForDisplay(await _repository.getMyPathway());
      if (!mounted) return;
      setState(() {
        _pathway = pathway;
        _selectedNode = _initialSelectedNode(pathway.nodes);
      });
      // C3 (spec 20): tu dong lay pending reroute suggestion sau moi lan load
      // (thay cho viec persist suggestion vao database)
      _refreshRerouteSuggestion();
    } catch (e) {
      if (!mounted) return;
      // 404 = user chua co pathway nao (chua lam exam) -> hien man hinh empty state
      setState(() {
        _pathway = null;
        _errorMessage = e.toString().contains('404')
            ? 'No active pathway yet. Finish an exam to let AI build a route for you.'
            : e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showEditGoalDialog() {
    final pathway = _pathway;
    if (pathway == null) return;

    showDialog<void>(
      context: context,
      builder: (context) => EditGoalDialog(
        pathway: pathway,
        isDarkMode: _isDarkMode,
        repository: _repository,
        onUpdated: (updatedPathway) {
          if (!mounted) return;
          setState(() {
            _pathway = updatedPathway;
            _selectedNode = updatedPathway.nodes.firstWhere(
              (n) => n.status == NodeStatus.inProgress,
              orElse: () => updatedPathway.nodes.first,
            );
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(LanguageManager.isVi
                  ? 'Đã cập nhật mục tiêu và lộ trình học!'
                  : 'Pathway goals updated successfully!'),
              backgroundColor: const Color(0xFF10B981),
            ),
          );
        },
      ),
    );
  }

  void _handleNodeTap(PathwayNode node) {
    setState(() => _selectedNode = node);
  }

  void _handlePathwayUpdated(LearningPathway updatedPathway) {
    final displayPathway = _preparePathwayForDisplay(updatedPathway);
    setState(() {
      _pathway = displayPathway;
      _selectedNode = _initialSelectedNode(displayPathway.nodes);
    });
  }

  LearningPathway _preparePathwayForDisplay(LearningPathway pathway) {
    var allPreviousCompleted = true;
    final displayNodes = <PathwayNode>[];

    for (final node in pathway.nodes) {
      var displayNode = node;
      if (node.status == NodeStatus.locked && allPreviousCompleted) {
        displayNode = node.copyWith(
          status: NodeStatus.inProgress,
          reasonWhy: node.reasonWhy.isEmpty
              ? 'Unlocked because you completed the previous course.'
              : node.reasonWhy,
        );
      }

      displayNodes.add(displayNode);
      allPreviousCompleted = allPreviousCompleted &&
          displayNode.status == NodeStatus.completed;
    }

    return pathway.copyWith(nodes: displayNodes);
  }

  PathwayNode? _initialSelectedNode(List<PathwayNode> nodes) {
    if (nodes.isEmpty) return null;
    return nodes.firstWhere(
      (node) => node.status == NodeStatus.inProgress,
      orElse: () => nodes.first,
    );
  }

  /// C3 (spec 20): goi lai policy suggestions sau khi load pathway de card
  /// "Pathway update suggestion" luon hien dung du khi user refresh trang.
  Future<void> _refreshRerouteSuggestion() async {
    final current = _pathway;
    if (current == null) return;
    try {
      final updated = await _repository.suggestReroute(pathwayId: current.pathwayId);
      if (!mounted || _pathway == null || _pathway!.pathwayId != updated.pathwayId) return;
      setState(() {
        // Giu node dang chon, chi cap nhat suggestion moi
        _pathway = _preparePathwayForDisplay(updated);
      });
    } catch (_) {
      // Khong co suggestion / loi mang: bo qua im lang
    }
  }

  /// B4 (spec 20): mo man hinh Mastery Quiz that thay cho mock score 90/100.
  Future<void> _openMasteryQuiz(PathwayNode node) async {
    if (_pathway == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MasteryQuizPage(
          pathwayId: _pathway!.pathwayId,
          node: node,
          isDarkMode: _isDarkMode,
          onCompleted: (updatedPathway) {
            if (!mounted) return;
            setState(() {
              _pathway = _preparePathwayForDisplay(updatedPathway);
            });
          },
        ),
      ),
    );
    // E1 (spec 20): refresh tien do sau khi quay ve tu man hinh quiz
    if (mounted) _loadPathway();
  }

  /// E1 (spec 20): mo khoa hoc va refresh pathway khi quay ve de tien do/status khong bi stale.
  Future<void> _openCourseAndRefresh(PathwayNode node) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CourseDetailPage(courseId: node.courseId),
      ),
    );
    if (mounted) _loadPathway();
  }


  void _showSkillAnalysis() {
    final pathway = _pathway;
    if (pathway == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SkillAnalysisPanel(
          weakSkills: pathway.weakSkills,
          latestWeakSkills: pathway.latestWeakSkills,
          attemptsUsed: pathway.analyzedAttempts,
          isDarkMode: _isDarkMode,
        ),
      ),
    );
  }

  Future<void> _handleFastTrack(PathwayNode node) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Fast-track Course'),
        content: const Text('To fast-track this course, you must take the Mastery Quiz to prove your knowledge. Are you ready?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
            ),
            child: const Text('Take Mastery Quiz'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    // Redirect to Mastery Quiz instead of skipping via backend API
    await _openMasteryQuiz(node);
  }

  Future<void> _showRegenerateFreeWarningDialog() async {
    final pathway = _pathway;
    if (pathway == null || pathway.examAttemptId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot regenerate: Missing Exam Attempt ID.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Limitation Warning ⚠️'),
        content: const Text(
          'A learning pathway containing only free courses might not cover all the advanced knowledge needed to reach your goal.\n\n'
          'You can still start with this free pathway and purchase premium courses later to fill any gaps. Do you want to continue generating a free-only pathway?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
            ),
            child: const Text('Continue (Free Only)'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final newPathway = await _repository.generatePathway(
        examAttemptId: pathway.examAttemptId!,
        goalName: pathway.goalName,
        targetDate: pathway.targetDate,
        hoursPerWeek: pathway.hoursPerWeek,
        onlyFree: true,
      );
      if (!mounted) return;
      setState(() {
        _pathway = _preparePathwayForDisplay(newPathway);
        _selectedNode = _initialSelectedNode(newPathway.nodes);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã tạo lộ trình mới chỉ với các khóa học miễn phí!'),
          backgroundColor: Color(0xFF28B79B),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 960;
        final bg = _isDarkMode ? const Color(0xFF0D1117) : const Color(0xFFF8FAFC);

        return Scaffold(
          backgroundColor: bg,
          appBar: widget.isEmbedded ? null : SharedHeader(isDesktop: isDesktop, activeTab: 'Learning Pathway'),
          endDrawer: isDesktop ? null : Drawer(
            width: constraints.maxWidth * 0.85,
            child: _pathway != null ? AIMentorSidePanel(
              pathway: _pathway!,
              selectedNode: _selectedNode,
              onPathwayUpdated: _handlePathwayUpdated,
              onRegenerateFree: _showRegenerateFreeWarningDialog,
              isDarkMode: _isDarkMode,
            ) : const SizedBox(),
          ),
          floatingActionButton: isDesktop || _pathway == null ? null : Builder(
            builder: (ctx) => FloatingActionButton.extended(
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('AI Mentor'),
              backgroundColor: const Color(0xFF6366F1),
              foregroundColor: Colors.white,
            ),
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isDarkMode
                    ? const [Color(0xFF0D1117), Color(0xFF0F172A)]
                    : const [Color(0xFFF8FAFC), Color(0xFFEEF2FF)], // Playful indigo hint
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: _isLoading
                ? _buildLoading()
                : _errorMessage != null
                    ? _buildErrorBody()
                    : _pathway == null
                        ? _buildErrorBody()
                        : isDesktop
                            ? _buildDesktopLayout()
                            : _buildMobileLayout(),
          ),
        );
      },
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        PathwaySummaryHeader(
          pathway: _pathway!,
          isDarkMode: _isDarkMode,
          onAnalysisPressed: _showSkillAnalysis,
          onEditGoalPressed: _showEditGoalDialog,
          onRegenerateFreePressed: _showRegenerateFreeWarningDialog,
        ),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: InteractiveNodeTree(
                  nodes: _pathway!.nodes,
                  onNodeTap: _handleNodeTap,
                  onFastTrackTap: _handleFastTrack,
                  onMasteryTap: _openMasteryQuiz,
                  selectedNode: _selectedNode,
                  isDarkMode: _isDarkMode,
                  contentPadding: const EdgeInsets.only(right: 480), // Padding to not hide nodes under mentor
                  header: DailyPlanCard(
                    pathway: _pathway!,
                    isDarkMode: _isDarkMode,
                    onStartLearning: (node) {
                      _openCourseAndRefresh(node);
                    },
                    onTakeMastery: _openMasteryQuiz,
                    onReview: _openMasteryQuiz,
                  ),
                ),
              ),
              Positioned(
                top: 24,
                right: 24,
                bottom: 24,
                width: 440,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: AIMentorSidePanel(
                    pathway: _pathway!,
                    selectedNode: _selectedNode,
                    onPathwayUpdated: _handlePathwayUpdated,
                    onRegenerateFree: _showRegenerateFreeWarningDialog,
                    isDarkMode: _isDarkMode,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        PathwaySummaryHeader(
          pathway: _pathway!,
          isDarkMode: _isDarkMode,
          onAnalysisPressed: _showSkillAnalysis,
          onEditGoalPressed: _showEditGoalDialog,
          onRegenerateFreePressed: _showRegenerateFreeWarningDialog,
        ),
        Expanded(
          child: InteractiveNodeTree(
            nodes: _pathway!.nodes,
            onNodeTap: _handleNodeTap,
            onFastTrackTap: _handleFastTrack,
            onMasteryTap: _openMasteryQuiz,
            selectedNode: _selectedNode,
            isDarkMode: _isDarkMode,
            contentPadding: const EdgeInsets.only(bottom: 100),
            header: DailyPlanCard(
              pathway: _pathway!,
              isDarkMode: _isDarkMode,
              onStartLearning: (node) {
                _openCourseAndRefresh(node);
              },
              onTakeMastery: _openMasteryQuiz,
              onReview: _openMasteryQuiz,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return Center(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.88, end: 1),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeInOut,
        builder: (context, value, child) => Transform.scale(scale: value, child: child),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF28B79B)),
            SizedBox(height: 18),
            Text('Preparing your pathway...', style: TextStyle(color: Color(0xFF8B949E), fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorBody() {
    final dark = _isDarkMode;
    final titleColor = dark ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A);
    final textColor = dark ? const Color(0xFF8B949E) : const Color(0xFF64748B);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF161B22) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: dark ? const Color(0xFF30363D) : const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(dark ? 0.28 : 0.06),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF28B79B).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.route_rounded, size: 42, color: Color(0xFF28B79B)),
              ),
              const SizedBox(height: 18),
              Text(
                'No pathway to show yet',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: titleColor),
              ),
              const SizedBox(height: 10),
              Text(
                _errorMessage ?? 'Finish an exam first, then HanGo can build a personalized learning route.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, height: 1.5, color: textColor),
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: _loadPathway,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Reload pathway'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28B79B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
