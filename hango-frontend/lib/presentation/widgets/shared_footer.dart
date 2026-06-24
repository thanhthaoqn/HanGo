import 'package:flutter/material.dart';

class SharedFooter extends StatelessWidget {
  final bool isDesktop;

  const SharedFooter({Key? key, required this.isDesktop}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFE6FFFA).withOpacity(0.3),
        border: const Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 48),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              isDesktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Logo & Statement
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Image.network(
                                'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
                                height: 36,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => const Text(
                                  'HanGo',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'The leading digital coaching platform for high school students aiming for distinction in the THPTQG English National Exam.',
                                style: TextStyle(
                                  color: Color(0xFF6B7280),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSocialRow(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 48),
                        
                        // Learning Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LEARNING',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                              ),
                              const SizedBox(height: 16),
                              _buildFooterLink('Mock Tests'),
                              _buildFooterLink('Vocabulary Sets'),
                              _buildFooterLink('Grammar Courses'),
                            ],
                          ),
                        ),
                        
                        // Support Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'SUPPORT',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                              ),
                              const SizedBox(height: 16),
                              _buildFooterLink('Learner FAQ'),
                              _buildFooterLink('Privacy Policy'),
                              _buildFooterLink('Terms of Service'),
                            ],
                          ),
                        )
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Image.network(
                          'https://res.cloudinary.com/diqekap4o/image/upload/v1781621071/logo_ayqvq4.png',
                          height: 36,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => const Text(
                            'HanGo',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'The leading digital coaching platform for high school students aiming for distinction in the THPTQG English National Exam.',
                          style: TextStyle(
                            color: Color(0xFF6B7280),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildSocialRow(),
                        const SizedBox(height: 32),
                        const Text(
                          'LEARNING',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        const Divider(),
                        _buildFooterLink('Mock Tests'),
                        _buildFooterLink('Vocabulary Sets'),
                        _buildFooterLink('Grammar Courses'),
                        const SizedBox(height: 24),
                        const Text(
                          'SUPPORT',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                        ),
                        const Divider(),
                        _buildFooterLink('Learner FAQ'),
                        _buildFooterLink('Privacy Policy'),
                        _buildFooterLink('Terms of Service'),
                      ],
                    ),
              
              const SizedBox(height: 32),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 16),
              const Text(
                '© 2026 HanGo Platform. All rights reserved.',
                style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooterLink(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: InkWell(
        onTap: () {},
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFF6B7280),
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildSocialRow() {
    return Row(
      children: [
        _buildSocialIcon(Icons.language),
        const SizedBox(width: 8),
        _buildSocialIcon(Icons.share),
      ],
    );
  }

  Widget _buildSocialIcon(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Center(
        child: Icon(
          icon,
          size: 16,
          color: const Color(0xFF28B79B),
        ),
      ),
    );
  }
}
