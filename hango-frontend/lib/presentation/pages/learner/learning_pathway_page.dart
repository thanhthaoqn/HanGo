import 'package:flutter/material.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/learning_pathway/interactive_node_tree.dart';
import '../../widgets/learning_pathway/ai_mentor_side_panel.dart';
import '../../widgets/learning_pathway/pathway_summary_header.dart';
import '../../widgets/learning_pathway/skill_analysis_panel.dart';
import '../../widgets/learning_pathway/merge_preview_dialog.dart';
import '../../../domain/entities/learning_pathway.dart';
import '../../../data/repositories/pathway_repository.dart';

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
  bool _isDarkMode = true;
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
      final pathway = _preparePathwayForDisplay(await _repository.getMyPathway());
      if (!mounted) return;
      setState(() {
        _pathway = pathway;
        _selectedNode = _initialSelectedNode(pathway.nodes);
      });
    } catch (e) {
      if (!mounted) return;
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
          attemptsUsed: 10,
          isDarkMode: _isDarkMode,
        ),
      ),
    );
  }

  Future<void> _handleMergeGoals() async {
    final pathway = _pathway;
    if (pathway == null) return;

    final uncompletedCourseIds = pathway.nodes
        .where((n) => n.status != NodeStatus.completed)
        .map((n) => n.courseId)
        .toList();

    if (uncompletedCourseIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No active steps available to merge.')),
      );
      return;
    }

    try {
      final preview = await _repository.mergePreview(uncompletedCourseIds);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => MergePreviewDialog(preview: preview),
      );

      if (confirmed == true && mounted) {
        final updatedPathway = await _repository.mergeConfirm(pathway.pathwayId, preview);
        setState(() {
          _pathway = updatedPathway;
          _selectedNode = updatedPathway.nodes.isNotEmpty ? updatedPathway.nodes.first : null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Goals merged successfully!')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not generate merge preview: $e')),
      );
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
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _isDarkMode
                    ? const [Color(0xFF0D1117), Color(0xFF0F172A)]
                    : const [Color(0xFFF8FAFC), Color(0xFFEFFDF8)],
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
          onMergePressed: _handleMergeGoals,
          onThemeToggle: () => setState(() => _isDarkMode = !_isDarkMode),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 64,
                child: InteractiveNodeTree(
                  nodes: _pathway!.nodes,
                  onNodeTap: _handleNodeTap,
                  selectedNode: _selectedNode,
                  isDarkMode: _isDarkMode,
                ),
              ),
              Expanded(
                flex: 36,
                child: AIMentorSidePanel(
                  pathway: _pathway!,
                  selectedNode: _selectedNode,
                  onPathwayUpdated: _handlePathwayUpdated,
                  isDarkMode: _isDarkMode,
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
          onMergePressed: _handleMergeGoals,
          onThemeToggle: () => setState(() => _isDarkMode = !_isDarkMode),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 600,
                  child: InteractiveNodeTree(
                    nodes: _pathway!.nodes,
                    onNodeTap: _handleNodeTap,
                    selectedNode: _selectedNode,
                    isDarkMode: _isDarkMode,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 460,
                  child: AIMentorSidePanel(
                    pathway: _pathway!,
                    selectedNode: _selectedNode,
                    onPathwayUpdated: _handlePathwayUpdated,
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
