import 'package:flutter/material.dart';

class TermsAndPrivacyPage extends StatefulWidget {
  final int initialTab; // 0: Terms of Service, 1: Privacy Policy

  const TermsAndPrivacyPage({
    super.key,
    this.initialTab = 0,
  });

  @override
  State<TermsAndPrivacyPage> createState() => _TermsAndPrivacyPageState();
}

class _TermsAndPrivacyPageState extends State<TermsAndPrivacyPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1F2937)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF28B79B).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gavel_rounded,
                color: Color(0xFF28B79B),
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Legal & Compliance',
              style: TextStyle(
                color: Color(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF28B79B),
          unselectedLabelColor: const Color(0xFF6B7280),
          indicatorColor: const Color(0xFF28B79B),
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
          tabs: const [
            Tab(text: 'Terms of Service'),
            Tab(text: 'Privacy Policy'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDocumentView(
            title: 'Terms of Service',
            effectiveDate: 'August 14, 2026',
            version: 'v1.0',
            content: _buildTermsOfServiceContent(),
          ),
          _buildDocumentView(
            title: 'Privacy Policy',
            effectiveDate: 'August 14, 2026',
            version: 'v1.0',
            content: _buildPrivacyPolicyContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentView({
    required String title,
    required String effectiveDate,
    required String version,
    required List<Widget> content,
  }) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850),
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Document Header
              Text(
                title,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F7F4),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Effective: $effectiveDate',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF28B79B),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Version: $version',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 24),

              // Content Body
              ...content,

              const SizedBox(height: 32),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 24),

              // Footer Note
              Center(
                child: Text(
                  '© 2026 HanGo Platform. All rights reserved.',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTermsOfServiceContent() {
    return [
      _buildSectionTitle('1. Acceptance of Terms'),
      _buildParagraph(
        'Welcome to HanGo (Smart Language Self-Study Platform). By accessing, registering an account, '
        'or using any services on the HanGo platform, you agree to comply with and be bound by these Terms of Service. '
        'HanGo operates as an intermediary digital platform connecting content creators (Trainers) with learners (Learners), '
        'enhanced by artificial intelligence tools.',
      ),

      _buildSectionTitle('2. User Accounts & Phased Dual-Mode'),
      _buildParagraph(
        '2.1 Registration & Verification: Users must register with a valid email address and verify via a 6-digit OTP code '
        '(valid for 5 minutes). Each individual is permitted to maintain one primary account.',
      ),
      _buildParagraph(
        '2.2 User Roles:\n'
        '• Learner: Access learning materials, purchase courses, complete quizzes/exams, and receive AI-driven weakness analysis & personalized learning pathways.\n'
        '• Trainer (Professional Teacher / Peer Tutor): Create and publish courses, quizzes, and exams. Trainer accounts feature an integrated Dual-Mode, allowing Trainers to switch between Trainer Mode and Learner Mode to enroll in courses created by peers.\n'
        '• Course Manager: Quality assurance, content reviewing (Course & Exam approval/rejection), management of Exam Matrices, support ticket handling, and financial revenue settlements.\n'
        '• Administrator: System governance, account lifecycle management, RBAC permission matrix configuration, AI usage tracking, and audit log monitoring.',
      ),

      _buildSectionTitle('3. Content Rights & Quality Control'),
      _buildParagraph(
        '3.1 Intellectual Property: All original course contents, lessons, and media uploaded by Trainers remain the intellectual property of the respective Trainer. Trainers grant HanGo a non-exclusive license to host and distribute the content.',
      ),
      _buildParagraph(
        '3.2 Review & Publication Workflow: Every course and independent exam created by a Trainer must undergo formal review by a Course Manager. Content is made public only upon approval (state: PUBLISHED).',
      ),
      _buildParagraph(
        '3.3 Course Pricing & First Free Course Rule: Each Trainer\'s first published course MUST be offered completely FREE of charge. For paid courses, HanGo provides an automated algorithmic suggested price based on tier and scope, but the final price is chosen by the Trainer.',
      ),

      _buildSectionTitle('4. Revenue Sharing, Payments & Taxes'),
      _buildParagraph(
        '4.1 Revenue Split:\n'
        '• Professional Teachers: 70% Trainer / 30% HanGo Platform.\n'
        '• Peer Tutors: 60% Trainer / 40% HanGo Platform.',
      ),
      _buildParagraph(
        '4.2 Payment Gateway: All transactions are processed in VND via the PayOS online payment gateway with secure HMAC-SHA256 signature verification.',
      ),
      _buildParagraph(
        '4.3 Monthly Statements & Tax Withholding: Revenue payouts are settled monthly via manual bank transfer after Trainer confirmation. In accordance with Vietnamese Tax Regulations (Clause 1 Article 25 Circular 111/2013/TT-BTC), a 10% Personal Income Tax (PIT) withholding applies at source for Trainers with total gross earnings of 2,000,000 VND or higher per period.',
      ),
      _buildParagraph(
        '4.4 Refund Policy: Due to the immediate access nature of digital educational content, purchases are non-refundable. Technical issues or accidental duplicate charges are resolved manually via our Ticket Support System.',
      ),

      _buildSectionTitle('5. Artificial Intelligence (AI) Features'),
      _buildParagraph(
        'HanGo integrates Google Gemini API to power AI Assistant in lessons, post-exam Weakness Analysis, Personalized Learning Pathways, and automated question generation. AI output is designed for educational assistance; HanGo continuously optimizes AI accuracy but does not guarantee 100% error-free outputs.',
      ),

      _buildSectionTitle('6. Code of Conduct & Termination'),
      _buildParagraph(
        'Users must not post unlawful, defamatory, or copyright-infringing material, attempt to automate exam completions, or engage in spam/hate speech in comments. HanGo reserves the right to suspend or terminate accounts violating these terms.',
      ),
    ];
  }

  List<Widget> _buildPrivacyPolicyContent() {
    return [
      _buildSectionTitle('1. Information We Collect'),
      _buildParagraph(
        '1.1 Personal Identification: Full name, email address, password (hashed using BCrypt), profile avatar, and phone number. If registering via "Sign in with Google", we receive basic OAuth profile details.',
      ),
      _buildParagraph(
        '1.2 Trainer Credentials & Financial Data: Certificate images/score reports (scoreReportUrl) submitted during application, and bank account details for revenue payouts and tax compliance.',
      ),
      _buildParagraph(
        '1.3 Learning & Interaction Activity: Lesson completion history, quiz/exam attempt results, incorrect answer data used for Weakness Analysis, AI Assistant chat interactions, reviews, comments, and support tickets.',
      ),
      _buildParagraph(
        '1.4 Payment Information: Transaction IDs, payment timestamps, and payment statuses provided by PayOS. HanGo does NOT store full bank card numbers or banking credentials.',
      ),

      _buildSectionTitle('2. How We Use Your Information'),
      _buildParagraph(
        'We process personal data strictly for:\n'
        '• Delivering LMS features (course enrollment, lesson progress tracking, certificates).\n'
        '• AI Personalization (analyzing weaknesses via Google Gemini to generate custom learning pathways).\n'
        '• Financial Settlement (calculating Trainer earnings, executing payouts, and applying 10% PIT tax withholding).\n'
        '• System Communication (sending OTP verification emails, purchase receipts, and ticket status updates).\n'
        '• Security & Monitoring (logging AI usage, enforcing RBAC permissions, and preventing fraud).',
      ),

      _buildSectionTitle('3. Third-Party Data Sharing'),
      _buildParagraph(
        'We never sell or rent your personal information. Data is shared strictly with trusted infrastructure providers:',
      ),
      _buildBulletPoint('PayOS Payment Gateway: Transaction amounts and IDs for secure checkout.'),
      _buildBulletPoint('Google Gemini API: Lesson context and exercise prompts for AI assistance and pathway generation.'),
      _buildBulletPoint('Cloudinary: Media storage for lesson videos, PDFs, avatars, and certificate files.'),
      _buildBulletPoint('SMTP Email Service: Dispatching OTP codes and critical system alerts.'),

      _buildSectionTitle('4. Data Security & Retention'),
      _buildParagraph(
        'HanGo employs JWT access tokens with single-use hashed Refresh Token rotation, HTTPS data encryption, and strict RBAC controls. Personal data is stored for the active duration of your account.',
      ),

      _buildSectionTitle('5. Your Privacy Rights'),
      _buildParagraph(
        'You have the right to view and update your profile information, change your password, request account deactivation, or contact support via our Ticket System regarding data privacy concerns.',
      ),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1F2937),
        ),
      ),
    );
  }

  Widget _buildParagraph(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          color: Color(0xFF4B5563),
          height: 1.6,
        ),
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16.0, bottom: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF28B79B),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B5563),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
