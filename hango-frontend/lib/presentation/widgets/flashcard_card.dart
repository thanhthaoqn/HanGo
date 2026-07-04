import 'package:flutter/material.dart';
import '../../domain/entities/flashcard.dart';

class FlashcardCard extends StatefulWidget {
  final FlashcardCollection collection;
  final VoidCallback onTap;
  const FlashcardCard({Key? key, required this.collection, required this.onTap}) : super(key: key);

  @override
  State<FlashcardCard> createState() => _FlashcardCardState();
}

class _FlashcardCardState extends State<FlashcardCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, isHovered ? -8 : 0, 0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: isHovered
                    ? Colors.black.withOpacity(0.12)
                    : Colors.black.withOpacity(0.05),
                blurRadius: isHovered ? 20 : 10,
                offset: Offset(0, isHovered ? 10 : 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Half - Gradient Header with Hat/School Icon
              Container(
                height: 100,
                decoration: const BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  gradient: LinearGradient(
                    colors: [Color(0xFF28B79B), Color(0xFF209D84)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Badge: FLASHCARD
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'FLASHCARD',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),

                    // Title
                    Padding(
                      padding: const EdgeInsets.only(left: 12.0, right: 12.0, top: 28.0, bottom: 12.0),
                      child: Text(
                        widget.collection.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          height: 1.3,
                        ),
                      ),
                    ),

                    // school watermark
                    Positioned(
                      bottom: -10,
                      right: -10,
                      child: Icon(
                        Icons.school_rounded,
                        size: 68,
                        color: Colors.white.withOpacity(0.15),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Half - Details & Stats
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Description
                      Text(
                        widget.collection.description.isNotEmpty
                            ? widget.collection.description
                            : 'No description provided.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      
                      // Creator Info
                      Text(
                        'Created By: ${widget.collection.creator}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const Spacer(),

                      // Sentences & Duration details row
                      Row(
                        children: [
                          const Icon(Icons.menu_book_outlined, size: 13, color: Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.collection.flashcards.length} sentences',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          ),
                          const Spacer(),
                          const Icon(Icons.timer_outlined, size: 13, color: Color(0xFF6B7280)),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.collection.durationMinutes} minute',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
