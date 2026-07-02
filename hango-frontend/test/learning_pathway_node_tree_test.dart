import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hango/domain/entities/learning_pathway.dart';
import 'package:hango/presentation/widgets/learning_pathway/interactive_node_tree.dart';

void main() {
  test('PathwayNode.fromJson accepts backend status variants', () {
    expect(
      PathwayNode.fromJson({
        'step': 1,
        'course_id': 1,
        'course_title': 'Grammar Basics',
        'status': 'IN_PROGRESS',
      }).status,
      NodeStatus.inProgress,
    );
    expect(
      PathwayNode.fromJson({
        'step': 2,
        'courseId': 2,
        'courseTitle': 'Reading Practice',
        'status': 'Completed',
      }).status,
      NodeStatus.completed,
    );
  });

  testWidgets('InteractiveNodeTree transitions node states without pending frame callbacks', (tester) async {
    PathwayNode? tappedNode;
    final initialNodes = [
      node(step: 1, courseId: 10, title: 'Grammar Basics', status: NodeStatus.locked),
      node(step: 2, courseId: 20, title: 'Reading Upgrade', status: NodeStatus.inProgress, progress: 40),
      node(step: 3, courseId: 30, title: 'Final Review', status: NodeStatus.completed),
    ];

    await tester.pumpWidget(treeHarness(
      nodes: initialNodes,
      onNodeTap: (node) => tappedNode = node,
    ));

    expect(find.byIcon(Icons.lock), findsOneWidget);
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    expect(find.byIcon(Icons.check_circle), findsOneWidget);
    expect(find.text('40%'), findsOneWidget);

    await tester.tap(find.text('Reading Upgrade'));
    expect(tappedNode?.courseId, 20);

    final transitionedNodes = [
      node(step: 1, courseId: 10, title: 'Grammar Basics', status: NodeStatus.completed),
      node(step: 2, courseId: 20, title: 'Reading Upgrade', status: NodeStatus.inProgress, progress: 75),
      node(step: 3, courseId: 30, title: 'Final Review', status: NodeStatus.completed),
    ];

    await tester.pumpWidget(treeHarness(
      nodes: transitionedNodes,
      selectedNode: transitionedNodes[1],
      onNodeTap: (node) => tappedNode = node,
    ));
    await tester.pump(const Duration(milliseconds: 16));

    expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
    expect(find.byIcon(Icons.play_circle_fill), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(tester.binding.transientCallbackCount, 0);
  });
}

Widget treeHarness({
  required List<PathwayNode> nodes,
  required ValueChanged<PathwayNode> onNodeTap,
  PathwayNode? selectedNode,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 900,
        height: 760,
        child: InteractiveNodeTree(
          nodes: nodes,
          selectedNode: selectedNode,
          onNodeTap: onNodeTap,
        ),
      ),
    ),
  );
}

PathwayNode node({
  required int step,
  required int courseId,
  required String title,
  required NodeStatus status,
  int progress = 0,
}) {
  return PathwayNode(
    step: step,
    courseId: courseId,
    courseTitle: title,
    tags: const ['#Grammar'],
    status: status,
    reasonWhy: 'Recommended from your exam result.',
    progressPercent: progress,
  );
}
