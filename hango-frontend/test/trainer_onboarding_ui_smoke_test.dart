library;

import 'package:flutter_test/flutter_test.dart';
import 'package:hango/presentation/pages/login_page.dart';
import 'package:hango/presentation/pages/trainer/onboarding/trainer_onboarding_agreement_page.dart';
import 'package:hango/presentation/pages/trainer/onboarding/trainer_onboarding_details_page.dart';
import 'package:hango/presentation/pages/trainer/onboarding/trainer_onboarding_status_page.dart';
import 'package:hango/presentation/pages/trainer/trainer_profile_page.dart';

void main() {
  test('Trainer onboarding pages remain constructible', () {
    const profile = <String, dynamic>{};

    expect(LoginPage.new, isNotNull);
    expect(
      const TrainerOnboardingAgreementPage(
        profilePayload: profile,
        trainerType: 'PROFESSIONAL',
      ),
      isA<TrainerOnboardingAgreementPage>(),
    );
    expect(
      const TrainerOnboardingDetailsPage(initialProfile: profile),
      isA<TrainerOnboardingDetailsPage>(),
    );
    expect(
      const TrainerOnboardingStatusPage(initialProfile: profile),
      isA<TrainerOnboardingStatusPage>(),
    );
    expect(const TrainerProfilePage(), isA<TrainerProfilePage>());
  });
}
