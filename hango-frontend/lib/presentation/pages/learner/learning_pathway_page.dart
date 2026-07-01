import 'package:flutter/material.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/learning_pathway/interactive_node_tree.dart';
import '../../widgets/learning_pathway/ai_mentor_side_panel.dart';
import '../../../domain/entities/learning_pathway.dart';
import '../../../data/repositories/mock_pathway_repository.dart';

class LearningPathwayPage extends StatefulWidget {
  const LearningPathwayPage({Key? key}) : super(key: key);

  @override
  State<LearningPathwayPage> createState() => _LearningPathwayPageState();
}

class _LearningPathwayPageState extends State<LearningPathwayPage> {
  final MockPathwayRepository _repository = MockPathwayRepository();
  LearningPathway? _pathway;
  PathwayNode? _selectedNode;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPathway();
  }

  Future<void> _loadPathway() async {
    try {
      final pathway = await _repository.getMyPathway();
      setState(() {
        _pathway = pathway;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      // Handle error
    }
  }

  void _handleNodeTap(PathwayNode node) {
    setState(() {
      _selectedNode = node;
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
              : _pathway == null
                  ? const Center(child: Text('Không tải được lộ trình.'))
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
    // Usually a bottom sheet or a tab view is better. 
    // Here we'll just stack the mentor at the bottom as a persistent sheet
    // but for simplicity right now we'll put them in a column (scrollable)
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
          ),
        ),
      ],
    );
  }
}
