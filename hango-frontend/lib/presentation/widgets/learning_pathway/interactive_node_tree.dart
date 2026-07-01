import 'package:flutter/material.dart';
import '../../../domain/entities/learning_pathway.dart';

class InteractiveNodeTree extends StatelessWidget {
  final List<PathwayNode> nodes;
  final Function(PathwayNode) onNodeTap;
  final PathwayNode? selectedNode;

  const InteractiveNodeTree({
    Key? key,
    required this.nodes,
    required this.onNodeTap,
    this.selectedNode,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      itemCount: nodes.length,
      itemBuilder: (context, index) {
        final node = nodes[index];
        final isLast = index == nodes.length - 1;
        
        // Zig-zag alignment: Left, Center, Right, Center, Left...
        // For simplicity, alternating left and right slightly
        final alignment = index % 2 == 0 ? Alignment.centerLeft : Alignment.centerRight;
        final paddingHorizontal = index % 2 == 0 ? const EdgeInsets.only(left: 40, right: 80) : const EdgeInsets.only(left: 80, right: 40);

        return _buildNodeItem(context, node, isLast, alignment, paddingHorizontal);
      },
    );
  }

  Widget _buildNodeItem(
    BuildContext context, 
    PathwayNode node, 
    bool isLast, 
    Alignment alignment, 
    EdgeInsets padding
  ) {
    final isSelected = selectedNode?.step == node.step;
    
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Connecting Line
        if (!isLast)
          Positioned(
            top: 60,
            bottom: -60,
            child: Container(
              width: 4,
              color: node.status == NodeStatus.completed 
                  ? const Color(0xFF10B981) // Green
                  : const Color(0xFFE2E8F0), // Gray
            ),
          ),
          
        // Node Content
        Align(
          alignment: alignment,
          child: Padding(
            padding: padding,
            child: GestureDetector(
              onTap: () => onNodeTap(node),
              child: Container(
                margin: const EdgeInsets.only(bottom: 60),
                width: 280,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected 
                        ? const Color(0xFF3B82F6) // Selected Blue
                        : _getBorderColor(node.status),
                    width: isSelected ? 2 : 1.5,
                  ),
                  boxShadow: [
                    if (node.status == NodeStatus.inProgress || isSelected)
                      BoxShadow(
                        color: _getShadowColor(node.status, isSelected),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    if (node.status != NodeStatus.inProgress && !isSelected)
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildStatusBadge(node.status),
                          Text(
                            'Bước ${node.step}',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        node.courseTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: node.status == NodeStatus.locked 
                              ? const Color(0xFF94A3B8) 
                              : const Color(0xFF1E293B),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: node.tags.map((tag) => _buildTag(tag, node.status)).toList(),
                      ),
                      if (node.status == NodeStatus.inProgress) ...[
                        const SizedBox(height: 16),
                        _buildProgressBar(node.progressPercent),
                      ]
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getBorderColor(NodeStatus status) {
    switch (status) {
      case NodeStatus.completed: return const Color(0xFF10B981);
      case NodeStatus.inProgress: return const Color(0xFF3B82F6);
      case NodeStatus.locked: return const Color(0xFFE2E8F0);
    }
  }

  Color _getShadowColor(NodeStatus status, bool isSelected) {
    if (isSelected) return const Color(0xFF3B82F6).withOpacity(0.3);
    if (status == NodeStatus.inProgress) return const Color(0xFF3B82F6).withOpacity(0.2);
    return Colors.transparent;
  }

  Widget _buildStatusBadge(NodeStatus status) {
    switch (status) {
      case NodeStatus.completed:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 14, color: Color(0xFF10B981)),
              SizedBox(width: 4),
              Text('Hoàn thành', style: TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      case NodeStatus.inProgress:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill, size: 14, color: Color(0xFF3B82F6)),
              SizedBox(width: 4),
              Text('Đang học', style: TextStyle(color: Color(0xFF3B82F6), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        );
      case NodeStatus.locked:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock, size: 14, color: Color(0xFF94A3B8)),
              SizedBox(width: 4),
              Text('Chưa mở', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        );
    }
  }

  Widget _buildTag(String tag, NodeStatus status) {
    final isLocked = status == NodeStatus.locked;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isLocked ? const Color(0xFFF8FAFC) : const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tag,
        style: TextStyle(
          color: isLocked ? const Color(0xFF94A3B8) : const Color(0xFF4F46E5),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildProgressBar(int percent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          '$percent%',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF3B82F6),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 6,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFE0E7FF),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: percent / 100,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
