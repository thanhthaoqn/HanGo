import 'package:flutter/material.dart';
import '../../../domain/model/course_review_summary.dart';

class ReviewTab extends StatelessWidget {
  final CourseReviewSummary summary;

  const ReviewTab({Key? key, required this.summary}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Learner Reviews',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 24),
          _buildSummaryCard(),
          const SizedBox(height: 32),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: summary.reviews.length,
            separatorBuilder: (context, index) => const Divider(height: 48, color: Color(0xFFE2E8F0)),
            itemBuilder: (context, index) {
              final review = summary.reviews[index];
              return _buildReviewItem(review);
            },
          ),
          if (summary.reviews.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 32.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    // Logic for see more
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'See more',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF29B69A), // Primary color matching mockup
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left side: Rating number
          Expanded(
            flex: 2,
            child: Column(
              children: [
                Text(
                  summary.averageRating.toStringAsFixed(1),
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF29B69A),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    return Icon(
                      index < summary.averageRating.round() ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFACC15),
                      size: 20,
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  '${summary.totalRatings} total ratings',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),
          // Right side: Bars
          Expanded(
            flex: 3,
            child: Column(
              children: List.generate(5, (index) {
                int starRating = 5 - index;
                int count = summary.ratingCounts[starRating.toString()] ?? 0;
                double percentage = summary.totalRatings == 0 ? 0 : (count / summary.totalRatings);
                
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      Text(
                        '$starRating star',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: percentage,
                            backgroundColor: const Color(0xFFF1F5F9),
                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF29B69A)),
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${(percentage * 100).round()}%',
                          textAlign: TextAlign.right,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(CourseReview review) {
    // Format date roughly. Mockup: "28 Dec 2023"
    // If we have ISO string, parse it, otherwise generic.
    String displayDate = '';
    if (review.createdAt != null) {
      try {
        DateTime dt = DateTime.parse(review.createdAt!);
        const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        displayDate = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      } catch (e) {
        displayDate = review.createdAt!;
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFF9FA8DA),
          foregroundColor: Colors.white,
          child: Text(review.userInitial),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    review.userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    displayDate,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: List.generate(5, (index) {
                  return Icon(
                    index < review.rating ? Icons.star : Icons.star_border,
                    color: const Color(0xFFFACC15),
                    size: 16,
                  );
                }),
              ),
              const SizedBox(height: 12),
              Text(
                review.content,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF334155),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
