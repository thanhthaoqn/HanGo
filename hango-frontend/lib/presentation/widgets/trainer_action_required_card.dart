import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class TrainerActionRequiredCard extends StatelessWidget {
  final String? courseStatus;
  final String? rejectionReason;
  final VoidCallback? onSubmit;

  const TrainerActionRequiredCard({
    super.key,
    this.courseStatus,
    this.rejectionReason,
    this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    if (courseStatus != 'DRAFT' && courseStatus != 'REJECTED') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: courseStatus == 'REJECTED'
            ? const Color(0xFFFEF2F2) // Light red for rejected
            : const Color(0xFFF1F5F9), // light grey/blue slate 100
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: courseStatus == 'REJECTED'
              ? const Color(0xFFFCA5A5)
              : const Color(0xFFEFF2F5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            courseStatus == 'REJECTED' ? 'Action Required' : 'Progress Overview',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: courseStatus == 'REJECTED'
                  ? const Color(0xFF991B1B)
                  : const Color(0xFF1E293B),
              fontFamily: 'Outfit',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            courseStatus == 'REJECTED'
                ? 'This course was rejected. Fix the issues below and re-submit.'
                : '1/3 steps completed successfully. Complete the remaining steps to publish the course.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF64748B),
              fontFamily: 'Outfit',
              height: 1.4,
            ),
          ),
          if (courseStatus == 'REJECTED' &&
              rejectionReason != null &&
              rejectionReason!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: MarkdownBody(
                data: rejectionReason!,
                styleSheet: MarkdownStyleSheet(
                  p: const TextStyle(
                      color: Color(0xFF991B1B),
                      fontSize: 11,
                      fontFamily: 'Outfit',
                      height: 1.4),
                  listBullet: const TextStyle(
                      color: Color(0xFF991B1B), fontSize: 11),
                  strong: const TextStyle(
                      color: Color(0xFF7F1D1D),
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Outfit',
                      fontSize: 11),
                ),
              ),
            ),
          ],
          if (onSubmit != null) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onSubmit,
              icon: Icon(
                courseStatus == 'REJECTED' ? Icons.refresh : Icons.play_arrow,
                size: 16,
              ),
              label: Text(
                courseStatus == 'REJECTED'
                    ? 'Re-submit for Review'
                    : 'Submit for Review',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  fontFamily: 'Outfit',
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: courseStatus == 'REJECTED'
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF20B486),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              courseStatus == 'REJECTED'
                  ? 'Save your fixes first, then re-submit'
                  : 'Submit once 100% completed',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
