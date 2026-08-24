import 'package:flutter/material.dart';

import '../presentation/pages/trainer/onboarding/trainer_onboarding_agreement_page.dart';
import '../presentation/pages/trainer/onboarding/trainer_onboarding_details_page.dart';
import '../presentation/pages/trainer/onboarding/trainer_onboarding_status_page.dart';
import '../presentation/pages/trainer/onboarding/trainer_payout_details_page.dart';
import '../presentation/pages/trainer/onboarding/trainer_type_selection_page.dart';
import 'trainer_onboarding_stage.dart';

export 'trainer_onboarding_stage.dart';

Widget buildTrainerOnboardingStagePage(
  Map<String, dynamic> profile, {
  bool isEmbedded = false,
}) {
  final stage = resolveTrainerOnboardingStage(profile);
  final trainerType =
      (profile['trainerType'] ?? 'PROFESSIONAL').toString().trim().isEmpty
      ? 'PROFESSIONAL'
      : profile['trainerType'].toString();

  switch (stage) {
    case TrainerOnboardingStage.typeSelection:
      return TrainerTypeSelectionPage(isEmbedded: isEmbedded);
    case TrainerOnboardingStage.agreement:
      return TrainerOnboardingAgreementPage(
        profilePayload: profile,
        trainerType: trainerType,
        isEmbedded: isEmbedded,
      );
    case TrainerOnboardingStage.details:
      return TrainerOnboardingDetailsPage(
        initialProfile: profile,
        isEmbedded: isEmbedded,
      );
    case TrainerOnboardingStage.status:
      return TrainerOnboardingStatusPage(
        initialProfile: profile,
        isEmbedded: isEmbedded,
      );
    case TrainerOnboardingStage.payout:
      return TrainerPayoutDetailsPage(
        initialProfile: profile,
        isEmbedded: isEmbedded,
      );
    case TrainerOnboardingStage.complete:
      return TrainerOnboardingStatusPage(
        initialProfile: profile,
        isEmbedded: isEmbedded,
      );
  }
}
