import 'package:flutter/material.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/learning_pathway/interactive_node_tree.dart';
import '../../widgets/learning_pathway/ai_mentor_side_panel.dart';
import '../../../domain/entities/learning_pathway.dart';
import '../../../data/repositories/pathway_repository.dart';

class LearningPathwayPage extends StatefulWidget {
  const LearningPathwayPage({super.key});

  @override
  State<LearningPathwayPage> createState() => _LearningPathwayPageState();
}

class _LearningPathwayPageState extends State<LearningPathwayPage> {
  final PathwayRepository _repository = PathwayRepository();
  LearningPathway? _pathway;
  PathwayNode? _selectedNode;
  bool _isLoading = true;
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
      final pathway = await _repository.getMyPathway();
      setState(() {
        _pathway = pathway;
        _selectedNode = pathway.nodes.isNotEmpty ? pathway.nodes.first : null;
      });
    } catch (e) {
      setState(() {
        _pathway = null;
        _errorMessage = e.toString();
        if (e.toString().contains('404')) {
          _errorMessage = 'Hiện chưa có lộ trình học. Vui lòng tạo lộ trình mới hoặc kiểm tra lại trang khóa học.';
        }
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _handleNodeTap(PathwayNode node) {
    setState(() {
      _selectedNode = node;
    });
  }

  void _handlePathwayUpdated(LearningPathway updatedPathway) {
    setState(() {
      _pathway = updatedPathway;
      _selectedNode = updatedPathway.nodes.isNotEmpty ? updatedPathway.nodes.first : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;

        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: SharedHeader(
            isDesktop: isDesktop,
            activeTab: 'Learning Pathway',
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorBody()
                  : _pathway == null
                      ? const Center(child: Text('Không có lộ trình để hiển thị.'))
                      : isDesktop
                          ? _buildDesktopLayout(isDesktop)
                          : _buildMobileLayout(isDesktop),
        );
      },
    );
  }

  Widget _buildDesktopLayout(bool isDesktop) {
    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cột Trái 65% - Node Tree
              Expanded(
                flex: 65,
                child: Container(
                  color: const Color(0xFFF8FAFC),
                  child: InteractiveNodeTree(
                    nodes: _pathway!.nodes,
                    onNodeTap: _handleNodeTap,
                    selectedNode: _selectedNode,
                  ),
                ),
              ),
              
              // Cột Phải 35% - AI Mentor
              Expanded(
                flex: 35,
                child: AIMentorSidePanel(
                  pathway: _pathway!,
                  selectedNode: _selectedNode,
                  onPathwayUpdated: _handlePathwayUpdated,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(bool isDesktop) {
    // For mobile, we can use a Stack or just a basic column.
    return Column(
      children: [
        Expanded(
          child: InteractiveNodeTree(
            nodes: _pathway!.nodes,
            onNodeTap: _handleNodeTap,
            selectedNode: _selectedNode,
          ),
        ),
        SizedBox(
          height: 350,
          child: AIMentorSidePanel(
            pathway: _pathway!,
            selectedNode: _selectedNode,
            onPathwayUpdated: _handlePathwayUpdated,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 56, color: Color(0xFFEF4444)),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'Đã xảy ra lỗi.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Color(0xFF334155)),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadPathway,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Tải lại lộ trình'),
            ),
          ],
        ),
      ),
    );
  }
}

