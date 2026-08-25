const trainerAgreementVersion = 'v1.0-2026-08-14';

enum TrainerOnboardingStage {
  typeSelection,
  agreement,
  details,
  status,
  payout,
  complete,
}

TrainerOnboardingStage resolveTrainerOnboardingStage(
  Map<String, dynamic> profile,
) {
  final status = (profile['status'] ?? 'PENDING_VERIFICATION')
      .toString()
      .toUpperCase();
  final trainerType = profile['trainerType']?.toString().trim();
  final agreementAccepted =
      profile['agreementSigned'] == true &&
      profile['agreementVersion'] == trainerAgreementVersion;
  final bankAccount = (profile['bankAccount'] ?? '').toString().trim();
  final adminNotes = (profile['adminNotes'] ?? '').toString().trim();
  final hasEditsRequested =
      status == 'PENDING_VERIFICATION' && adminNotes.isNotEmpty;

  if (status == 'VERIFIED') {
    if (!agreementAccepted) {
      return TrainerOnboardingStage.agreement;
    }
    if (bankAccount.isEmpty) {
      return TrainerOnboardingStage.payout;
    }
    return TrainerOnboardingStage.complete;
  }

  if (status == 'AWAITING_APPROVAL' ||
      status == 'PENDING_REVIEW' ||
      status == 'SUSPENDED' ||
      hasEditsRequested) {
    return TrainerOnboardingStage.status;
  }

  if (trainerType == null || trainerType.isEmpty) {
    return TrainerOnboardingStage.typeSelection;
  }

  if (!agreementAccepted) {
    return TrainerOnboardingStage.agreement;
  }

  return TrainerOnboardingStage.details;
}
