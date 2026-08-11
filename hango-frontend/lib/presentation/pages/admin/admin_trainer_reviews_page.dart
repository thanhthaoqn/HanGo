import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';

class AdminTrainerReviewsPage extends StatefulWidget {
  const AdminTrainerReviewsPage({super.key});

  @override
  State<AdminTrainerReviewsPage> createState() => _AdminTrainerReviewsPageState();
}

class _AdminTrainerReviewsPageState extends State<AdminTrainerReviewsPage> {
  final _onboardingService = TrainerOnboardingService();
  
  List<dynamic> _applications = [];
  bool _isLoading = true;
  String _statusFilter = 'AWAITING_APPROVAL'; // ALL | AWAITING_APPROVAL | VERIFIED | SUSPENDED
  String _searchQuery = '';

  int _currentPage = 1;
  int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _fetchApplications();
  }

  void _fetchApplications({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    final result = await _onboardingService.getTrainerProfilesForAdmin(
      status: _statusFilter,
      search: _searchQuery,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        _currentPage = 1;
        if (result['success'] == true) {
          _applications = result['data'] ?? [];
        } else {
          ToastHelper.showError(context, result['message'] ?? 'Error loading profiles');
        }
      });
    }
  }

  void _handleReview(int userId, String status, String? notes, double? splitRate) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF28B79B)),
      ),
    );

    final result = await _onboardingService.reviewTrainerProfile(
      userId,
      status: status,
      adminNotes: notes,
      revenueShare: splitRate,
    );

    if (mounted) {
      Navigator.pop(context); // Close loading dialog
      if (result['success'] == true) {
        ToastHelper.showSuccess(
          context,
          'Profile reviewed successfully!',
        );
        _fetchApplications(silent: true); // Silently refresh the list without blanking screen
      } else {
        ToastHelper.showError(context, result['message'] ?? 'Review action failed');
      }
    }
  }

  void _showRejectDialog(int userId) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 28),
              SizedBox(width: 12),
              Text(
                'Reject Application',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter detailed rejection reason for the applicant (Visible to Trainer):',
                style: TextStyle(fontSize: 14, color: Color(0xFF64748B), fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                maxLines: 4,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Example: Pedagogical degree is missing or IELTS certificate scan is unreadable. Please re-upload clear credentials...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final notes = noteController.text.trim();
                if (notes.isEmpty) {
                  ToastHelper.showError(context, 'Please enter a rejection reason.');
                  return;
                }
                Navigator.pop(context);
                _handleReview(userId, 'PENDING_VERIFICATION', notes, null);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                'Reject Application',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showApproveDialog(int userId, String trainerType) {
    final isPro = trainerType == 'PROFESSIONAL';
    final double defaultRate = isPro ? 0.70 : 0.60;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_outline_rounded, color: Color(0xFF28B79B), size: 28),
              SizedBox(width: 12),
              Text(
                'Approve Trainer Application',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to approve this trainer application?',
                style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A), fontFamily: 'Outfit'),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6FDF9),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF059669), size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Account Type: ${isPro ? "Professional Teacher (70/30 Split)" : "Peer Tutor (60/40 Split)"}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF065F46), fontFamily: 'Outfit'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _handleReview(userId, 'VERIFIED', 'Verified credentials valid', defaultRate);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF28B79B),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
              child: const Text(
                'Approve Application',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRejectProfileConfirmDialog(int userId) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 28),
              SizedBox(width: 12),
              Text(
                'Reject Profile Application',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to reject this trainer profile application?',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 14, color: Color(0xFF475569), height: 1.5),
              ),
              const SizedBox(height: 16),
              const Text(
                'Reason for Rejection (Visible to Trainer) *',
                style: TextStyle(fontFamily: 'Outfit', fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                maxLines: 3,
                style: const TextStyle(fontFamily: 'Outfit', fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Enter reason for rejection (e.g., Unclear diploma scan, invalid language certificate, unverified credentials)...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.redAccent, width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final notes = noteController.text.trim();
                if (notes.isEmpty) {
                  ToastHelper.showError(context, 'Please enter a rejection reason.');
                  return;
                }
                Navigator.pop(context);
                _handleReview(userId, 'SUSPENDED', notes, null);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.redAccent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: const Text(
                'Confirm Reject',
                style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }


  void _showDetailDialog(dynamic app) {
    final userId = app['userId'] as int;
    final fullName = app['fullName'] ?? 'N/A';
    final email = app['email'] ?? 'N/A';
    final phone = app['phoneNumber'] ?? 'N/A';
    final bio = app['bio'] ?? '';
    final type = app['trainerType'] ?? 'PROFESSIONAL';
    final status = app['status'] ?? 'PENDING_VERIFICATION';
    
    final scoreUrl = app['scoreReportUrl'] as String?;
    final avatarUrl = app['avatarUrl'] as String?;

    final bioRejectController = TextEditingController();
    final certRejectController = TextEditingController();
    bool isRejectingMode = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 800),
                padding: const EdgeInsets.all(28),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title Header with Avatar
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor: const Color(0xFFE2E8F0),
                            backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                                ? NetworkImage(avatarUrl)
                                : null,
                            child: (avatarUrl == null || avatarUrl.isEmpty)
                                ? Text(
                                    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'T',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Trainer Profile: $fullName',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$email • $phone',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFFE2E8F0)),
                      const SizedBox(height: 16),

                      // Bio Section
                      const Text(
                        'Teacher Introduction & Bio:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bio.isNotEmpty ? bio : 'No Bio provided.',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569), height: 1.4, fontFamily: 'Outfit'),
                      ),
                      if (isRejectingMode) ...[
                        const SizedBox(height: 8),
                        TextField(
                          controller: bioRejectController,
                          maxLines: 2,
                          style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                          decoration: InputDecoration(
                            hintText: 'Enter rejection reason for Bio (e.g. Bio lacks teaching experience details)...',
                            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                            fillColor: const Color(0xFFFEF2F2),
                            filled: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
                          ),
                        ),
                      ] else if (status != 'VERIFIED' && app['adminNotes'] != null && app['adminNotes'].toString().trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCA5A5)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Previous Rejection Reason: ${app['adminNotes']}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontFamily: 'Outfit'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),

                      // Qualifications & Proof images
                      const Text(
                        'Qualifications & Competency Proofs (Click to zoom):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
                      ),
                      const SizedBox(height: 12),
                      Builder(
                        builder: (context) {
                          List<Map<String, String>> certList = [];
                          final rawCerts = app['certificates'];
                          if (rawCerts != null && rawCerts is List && rawCerts.isNotEmpty) {
                            certList = (rawCerts as List).map((c) => Map<String, String>.from(c as Map)).toList();
                          } else if (scoreUrl != null && scoreUrl.isNotEmpty) {
                            if (scoreUrl.startsWith('[')) {
                              try {
                                final List parsed = jsonDecode(scoreUrl);
                                certList = parsed.map((c) => Map<String, String>.from(c as Map)).toList();
                              } catch (_) {}
                            } else {
                              certList.add({'name': 'Credential Proof', 'url': scoreUrl});
                            }
                          }

                          if (certList.isEmpty) {
                            return const Text(
                              'No certificates uploaded.',
                              style: TextStyle(fontSize: 13, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8), fontFamily: 'Outfit'),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: certList.map((item) {
                                  final label = item['name'] ?? 'Proof';
                                  final url = item['url'] ?? '';
                                  return SizedBox(
                                    width: 220,
                                    child: _buildProofImageCard(label, url),
                                  );
                                }).toList(),
                              ),
                              if (isRejectingMode) ...[
                                const SizedBox(height: 12),
                                TextField(
                                  controller: certRejectController,
                                  maxLines: 2,
                                  style: const TextStyle(fontFamily: 'Outfit', fontSize: 13),
                                  decoration: InputDecoration(
                                    hintText: 'Enter rejection reason for Credentials & Certificates (e.g. Missing pedagogical degree)...',
                                    hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                                    fillColor: const Color(0xFFFEF2F2),
                                    filled: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFCA5A5))),
                                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.redAccent, width: 2)),
                                  ),
                                ),
                              ] else if (status != 'VERIFIED' && app['adminNotes'] != null && app['adminNotes'].toString().trim().isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFFCA5A5)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.info_outline, color: Colors.redAccent, size: 16),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Rejection Note on Credentials: ${app['adminNotes']}',
                                          style: const TextStyle(fontSize: 12, color: Color(0xFF991B1B), fontFamily: 'Outfit'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      
                      if (status == 'AWAITING_APPROVAL') ...[
                        const SizedBox(height: 32),
                        const Divider(color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 16),
                        if (isRejectingMode)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: () {
                                  setModalState(() {
                                    isRejectingMode = false;
                                  });
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(color: Color(0xFF64748B), fontFamily: 'Outfit'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  final bioNote = bioRejectController.text.trim();
                                  final certNote = certRejectController.text.trim();
                                  if (bioNote.isEmpty && certNote.isEmpty) {
                                    ToastHelper.showError(context, 'Please enter a rejection reason for Bio or Certificates.');
                                    return;
                                  }
                                  String combined = '';
                                  if (bioNote.isNotEmpty && certNote.isNotEmpty) {
                                    combined = 'Bio: $bioNote | Certificates: $certNote';
                                  } else if (bioNote.isNotEmpty) {
                                    combined = 'Bio: $bioNote';
                                  } else {
                                    combined = 'Certificates: $certNote';
                                  }
                                  Navigator.pop(context);
                                  _handleReview(userId, 'PENDING_VERIFICATION', combined, null);
                                },
                                icon: const Icon(Icons.cancel_outlined, size: 16),
                                label: const Text('Reject Application'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () {
                                  setModalState(() {
                                    isRejectingMode = true;
                                  });
                                },
                                icon: const Icon(Icons.cancel_outlined, size: 16, color: Colors.redAccent),
                                label: const Text('Reject Application'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.redAccent,
                                  side: const BorderSide(color: Colors.redAccent),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                  _showApproveDialog(userId, type);
                                },
                                icon: const Icon(Icons.check_circle_rounded, size: 16),
                                label: const Text('Approve Application'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF28B79B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                      ] else ...[
                        const SizedBox(height: 32),
                        const Divider(color: Color(0xFFE2E8F0)),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: _getStatusBgColor(status),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    status == 'VERIFIED' ? Icons.check_circle_rounded : Icons.cancel_rounded,
                                    size: 16,
                                    color: _getStatusTextColor(status),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Status: ${_getStatusText(status)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: _getStatusTextColor(status),
                                      fontFamily: 'Outfit',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close_rounded, size: 16),
                              label: const Text('Close'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF64748B),
                                side: const BorderSide(color: Color(0xFFCBD5E1)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'),
        ),
        Text(
          value.isNotEmpty ? value : 'N/A',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B), fontFamily: 'Outfit'),
        ),
      ],
    );
  }

  Widget _buildApplicationRow(dynamic app) {
    final userId = app['userId'] as int;
    final fullName = app['fullName'] ?? 'N/A';
    final email = app['email'] ?? 'N/A';
    final type = app['trainerType'] ?? 'PROFESSIONAL';
    final status = app['status'] ?? 'PENDING_VERIFICATION';

    final rawDate = app['submittedAt'];
    String dateStr = 'N/A';
    if (rawDate != null) {
      try {
        final parsed = DateTime.parse(rawDate.toString());
        dateStr = "${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-${parsed.day.toString().padLeft(2, '0')} ${parsed.hour.toString().padLeft(2, '0')}:${parsed.minute.toString().padLeft(2, '0')}";
      } catch (_) {
        dateStr = rawDate.toString();
      }
    }

    final isPro = type == 'PROFESSIONAL';
    final typeDisplay = isPro ? 'Teacher' : 'Tutor';

    return InkWell(
      onTap: () => _showDetailDialog(app),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))),
        ),
        child: Row(
          children: [
            // Radio indicator
            Icon(
              Icons.radio_button_checked_rounded,
              size: 16,
              color: status == 'AWAITING_APPROVAL' ? const Color(0xFF28B79B) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 16),
            
            // Name and email
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  Text(
                    email,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ],
              ),
            ),
            
            // Specialization Type
            Expanded(
              flex: 2,
              child: Text(
                typeDisplay,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF334155),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            
            // Proof Document status badge
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFCBD5E1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.attachment_rounded, size: 14, color: Color(0xFF64748B)),
                        SizedBox(width: 4),
                        Text(
                          'Credentials Attached',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
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
            
            // Submission Date
            Expanded(
              flex: 2,
              child: Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                  fontFamily: 'Outfit',
                ),
              ),
            ),
            
            // Actions
            Expanded(
              flex: 2,
              child: status == 'AWAITING_APPROVAL'
                  ? SizedBox(
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: () => _showDetailDialog(app),
                        icon: const Icon(Icons.rate_review_outlined, size: 14),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28B79B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        label: const Text(
                          'Review Application',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                        ),
                      ),
                    )
                  : Row(
                      children: [
                        InkWell(
                          onTap: () => _showDetailDialog(app),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getStatusBgColor(status),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: _getStatusTextColor(status).withOpacity(0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _getStatusText(status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: _getStatusTextColor(status),
                                    fontFamily: 'Outfit',
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.visibility_outlined, size: 14, color: _getStatusTextColor(status)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProofImageCard(String label, String url) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF475569),
                fontFamily: 'Outfit',
              ),
            ),
          ),
          InkWell(
            onTap: () {
              showDialog(
                context: context,
                builder: (context) {
                  return Dialog(
                    backgroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 800, maxHeight: 700),
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit')),
                              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                url,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) => Center(
                                  child: SelectableText('Link: $url'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            child: SizedBox(
              height: 180,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: const Color(0xFFF1F5F9),
                  child: const Center(
                    child: Text(
                      'Load Error',
                      style: TextStyle(color: Color(0xFFEF4444), fontSize: 12),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'VERIFIED':
        return const Color(0xFFE6FDF9);
      case 'PENDING_VERIFICATION':
        return const Color(0xFFFEF3C7);
      case 'SUSPENDED':
        return const Color(0xFFFEE2E2);
      default:
        return const Color(0xFFF1F5F9);
    }
  }

  Color _getStatusTextColor(String status) {
    switch (status) {
      case 'VERIFIED':
        return const Color(0xFF14B8A6);
      case 'PENDING_VERIFICATION':
        return const Color(0xFFD97706);
      case 'SUSPENDED':
        return const Color(0xFFEF4444);
      default:
        return const Color(0xFF64748B);
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'VERIFIED':
        return 'Approved';
      case 'PENDING_VERIFICATION':
        return 'Revision Req';
      case 'SUSPENDED':
        return 'Suspended';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalItems = _applications.length;
    final totalPages = totalItems > 0 ? (totalItems / _pageSize).ceil() : 1;
    final safeCurrentPage = _currentPage.clamp(1, totalPages);
    final startIndex = totalItems > 0 ? (safeCurrentPage - 1) * _pageSize : 0;
    final endIndex = math.min(startIndex + _pageSize, totalItems);
    final pagedApplications = totalItems > 0 ? _applications.sublist(startIndex, endIndex) : [];

    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.all(28.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dashboard title header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Trainer Onboarding Approvals',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                      fontFamily: 'Outfit',
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Review credentials and approve teaching application profiles.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 32),

          // Filters row
          Row(
            children: [
              // Dropdown filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _statusFilter,
                    dropdownColor: Colors.white,
                    focusColor: Colors.white,
                    style: const TextStyle(color: Color(0xFF0F172A), fontFamily: 'Outfit', fontSize: 14),
                    icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF64748B)),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _statusFilter = val;
                        });
                        _fetchApplications();
                      }
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'ALL',
                        child: Text('All Applications'),
                      ),
                      DropdownMenuItem(
                        value: 'AWAITING_APPROVAL',
                        child: Text('Awaiting Review'),
                      ),
                      DropdownMenuItem(
                        value: 'VERIFIED',
                        child: Text('Approved Applications'),
                      ),
                      DropdownMenuItem(
                        value: 'REJECTED',
                        child: Text('Rejected Applications'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Search text query
              Expanded(
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                    _fetchApplications();
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'Search by trainer name or email...',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    fillColor: Colors.white,
                    filled: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main tabular list block
          _isLoading
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80.0),
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF28B79B))),
                )
              : _applications.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 80.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.folder_open_rounded, size: 48, color: Color(0xFF94A3B8)),
                            SizedBox(height: 16),
                            Text(
                              'No applications found',
                              style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500, fontFamily: 'Outfit'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Table Header Column
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: Row(
                              children: const [
                                SizedBox(width: 32),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Trainer Name',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Trainer Type',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Proof Document',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Submission Date',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Actions / Status',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF475569), fontFamily: 'Outfit'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          // Non-scrollable list items (scrolling is handled by parent dashboard viewport)
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: pagedApplications.length,
                            itemBuilder: (context, index) {
                              return _buildApplicationRow(pagedApplications[index]);
                            },
                          ),

                          // Pagination controls footer bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8FAFC),
                              border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Showing ${totalItems > 0 ? startIndex + 1 : 0} to $endIndex of $totalItems entries',
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), fontFamily: 'Outfit'),
                                ),
                                Row(
                                  children: [
                                    const Text('Rows per page: ', style: TextStyle(fontSize: 12, color: Color(0xFF64748B), fontFamily: 'Outfit')),
                                    DropdownButtonHideUnderline(
                                      child: DropdownButton<int>(
                                        value: _pageSize,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF0F172A), fontFamily: 'Outfit', fontWeight: FontWeight.bold),
                                        onChanged: (val) {
                                          if (val != null) {
                                            setState(() {
                                              _pageSize = val;
                                              _currentPage = 1;
                                            });
                                          }
                                        },
                                        items: const [10, 20, 50].map((size) {
                                          return DropdownMenuItem<int>(
                                            value: size,
                                            child: Text('$size'),
                                          );
                                        }).toList(),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    OutlinedButton(
                                      onPressed: safeCurrentPage > 1
                                          ? () => setState(() => _currentPage = safeCurrentPage - 1)
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: const Text('Previous', style: TextStyle(fontSize: 12, fontFamily: 'Outfit')),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Page $safeCurrentPage of $totalPages',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF334155), fontFamily: 'Outfit'),
                                    ),
                                    const SizedBox(width: 8),
                                    OutlinedButton(
                                      onPressed: safeCurrentPage < totalPages
                                          ? () => setState(() => _currentPage = safeCurrentPage + 1)
                                          : null,
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                      child: const Text('Next', style: TextStyle(fontSize: 12, fontFamily: 'Outfit')),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
        ],
      ),
    );
  }
}
