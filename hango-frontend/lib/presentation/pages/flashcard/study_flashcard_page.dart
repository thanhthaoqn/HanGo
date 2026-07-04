import 'dart:math';
import 'package:flutter/material.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../../../domain/entities/flashcard.dart';
import '../../widgets/shared_header.dart';
import '../../../utils/toast_helper.dart';

class StudyFlashcardPage extends StatefulWidget {
  final String collectionId;
  const StudyFlashcardPage({Key? key, required this.collectionId}) : super(key: key);

  @override
  State<StudyFlashcardPage> createState() => _StudyFlashcardPageState();
}

class _StudyFlashcardPageState extends State<StudyFlashcardPage> with TickerProviderStateMixin {
  final FlashcardRepository _repository = FlashcardRepository();
  FlashcardCollection? _collection;
  bool _isLoading = true;

  // Study logic state
  int _currentIndex = 0;
  List<Flashcard> _studyCards = [];
  final List<bool> _rememberedResults = [];
  bool _isFinished = false;

  // Animation controllers for Flip
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  bool _isFront = true;

  // Animation controller for Swipe/Slide transition
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  Offset _slideTarget = Offset.zero;

  @override
  void initState() {
    super.initState();
    _loadCollection();

    // Flip Animation setup
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _flipAnimation = Tween<double>(begin: 0.0, end: pi).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOut),
    );

    // Slide/Swipe Animation setup
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _slideController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _goToNextCard();
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _loadCollection() async {
    setState(() {
      _isLoading = true;
    });

    final all = await _repository.fetchCollections();
    final col = all.firstWhere((c) => c.id == widget.collectionId);

    setState(() {
      _collection = col;
      _studyCards = List.from(col.flashcards);
      _rememberedResults.clear();
      _isFinished = _studyCards.isEmpty;
      _currentIndex = 0;
      _isFront = true;
      _flipController.reset();
      _slideController.reset();
      _isLoading = false;
    });
  }

  void _flipCard() {
    if (_flipController.isAnimating) return;
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  void _swipeCard(bool remembered) {
    if (_slideController.isAnimating) return;
    
    _rememberedResults.add(remembered);

    setState(() {
      _slideTarget = remembered ? const Offset(1.5, 0.0) : const Offset(-1.5, 0.0);
      _slideAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: _slideTarget,
      ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));
    });

    _slideController.forward();
  }

  void _goToNextCard() {
    if (_currentIndex < _studyCards.length) {
      final card = _studyCards[_currentIndex];
      final remembered = _rememberedResults[_currentIndex];
      _repository.markCardAsLearned(_collection!.id, card.id, remembered);
    }

    if (_currentIndex + 1 >= _studyCards.length) {
      setState(() {
        _isFinished = true;
      });
    } else {
      setState(() {
        _currentIndex++;
        _isFront = true;
        _flipController.reset();
        _slideController.reset();
      });
    }
  }

  void _restartStudy({bool unrememberedOnly = false}) {
    if (_collection == null) return;

    List<Flashcard> nextStudy = [];
    if (unrememberedOnly) {
      for (int i = 0; i < _studyCards.length; i++) {
        if (i < _rememberedResults.length && !_rememberedResults[i]) {
          nextStudy.add(_studyCards[i]);
        }
      }
    } else {
      nextStudy = List.from(_collection!.flashcards);
    }

    if (nextStudy.isEmpty) {
      nextStudy = List.from(_collection!.flashcards);
    }

    setState(() {
      _studyCards = nextStudy;
      _rememberedResults.clear();
      _currentIndex = 0;
      _isFront = true;
      _isFinished = nextStudy.isEmpty;
      _flipController.reset();
      _slideController.reset();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(Color(0xFF28B79B)))),
      );
    }

    final collection = _collection!;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: SharedHeader(isDesktop: isDesktop, activeTab: 'Flashcard'),
        body: Column(
          children: [
            // Tabs selector header
            Container(
              color: Colors.white,
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Row(
                    children: [
                      // Back Button
                      IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF475569)),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          collection.title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            fontFamily: 'Outfit',
                          ),
                        ),
                      ),
                      const SizedBox(
                        width: 280,
                        child: TabBar(
                          indicatorColor: Color(0xFF28B79B),
                          labelColor: Color(0xFF28B79B),
                          unselectedLabelColor: Color(0xFF64748B),
                          labelStyle: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                          tabs: [
                            Tab(text: 'Study Mode'),
                            Tab(text: 'Terms List'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // TabBar View
            Expanded(
              child: TabBarView(
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStudyTab(isDesktop),
                  _buildTermsListTab(isDesktop),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: STUDY MODE
  Widget _buildStudyTab(bool isDesktop) {
    if (_isFinished) {
      return _buildFinishedSummary(isDesktop);
    }

    if (_studyCards.isEmpty) {
      return _buildEmptyState();
    }

    final card = _studyCards[_currentIndex];
    final progress = (_currentIndex + 1) / _studyCards.length;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 700),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Card ${_currentIndex + 1} of ${_studyCards.length}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                  ),
                ),
                Text(
                  '${(progress * 100).toInt()}% complete',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: const Color(0xFFE2E8F0),
                valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF28B79B)),
              ),
            ),
            const SizedBox(height: 36),

            Expanded(
              child: AnimatedBuilder(
                animation: _slideAnimation,
                builder: (context, child) {
                  return FractionalTranslation(
                    translation: _slideAnimation.value,
                    child: Transform(
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.001)
                        ..rotateY(_flipAnimation.value),
                      alignment: Alignment.center,
                      child: GestureDetector(
                        onTap: _flipCard,
                        child: _flipAnimation.value < pi / 2
                            ? _buildCardSide(card.frontText, 'TERM (Front)', isFront: true)
                            : Transform(
                                transform: Matrix4.identity()..rotateY(pi),
                                alignment: Alignment.center,
                                child: _buildCardSide(card.backText, 'DEFINITION (Back)', isFront: false),
                              ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 36),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildActionButton(
                  icon: Icons.close_rounded,
                  color: const Color(0xFFEF4444),
                  label: "Don't Remember",
                  onPressed: () => _swipeCard(false),
                ),
                const SizedBox(width: 48),
                _buildActionButton(
                  icon: Icons.check_rounded,
                  color: const Color(0xFF28B79B),
                  label: "Remembered",
                  onPressed: () => _swipeCard(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardSide(String text, String sideLabel, {required bool isFront}) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: 24,
            left: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isFront ? const Color(0xFFE6FFFA) : const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                sideLabel,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isFront ? const Color(0xFF137333) : const Color(0xFF1D4ED8),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),
          
          const Positioned(
            bottom: 24,
            right: 24,
            child: Row(
              children: [
                Icon(Icons.touch_app_rounded, size: 16, color: Color(0xFF94A3B8)),
                SizedBox(width: 4),
                Text(
                  'Click card to flip',
                  style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                )
              ],
            ),
          ),

          Center(
            child: Padding(
              padding: const EdgeInsets.all(40.0),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  height: 1.4,
                  fontFamily: 'Outfit',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(40),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 2),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'Outfit',
          ),
        )
      ],
    );
  }

  Widget _buildFinishedSummary(bool isDesktop) {
    final correctCount = _rememberedResults.where((r) => r).length;
    final total = _studyCards.length;
    final ratio = total > 0 ? correctCount / total : 0.0;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(32.0),
        margin: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFE6F4EA),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: Color(0xFF28B79B),
                size: 64,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Excellent!',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You have reviewed all flashcards in this set.',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontFamily: 'Outfit',
              ),
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryStat('Remembered', '$correctCount', const Color(0xFF28B79B)),
                  Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                  _buildSummaryStat('Forgot', '${total - correctCount}', const Color(0xFFEF4444)),
                  Container(width: 1, height: 40, color: const Color(0xFFE2E8F0)),
                  _buildSummaryStat('Accuracy', '${(ratio * 100).toInt()}%', const Color(0xFF3B82F6)),
                ],
              ),
            ),
            const SizedBox(height: 40),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _restartStudy(unrememberedOnly: false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: Color(0xFF28B79B)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text(
                      'Review All',
                      style: TextStyle(color: Color(0xFF28B79B), fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                    ),
                  ),
                ),
                if (correctCount < total) ...[
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _restartStudy(unrememberedOnly: true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'Review Forgot Only',
                        style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
              child: const Text('Back to Flashcards list', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryStat(String label, String val, Color color) {
    return Column(
      children: [
        Text(
          val,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'Outfit',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF64748B),
            fontFamily: 'Outfit',
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.style_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('No flashcards in this collection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              DefaultTabController.of(context).animateTo(1);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF28B79B)),
            child: const Text('Add Terms Now', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  // TAB 2: TERMS LIST (MANAGE TERMS)
  Widget _buildTermsListTab(bool isDesktop) {
    final collection = _collection!;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000),
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Heading with Create & Delete Term Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${collection.flashcards.length} Terms in this set',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                Row(
                  children: [
                    // Delete Set Button
                    OutlinedButton.icon(
                      onPressed: _showDeleteCollectionConfirmation,
                      icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFEF4444)),
                      label: const Text(
                        'Delete Set',
                        style: TextStyle(
                          color: Color(0xFFEF4444),
                          fontFamily: 'Outfit',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Add Term Button
                    ElevatedButton.icon(
                      onPressed: _showAddTermDialog,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add Term'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // List of cards
            Expanded(
              child: ListView.separated(
                itemCount: collection.flashcards.length,
                separatorBuilder: (c, i) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = collection.flashcards[index];
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.01),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left index number
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFFF1F5F9),
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              fontFamily: 'Outfit',
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),

                        // Term Details
                        Expanded(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Front (Term)
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'TERM',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF94A3B8),
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.frontText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E293B),
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 24),
                              
                              // Back (Definition)
                              Expanded(
                                flex: 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'DEFINITION',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF94A3B8),
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      item.backText,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF475569),
                                        fontFamily: 'Outfit',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Action icons (Edit / Delete)
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, color: Color(0xFF28B79B), size: 18),
                              onPressed: () => _showEditTermDialog(item, index),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                              onPressed: () => _deleteTerm(index),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // DELETE COLLECTION DIALOG
  void _showDeleteCollectionConfirmation() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 400),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFEE2E2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Color(0xFFEF4444),
                    size: 32,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Delete Flashcard Set?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Are you sure you want to delete "${_collection!.title}"? This action cannot be undone and will delete all terms.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF64748B),
                    fontFamily: 'Outfit',
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          side: const BorderSide(color: Color(0xFFE2E8F0)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final title = _collection!.title;
                          await _repository.deleteCollection(_collection!.id);
                          if (!mounted) return;
                          ToastHelper.showSuccess(context, 'Deleted set "$title" successfully!');
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEF4444),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                        ),
                        child: const Text('Delete', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ADD TERM DIALOG
  void _showAddTermDialog() {
    final frontController = TextEditingController();
    final backController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add New Term',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 20),
                
                const Text(
                  'Term (Front) *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: frontController,
                  decoration: InputDecoration(
                    hintText: 'Enter term...',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Definition (Back) *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: backController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter definition...',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                      child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final front = frontController.text.trim();
                        final back = backController.text.trim();

                        if (front.isEmpty || back.isEmpty) {
                          ToastHelper.showError(context, 'Please enter both term and definition.');
                          return;
                        }

                        final newCard = Flashcard(
                          id: 'c_${DateTime.now().millisecondsSinceEpoch}',
                          frontText: front,
                          backText: back,
                        );

                        final updatedCards = List<Flashcard>.from(_collection!.flashcards)..add(newCard);
                        final updatedCollection = _collection!.copyWith(
                          flashcards: updatedCards,
                          sentenceCount: updatedCards.length,
                          durationMinutes: (updatedCards.length * 1.5).ceil(),
                        );

                        await _repository.updateCollection(updatedCollection);
                        Navigator.pop(ctx);
                        _loadCollection();
                        if (mounted) {
                          ToastHelper.showSuccess(context, 'Term "$front" added successfully!');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Add', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // EDIT TERM DIALOG
  void _showEditTermDialog(Flashcard card, int index) {
    final frontController = TextEditingController(text: card.frontText);
    final backController = TextEditingController(text: card.backText);

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          backgroundColor: Colors.white,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Edit Term',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                    fontFamily: 'Outfit',
                  ),
                ),
                const SizedBox(height: 20),
                
                const Text(
                  'Term (Front) *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: frontController,
                  decoration: InputDecoration(
                    hintText: 'Enter term...',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                ),
                const SizedBox(height: 16),

                const Text(
                  'Definition (Back) *',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: backController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Enter definition...',
                    filled: true,
                    fillColor: const Color(0xFFF1F5F9),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF64748B)),
                      child: const Text('Cancel', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () async {
                        final front = frontController.text.trim();
                        final back = backController.text.trim();

                        if (front.isEmpty || back.isEmpty) {
                          ToastHelper.showError(context, 'Please enter both term and definition.');
                          return;
                        }

                        final updatedCards = List<Flashcard>.from(_collection!.flashcards);
                        updatedCards[index] = card.copyWith(
                          frontText: front,
                          backText: back,
                        );

                        final updatedCollection = _collection!.copyWith(
                          flashcards: updatedCards,
                        );

                        await _repository.updateCollection(updatedCollection);
                        Navigator.pop(ctx);
                        _loadCollection();
                        if (mounted) {
                          ToastHelper.showSuccess(context, 'Term updated successfully!');
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF28B79B),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Save', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // DELETE TERM
  void _deleteTerm(int index) async {
    final termText = _collection!.flashcards[index].frontText;
    final updatedCards = List<Flashcard>.from(_collection!.flashcards)..removeAt(index);
    final updatedCollection = _collection!.copyWith(
      flashcards: updatedCards,
      sentenceCount: updatedCards.length,
      durationMinutes: (updatedCards.length * 1.5).ceil(),
    );

    await _repository.updateCollection(updatedCollection);
    _loadCollection();
    if (mounted) {
      ToastHelper.showSuccess(context, 'Deleted term "$termText".');
    }
  }
}
