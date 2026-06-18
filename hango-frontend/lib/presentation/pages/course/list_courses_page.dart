import 'package:flutter/material.dart';
import '../../../data/repositories/course_repository.dart';
import '../../../domain/model/course.dart';
import '../../widgets/course_card.dart';
import '../../widgets/shared_header.dart';

class ListCoursesPage extends StatefulWidget {
  const ListCoursesPage({Key? key}) : super(key: key);

  @override
  State<ListCoursesPage> createState() => _ListCoursesPageState();
}

class _ListCoursesPageState extends State<ListCoursesPage> {
  final CourseRepository _repository = CourseRepository();
  late Future<List<Course>> _coursesFuture;

  String _searchQuery = '';
  String _filterType = 'All'; // All, Enrolled
  String _difficulty = 'All'; // All, Beginner, Medium, Hard

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  void _fetchCourses() {
    // Map dropdown value "Enrolled" to "ENROLLED", "Beginner" to "EASY" if needed, 
    // or just pass as is and let backend handle it.
    // Assuming backend handles "ENROLLED" and "EASY"
    String backendFilterType = _filterType == 'Enrolled' ? 'ENROLLED' : 'ALL';
    String backendDifficulty = 'ALL';
    if (_difficulty == 'Beginner') backendDifficulty = 'EASY';
    if (_difficulty == 'Medium') backendDifficulty = 'MEDIUM';
    if (_difficulty == 'Hard') backendDifficulty = 'HARD';

    setState(() {
      _coursesFuture = _repository.fetchCourses(
        search: _searchQuery,
        filterType: backendFilterType,
        difficulty: backendDifficulty,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 900;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: SharedHeader(isDesktop: isDesktop, activeTab: 'Courses'),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1200),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Back Button
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                      },
                      hoverColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back_ios, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text(
                              'Back to Home',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    _buildBanner(),
                    _buildFilters(),
                    _buildGrid(),
                  ],
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24.0),
      padding: const EdgeInsets.symmetric(horizontal: 48.0, vertical: 48.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF209D84), Color(0xFF135D4E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A28B79B),
            blurRadius: 15,
            offset: Offset(0, 6),
          )
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A smart exam preparation platform with course suggestions, a question bank structured according to the Ministry of Education and Training\'s standards, and in-depth AI-assisted learning.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 48,
                  runSpacing: 16,
                  children: [
                    _buildStat('40,000+', 'Students trust and use it'),
                    _buildStat('50+', 'Awesome practice test'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Center(
              child: Icon(
                Icons.laptop_chromebook,
                size: 120,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String number, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 26,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 13,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: TextField(
              onChanged: (value) {
                _searchQuery = value;
                // debounce or search on enter. Let's just update on enter for simplicity
              },
              onSubmitted: (value) {
                _fetchCourses();
              },
              decoration: InputDecoration(
                hintText: 'Search for courses...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<String>(
              value: _filterType,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: ['All', 'Enrolled'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _filterType = newValue!;
                  _fetchCourses();
                });
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: DropdownButtonFormField<String>(
              value: _difficulty,
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              items: ['All', 'Beginner', 'Medium', 'Hard'].map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _difficulty = newValue!;
                  _fetchCourses();
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid() {
    return FutureBuilder<List<Course>>(
      future: _coursesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: Text('Error: ${snapshot.error}')),
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40.0),
            child: Center(child: Text('No courses found.')),
          );
        }

        final courses = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: courses.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              childAspectRatio: 0.85,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemBuilder: (context, index) {
              return CourseCard(course: courses[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildFooter() {
    return Container(
      color: const Color(0xFFF6FBF9),
      padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 40.0),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo and description
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.school, color: Color(0xFF38B29E)),
                        SizedBox(width: 8),
                        Text(
                          'HanGo',
                          style: TextStyle(
                            color: Color(0xFF38B29E),
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'The leading digital coaching platform for high school students aiming for distinction in the THPTQG English National Exam.',
                      style: TextStyle(color: Colors.black54, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        _buildSocialIcon(Icons.facebook),
                        const SizedBox(width: 16),
                        _buildSocialIcon(Icons.link), // Placeholder for other icons
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(width: 40),
              // Learning Links
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('LEARNING', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    Text('Mock Tests', style: TextStyle(color: Colors.black54)),
                    SizedBox(height: 8),
                    Text('Vocabulary Sets', style: TextStyle(color: Colors.black54)),
                    SizedBox(height: 8),
                    Text('Grammar Courses', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              // Support Links
              Expanded(
                flex: 1,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('SUPPORT', style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 16),
                    Text('Learner FAQ', style: TextStyle(color: Colors.black54)),
                    SizedBox(height: 8),
                    Text('Privacy Policy', style: TextStyle(color: Colors.black54)),
                    SizedBox(height: 8),
                    Text('Terms of Service', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          const Divider(color: Colors.black12),
          const SizedBox(height: 20),
          const Text(
            '© 2024 HanGo. Built for academic excellence.',
            style: TextStyle(color: Colors.black54, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Icon(icon, color: Colors.grey.shade600, size: 20),
    );
  }
}
