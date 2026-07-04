import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../data/repositories/flashcard_repository.dart';
import '../../../domain/entities/flashcard.dart';
import '../../widgets/shared_header.dart';
import '../../widgets/shared_footer.dart';
import '../../widgets/flashcard_card.dart';
import '../learner/learner_home_page.dart';
import 'study_flashcard_page.dart';
import '../../../utils/toast_helper.dart';

class ListFlashcardsPage extends StatefulWidget {
  const ListFlashcardsPage({Key? key}) : super(key: key);

  @override
  State<ListFlashcardsPage> createState() => _ListFlashcardsPageState();
}

class _ListFlashcardsPageState extends State<ListFlashcardsPage> {
  final FlashcardRepository _repository = FlashcardRepository();
  
  List<FlashcardCollection> _collections = [];
  List<FlashcardCollection> _filteredCollections = [];
  FlashcardCollection? _heroCollection;
  bool _isLoading = true;

  String _searchQuery = '';
  String _activeFilter = 'All'; // 'All' | 'Recents' | 'Learned' | 'Created'
  final TextEditingController _searchController = TextEditingController();

  String _userName = 'Learner';

  @override
  void initState() {
    super.initState();
    _loadUserAndData();
  }

  Future<void> _loadUserAndData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userName = prefs.getString('user_fullname') ?? 'Learner';
    });
    await _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all collections for hero calculations
      final all = await _repository.fetchCollections(status: 'All');
      
      // Get filtered collections
      final filtered = await _repository.fetchCollections(status: _activeFilter);

      // Find the hero collection (most recently studied, or fallback to first)
      FlashcardCollection? hero;
      final recentList = await _repository.fetchCollections(status: 'Recents');
      if (recentList.isNotEmpty) {
        hero = recentList.first;
      } else if (all.isNotEmpty) {
        hero = all.first;
      }

      setState(() {
        _collections = filtered;
        _heroCollection = hero;
        _applySearch();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('[ListFlashcardsPage] Error fetching collections: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applySearch() {
    if (_searchQuery.trim().isEmpty) {
      _filteredCollections = List.from(_collections);
    } else {
      final query = _searchQuery.toLowerCase().trim();
      _filteredCollections = _collections.where((c) {
        return c.title.toLowerCase().contains(query) ||
            c.description.toLowerCase().contains(query) ||
            c.creator.toLowerCase().contains(query);
      }).toList();
    }
  }

  void _onSearchChanged(String val) {
    setState(() {
      _searchQuery = val;
      _applySearch();
    });
  }

  void _onFilterChanged(String? filter) {
    if (filter != null && filter != _activeFilter) {
      setState(() {
        _activeFilter = filter;
      });
      _fetchData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50 background
      appBar: SharedHeader(isDesktop: isDesktop, activeTab: 'Flashcard'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1440),
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 40 : 16,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back Navigation Row
                    _buildBackRow(),
                    const SizedBox(height: 24),

                    // Hero Banner (Speed Grammar)
                    if (_heroCollection != null) ...[
                      _buildHeroBanner(isDesktop, size.width),
                      const SizedBox(height: 32),
                    ],

                    // Filter and Search Row
                    _buildFilterAndSearchRow(isDesktop),
                    const SizedBox(height: 24),

                    // Grid of Flashcard cards
                    _isLoading
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(48.0),
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFF28B79B),
                                ),
                              ),
                            ),
                          )
                        : _buildGrid(isDesktop),
                  ],
                ),
              ),
            ),
            SharedFooter(isDesktop: isDesktop),
          ],
        ),
      ),
    );
  }

  Widget _buildBackRow() {
    return InkWell(
      onTap: () {
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const LearnerHomePage()),
            (route) => false,
          );
        }
      },
      hoverColor: Colors.transparent,
      splashColor: Colors.transparent,
      highlightColor: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.arrow_back_ios_rounded, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 4),
          Text(
            'Back to Home',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w600,
              fontSize: 14,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterAndSearchRow(bool isDesktop) {
    final dropdownWidget = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _activeFilter,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF64748B),
            size: 20,
          ),
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.bold,
            fontSize: 15,
            fontFamily: 'Outfit',
          ),
          borderRadius: BorderRadius.circular(16),
          items: const {
            'All': 'All Flashcards',
            'Recents': 'Recents',
            'Learned': 'Learned',
            'Created': 'My Collections',
          }.entries.map((entry) {
            return DropdownMenuItem<String>(
              value: entry.key,
              child: Text(entry.value),
            );
          }).toList(),
          onChanged: _onFilterChanged,
        ),
      ),
    );

    final createButton = MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: _showCreateCollectionDialog,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: const Icon(
            Icons.add_rounded,
            color: Color(0xFF0F172A),
            size: 28,
          ),
        ),
      ),
    );

    final searchField = Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        decoration: InputDecoration(
          hintText: 'Search flashcards...',
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
            fontFamily: 'Outfit',
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Color(0xFF28B79B),
            size: 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B), size: 18),
                  onPressed: () {
                    _searchController.clear();
                    _onSearchChanged('');
                  },
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        style: const TextStyle(
          color: Color(0xFF1E293B),
          fontFamily: 'Outfit',
          fontSize: 14,
        ),
      ),
    );

    if (isDesktop) {
      return Row(
        children: [
          dropdownWidget,
          const SizedBox(width: 16),
          Expanded(child: searchField),
          const SizedBox(width: 16),
          createButton,
        ],
      );
    } else {
      return Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              dropdownWidget,
              createButton,
            ],
          ),
          const SizedBox(height: 12),
          searchField,
        ],
      );
    }
  }

  Widget _buildHeroBanner(bool isDesktop, double screenWidth) {
    final hero = _heroCollection!;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isDesktop ? 48.0 : 24.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF28B79B), Color(0xFF209D84)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF28B79B).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hero.title,
            style: TextStyle(
              color: Colors.white,
              fontSize: isDesktop ? 38 : 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Outfit',
              height: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            hero.description.isNotEmpty 
                ? hero.description 
                : 'Tiếp tục rèn luyện kỹ năng và mở rộng vốn từ của bạn ngay hôm nay.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: isDesktop ? 16 : 14,
              fontFamily: 'Outfit',
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  _navigateToStudy(hero);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  surfaceTintColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    color: Color(0xFF1F9E84),
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Outfit',
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(bool isDesktop) {
    if (_filteredCollections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 60),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.style_outlined, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                'No flashcard sets found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Try changing filters or search query',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontFamily: 'Outfit',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final size = MediaQuery.of(context).size;
    int crossAxisCount = 4;
    if (size.width < 600) {
      crossAxisCount = 1;
    } else if (size.width < 1000) {
      crossAxisCount = 2;
    } else if (size.width < 1250) {
      crossAxisCount = 3;
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 24,
        mainAxisSpacing: 24,
        childAspectRatio: 0.88, // Card proportion matching the mockup
      ),
      itemCount: _filteredCollections.length,
      itemBuilder: (context, index) {
        final collection = _filteredCollections[index];
        return FlashcardCard(
          collection: collection,
          onTap: () => _navigateToStudy(collection),
        );
      },
    );
  }

  void _navigateToStudy(FlashcardCollection collection) async {
    await _repository.touchCollection(collection.id);
    if (!mounted) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StudyFlashcardPage(collectionId: collection.id),
      ),
    );
    _fetchData();
  }

  // CREATE COLLECTION FLOW
  void _showCreateCollectionDialog() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final List<Map<String, TextEditingController>> cardControllers = [
      {
        'front': TextEditingController(),
        'back': TextEditingController(),
      }
    ];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 16,
              backgroundColor: Colors.white,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 650, maxHeight: 750),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Create Flashcard Collection',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                            fontFamily: 'Outfit',
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(height: 24, color: Color(0xFFE2E8F0)),

                    // Scrollable Fields
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title input
                            const Text(
                              'Collection Title *',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF334155),
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: titleController,
                              decoration: InputDecoration(
                                hintText: 'Enter title (e.g. 50 Tự Vựng Tiếng Anh Ôn Thi)',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Description input
                            const Text(
                              'Description',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF334155),
                                fontFamily: 'Outfit',
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: descController,
                              maxLines: 2,
                              decoration: InputDecoration(
                                hintText: 'What is this collection about?',
                                hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Cards header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Flashcards List',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF0F172A),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setDialogState(() {
                                      cardControllers.add({
                                        'front': TextEditingController(),
                                        'back': TextEditingController(),
                                      });
                                    });
                                  },
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                  label: const Text('Add Card'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF28B79B),
                                    textStyle: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            // Card items list
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: cardControllers.length,
                              separatorBuilder: (c, idx) => const SizedBox(height: 12),
                              itemBuilder: (context, idx) {
                                final row = cardControllers[idx];
                                return Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF8FAFC),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: const Color(0xFFE2E8F0)),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Card Number
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: const Color(0xFFE2E8F0),
                                        child: Text(
                                          '${idx + 1}',
                                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      
                                      // Card front/back inputs
                                      Expanded(
                                        child: Column(
                                          children: [
                                            TextField(
                                              controller: row['front'],
                                              decoration: const InputDecoration(
                                                hintText: 'Front (Term / Word) *',
                                                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                                isDense: true,
                                                border: InputBorder.none,
                                              ),
                                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                            ),
                                            const Divider(height: 10, color: Color(0xFFE2E8F0)),
                                            TextField(
                                              controller: row['back'],
                                              decoration: const InputDecoration(
                                                hintText: 'Back (Definition / Translation) *',
                                                hintStyle: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                                                isDense: true,
                                                border: InputBorder.none,
                                              ),
                                              style: const TextStyle(fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Delete button
                                      if (cardControllers.length > 1)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 18),
                                          onPressed: () {
                                            setDialogState(() {
                                              cardControllers.removeAt(idx);
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    const Divider(height: 24, color: Color(0xFFE2E8F0)),

                    // Footer Buttons
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
                            final title = titleController.text.trim();
                            if (title.isEmpty) {
                              ToastHelper.showError(context, 'Please enter a collection title.');
                              return;
                            }

                            final List<Flashcard> cards = [];
                            for (int i = 0; i < cardControllers.length; i++) {
                              final front = cardControllers[i]['front']!.text.trim();
                              final back = cardControllers[i]['back']!.text.trim();

                              if (front.isEmpty || back.isEmpty) {
                                ToastHelper.showError(context, 'Card #${i + 1} has empty fields. All cards must have term & definition.');
                                return;
                              }

                              cards.add(Flashcard(
                                id: 'c_${DateTime.now().millisecondsSinceEpoch}_$i',
                                frontText: front,
                                backText: back,
                              ));
                            }

                            final collection = FlashcardCollection(
                              id: '',
                              title: title,
                              description: descController.text.trim(),
                              creator: _userName,
                              sentenceCount: cards.length,
                              durationMinutes: (cards.length * 1.5).ceil(), // Rough estimate
                              rating: 5.0,
                              learnerCount: '1 Learner',
                              flashcards: cards,
                            );

                            await _repository.createCollection(collection);
                            Navigator.pop(ctx);
                            _fetchData();

                            if (mounted) {
                              ToastHelper.showSuccess(context, 'Created collection "$title" successfully!');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF28B79B),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
      },
    );
  }
}
