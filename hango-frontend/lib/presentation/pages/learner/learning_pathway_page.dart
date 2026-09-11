import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
          if (_selectedNode != null) {
            try {
              _selectedNode = pathway.nodes.firstWhere((n) => n.step == _selectedNode!.step);
            } catch (_) {
              _selectedNode = _initialSelectedNode(pathway.nodes);
            }
          } else {
            _selectedNode = _initialSelectedNode(pathway.nodes);
          }
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
    if (node.courseId <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Course information is not available.'),
          ),
        );
      }
      return;
    }
    try {
      await context.push('/courses/${node.courseId}');
    } catch (e) {
      debugPrint('[Pathway] context.push error: $e, falling back to Navigator');
      if (mounted) {
        await Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (_) => CourseDetailPage(courseId: node.courseId),
          ),
        );
      }
    }
    if (mounted) _loadPathway();
  }


  void _showSkillAnalysis() {
    final pathway = _pathway;
    if (pathway == null) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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

  Widget _buildConfirmationDialog({
    required BuildContext ctx,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String content,
    required String confirmText,
    required Color confirmButtonColor,
    String? cancelText,
  }) {
    final bg = _isDarkMode ? const Color(0xFF161B22) : Colors.white;
    final cardBorder = _isDarkMode ? const Color(0xFF30363D) : const Color(0xFFE2E8F0);
    final titleColor = _isDarkMode ? const Color(0xFFF0F6FC) : const Color(0xFF0F172A);
    final subColor = _isDarkMode ? const Color(0xFF8B949E) : const Color(0xFF64748B);

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cardBorder),
      ),
      backgroundColor: bg,
      elevation: 10,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: titleColor,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 12),
            Text(
              content,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: subColor,
                fontSize: 14,
                height: 1.5,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: BorderSide(
                        color: _isDarkMode ? const Color(0xFF30363D) : Colors.grey.shade300,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      cancelText ?? (LanguageManager.isVi ? 'Hủy' : 'Cancel'),
                      style: TextStyle(
                        color: subColor,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmButtonColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      confirmText,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleFastTrack(PathwayNode node) async {
    final isVi = LanguageManager.isVi;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmationDialog(
        ctx: ctx,
        icon: Icons.bolt_rounded,
        iconColor: const Color(0xFFF59E0B),
        iconBgColor: _isDarkMode ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7),
        title: isVi ? 'Học nhanh khóa học' : 'Fast-track Course',
        content: isVi
            ? 'Để học nhanh khóa học này, bạn cần làm bài kiểm tra Mastery Quiz để chứng minh năng lực. Bạn đã sẵn sàng?'
            : 'To fast-track this course, you must take the Mastery Quiz to prove your knowledge. Are you ready?',
        confirmText: isVi ? 'Làm bài kiểm tra' : 'Take Mastery Quiz',
        confirmButtonColor: const Color(0xFFF59E0B),
      ),
    );
    
    if (confirm != true) return;
    
    _openMasteryQuiz(node);
  }

  Future<void> _handleSkipNode(PathwayNode node) async {
    final isVi = LanguageManager.isVi;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmationDialog(
        ctx: ctx,
        icon: Icons.skip_next_rounded,
        iconColor: const Color(0xFF64748B),
        iconBgColor: _isDarkMode ? const Color(0xFF334155).withValues(alpha: 0.3) : const Color(0xFFF1F5F9),
        title: isVi ? 'Bỏ qua khóa học?' : 'Skip Course?',
        content: isVi
            ? 'Nếu bạn bỏ qua khóa học này, bạn sẽ không nhận được điểm Mastery cho khóa học, và khóa học tiếp theo sẽ được mở khóa. Bạn có chắc chắn muốn tiếp tục?'
            : 'If you skip this course, you will not receive a Mastery Score for it, and the next course will be unlocked. Are you sure you want to proceed?',
        confirmText: isVi ? 'Bỏ qua khóa học' : 'Skip Course',
        confirmButtonColor: const Color(0xFF64748B),
      ),
    );
    
    if (confirm != true || _pathway == null) return;
    
    try {
      final updated = await _repository.skipPathwayNode(
        pathwayId: _pathway!.pathwayId,
        nodeId: node.id,
      );
      if (!mounted) return;
      setState(() {
        _pathway = _preparePathwayForDisplay(updated);
        // chon luon node hien tai moi de UI update phan ben trai
        _selectedNode = updated.nodes.firstWhere((n) => n.id == node.id, orElse: () => updated.nodes.first);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Course skipped successfully.'), backgroundColor: Colors.green),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
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

    final isVi = LanguageManager.isVi;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => _buildConfirmationDialog(
        ctx: ctx,
        icon: Icons.warning_amber_rounded,
        iconColor: const Color(0xFFF59E0B),
        iconBgColor: _isDarkMode ? const Color(0xFF78350F).withValues(alpha: 0.3) : const Color(0xFFFEF3C7),
        title: isVi ? 'Cảnh báo giới hạn ⚠️' : 'Limitation Warning ⚠️',
        content: isVi
            ? 'Lộ trình học chỉ gồm các khóa miễn phí có thể không bao quát hết các kiến thức nâng cao cần thiết để đạt mục tiêu của bạn.\n\nBạn vẫn có thể bắt đầu với lộ trình miễn phí này và mua thêm các khóa trả phí sau. Bạn có muốn tiếp tục tạo lộ trình miễn phí không?'
            : 'A learning pathway containing only free courses might not cover all the advanced knowledge needed to reach your goal.\n\nYou can still start with this free pathway and purchase premium courses later to fill any gaps. Do you want to continue generating a free-only pathway?',
        confirmText: isVi ? 'Tiếp tục (Miễn phí)' : 'Continue (Free Only)',
        confirmButtonColor: const Color(0xFFF59E0B),
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
              onOpenCourse: _openCourseAndRefresh,
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
                  onStartLearningTap: _openCourseAndRefresh,
                  onFastTrackTap: _handleFastTrack,
                  onMasteryTap: _openMasteryQuiz,
                  onSkipTap: _handleSkipNode,
                  onRegenerateFreeTap: _showRegenerateFreeWarningDialog,
                  selectedNode: _selectedNode,
                  isDarkMode: _isDarkMode,
                  suggestedActions: _pathway!.suggestedActions,
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
                    onOpenCourse: _openCourseAndRefresh,
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
            onStartLearningTap: _openCourseAndRefresh,
            onFastTrackTap: _handleFastTrack,
            onMasteryTap: _openMasteryQuiz,
            onSkipTap: _handleSkipNode,
            onRegenerateFreeTap: _showRegenerateFreeWarningDialog,
            selectedNode: _selectedNode,
            isDarkMode: _isDarkMode,
            suggestedActions: _pathway!.suggestedActions,
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
