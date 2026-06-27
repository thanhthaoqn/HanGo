import 'package:flutter/material.dart';
import '../../../domain/model/course_review_summary.dart';
import '../../../utils/string_utils.dart';

class ReviewTab extends StatefulWidget {
  final CourseReviewSummary summary;
  final bool showWriteReviewButton;
  final VoidCallback? onWriteReview;
  final int currentUserId;
  final VoidCallback? onDeleteReview;
  final Function(double rating, String content)? onEditReview;
  final bool isEnrolled;

  const ReviewTab({
    super.key,
    required this.summary,
    this.showWriteReviewButton = false,
    this.onWriteReview,
    required this.currentUserId,
    this.onDeleteReview,
    this.onEditReview,
    this.isEnrolled = false,
  });

  @override
  State<ReviewTab> createState() => _ReviewTabState();
}

class _ReviewTabState extends State<ReviewTab> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final filteredReviews = widget.isEnrolled
        ? widget.summary.reviews
        : widget.summary.reviews.where((r) => r.userId != widget.currentUserId).toList();

    final displayedReviews = _isExpanded
        ? filteredReviews
        : filteredReviews.take(5).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Learner Reviews',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              if (widget.showWriteReviewButton)
                ElevatedButton.icon(
                  onPressed: widget.onWriteReview,
                  icon: const Icon(Icons.rate_review_outlined, size: 16, color: Colors.white),
                  label: const Text(
                    'Write a Review',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF29B69A),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSummaryCard(),
          const SizedBox(height: 32),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedReviews.length,
            separatorBuilder: (context, index) => const Divider(height: 48, color: Color(0xFFE2E8F0)),
            itemBuilder: (context, index) {
              final review = displayedReviews[index];
              return _buildReviewItem(review);
            },
          ),
          if (filteredReviews.length > 5)
            Padding(
              padding: const EdgeInsets.only(top: 32.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    _isExpanded ? 'Show less' : 'See more',
                    style: const TextStyle(
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
                  widget.summary.averageRating.toStringAsFixed(1),
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
                      index < widget.summary.averageRating.round() ? Icons.star : Icons.star_border,
                      color: const Color(0xFFFACC15),
                      size: 20,
                    );
                  }),
                ),
                const SizedBox(height: 8),
                Text(
                  '${widget.summary.totalRatings} total ratings',
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
                int count = widget.summary.ratingCounts[starRating.toString()] ?? 0;
                double percentage = widget.summary.totalRatings == 0 ? 0 : (count / widget.summary.totalRatings);
                
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
          child: review.userAvatar != null && review.userAvatar!.isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    review.userAvatar!,
                    width: 40,
                    height: 40,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Text(
                      getInitial(formatDisplayName(review.userName)),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                )
              : Text(getInitial(formatDisplayName(review.userName))),
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
                    formatDisplayName(review.userName),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        displayDate,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      if (review.userId == widget.currentUserId) ...[
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFF1F5F9), width: 1),
                          ),
                          color: Colors.white,
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.08),
                          onSelected: (value) {
                            if (value == 'edit') {
                              widget.onEditReview?.call(review.rating.toDouble(), review.content);
                            } else if (value == 'delete') {
                              widget.onDeleteReview?.call();
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'edit',
                              height: 38,
                              child: Row(
                                children: [
                                  Icon(Icons.edit_outlined, size: 16, color: Color(0xFF2563EB)),
                                  SizedBox(width: 10),
                                  Text('Edit', style: TextStyle(fontSize: 13, color: Color(0xFF334155))),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              height: 38,
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline, size: 16, color: Color(0xFFEF4444)),
                                  SizedBox(width: 10),
                                  Text('Delete', style: TextStyle(fontSize: 13, color: Color(0xFFEF4444))),
                                ],
                              ),
                            ),
                          ],
                          icon: const Icon(
                            Icons.more_horiz,
                            size: 18,
                            color: Color(0xFF94A3B8),
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
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
