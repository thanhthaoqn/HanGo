import 'package:flutter/material.dart';
import '../../../../data/services/trainer_onboarding_service.dart';
import '../../../../utils/toast_helper.dart';
import '../../../../utils/language_manager.dart';
import '../../../../utils/trainer_onboarding_payload_utils.dart';
import '../../../../utils/trainer_onboarding_stage.dart';
import 'trainer_onboarding_status_page.dart';
import 'trainer_onboarding_details_page.dart';
import 'trainer_payout_details_page.dart';
import 'trainer_onboarding_shell_page.dart';

class TrainerOnboardingAgreementPage extends StatefulWidget {
  final Map<String, dynamic> profilePayload;
  final String trainerType;
  final bool isEmbedded;

  const TrainerOnboardingAgreementPage({
    super.key,
    required this.profilePayload,
    required this.trainerType,
    this.isEmbedded = false,
  });

  @override
  State<TrainerOnboardingAgreementPage> createState() =>
      _TrainerOnboardingAgreementPageState();
}

class _TrainerOnboardingAgreementPageState
    extends State<TrainerOnboardingAgreementPage> {
  final _onboardingService = TrainerOnboardingService();
  bool _agreementSigned = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final alreadyAccepted =
        widget.profilePayload['agreementSigned'] == true &&
        widget.profilePayload['agreementVersion'] == trainerAgreementVersion;
    _agreementSigned = alreadyAccepted;
  }

  void _handleSubmit() async {
    if (!_agreementSigned || _isSubmitting) return;
    setState(() {
      _isSubmitting = true;
    });

    final result = await _onboardingService.saveProfileDraft(
      buildTrainerAgreementDraftPayload(),
    );

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
    });

    if (result['success'] == true) {
      final savedProfile = Map<String, dynamic>.from(
        result['data'] ?? widget.profilePayload,
      );
      final nextStage = resolveTrainerOnboardingStage(savedProfile);
      final Widget nextPage = switch (nextStage) {
        TrainerOnboardingStage.payout => TrainerPayoutDetailsPage(
          initialProfile: savedProfile,
          isEmbedded: true,
        ),
        TrainerOnboardingStage.complete ||
        TrainerOnboardingStage.status => TrainerOnboardingStatusPage(
          initialProfile: savedProfile,
          isEmbedded: true,
        ),
        _ => TrainerOnboardingDetailsPage(
          initialProfile: savedProfile,
          isEmbedded: true,
        ),
      };

      final shellState = TrainerOnboardingShellPage.of(context);
      if (shellState != null) {
        shellState.updateBody(nextPage);
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TrainerOnboardingShellPage(initialBody: nextPage),
          ),
        );
      }
    } else {
      ToastHelper.showError(context, result['message'] ?? 'Error proceeding.');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEmbedded) {
      return TrainerOnboardingShellPage(
        initialBody: TrainerOnboardingAgreementPage(
          profilePayload: widget.profilePayload,
          trainerType: widget.trainerType,
          isEmbedded: true,
        ),
      );
    }

    final isVi = LanguageManager.isVi;
    final isPro = widget.trainerType == 'PROFESSIONAL';
    final roleName = isPro ? 'Teacher' : 'Peer Tutor';
    final roleNameVi = isPro ? 'Giáo viên' : 'Gia sư';
    final agreementTitle = isVi
        ? 'Thỏa thuận Hợp tác $roleNameVi'
        : '$roleName Cooperation Agreement';

    final splitText = isVi
        ? (isPro
              ? '70% doanh thu dành cho Giáo viên (30% phí nền tảng HanGo)'
              : '60% doanh thu dành cho Gia sư (40% phí nền tảng HanGo)')
        : (isPro
              ? '70% revenue share for Teacher (30% HanGo platform fee)'
              : '60% revenue share for Tutor (40% HanGo platform fee)');

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                agreementTitle,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                isVi
                    ? 'Vui lòng xem lại các điều khoản trong thỏa thuận hợp tác về phân chia doanh thu, khóa học đầu tiên và bản quyền nội dung.'
                    : 'Please review the key terms of the cooperation agreement regarding revenue share, introductory courses, and content compliance.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                  fontFamily: 'Outfit',
                ),
              ),
              const SizedBox(height: 32),
              // Agreement Terms Box
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTermTitle(
                      isVi
                          ? 'ĐIỀU 1: TỶ LỆ PHÂN CHIA DOANH THU & QUYẾT TOÁN'
                          : 'ARTICLE 1: REVENUE SHARE & SETTLEMENT',
                    ),
                    _buildTermText(
                      isVi
                          ? 'Loại tài khoản lựa chọn: ${isPro ? "Giáo viên chính thức (tỷ lệ 70/30)" : "Gia sư / Sinh viên (tỷ lệ 60/40)"}.\n- Tỷ lệ phân chia doanh thu: $splitText.\n- Thu nhập được quyết toán định kỳ hàng tháng chuyển khoản trực tiếp vào tài khoản ngân hàng của bạn.'
                          : 'Based on selected profile: ${isPro ? "Professional Teacher (70/30 split)" : "Peer Tutor (60/40 split)"}.\n- Contracted Revenue Split Ratio: $splitText.\n- Payouts are processed monthly and wired directly to your registered bank account.',
                    ),
                    const SizedBox(height: 16),
                    _buildTermTitle(
                      isVi
                          ? 'ĐIỀU 2: CHÍNH SÁCH KHÓA HỌC ĐẦU TIÊN MIỄN PHÍ'
                          : 'ARTICLE 2: FIRST COURSE FREE POLICY',
                    ),
                    _buildTermText(
                      isVi
                          ? 'Để xây dựng uy tín giảng dạy ban đầu và đóng góp vào hệ sinh thái cộng đồng HanGo, tất cả $roleNameVi mới tham gia đồng ý phát hành khóa học đầu tiên của mình hoàn toàn miễn phí (0 VNĐ).'
                          : 'To establish initial teaching credentials and contribute to the HanGo community ecosystem, all newly onboarded ${roleName}s agree to publish their very first course for free (0 VND).',
                    ),
                    const SizedBox(height: 16),
                    _buildTermTitle(
                      isVi
                          ? 'ĐIỀU 3: BẢN QUYỀN NỘI DUNG & TUÂN THỦ'
                          : 'ARTICLE 3: CONTENT COPYRIGHTS & COMPLIANCE',
                    ),
                    _buildTermText(
                      isVi
                          ? '$roleNameVi đảm bảo quyền sở hữu gốc đối với giáo trình, đề thi và câu hỏi. Nghiêm cấm sao chép trái phép tài sản của bên thứ ba. $roleNameVi chịu hoàn toàn trách nhiệm pháp lý đối với bất kỳ vi phạm bản quyền nào.'
                          : '${roleName}s guarantee original ownership of syllabus, exams, and quizzes. No unlicensed duplication of third-party assets is permitted. The ${roleName.toLowerCase()} assumes full legal responsibility for any copyright violations.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _agreementSigned
                        ? const Color(0xFF28B79B)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _agreementSigned,
                  activeColor: const Color(0xFF28B79B),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          setState(() {
                            _agreementSigned = value ?? false;
                          });
                        },
                  title: Text(
                    isVi
                        ? 'Tôi đã đọc, hiểu và đồng ý với Thỏa thuận Hợp tác trên.'
                        : 'I have read, understood, and agree to the Cooperation Agreement above.',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                      fontFamily: 'Outfit',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Submit action
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed:
                        (_agreementSigned && !_isSubmitting)
                        ? _handleSubmit
                        : null,
                    icon: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: Text(
                      isVi ? 'Đồng ý và tiếp tục' : 'Accept and Continue',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF28B79B),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(
                        0xFF28B79B,
                      ).withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                      elevation: 4,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTermTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Color(0xFF0F172A),
          fontFamily: 'Outfit',
        ),
      ),
    );
  }

  Widget _buildTermText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF475569),
          height: 1.6,
          fontFamily: 'Outfit',
        ),
      ),
    );
  }
}
