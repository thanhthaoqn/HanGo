@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hango/presentation/pages/login_page.dart';
import 'package:hango/presentation/pages/trainer/onboarding/trainer_onboarding_agreement_page.dart';
import 'package:hango/presentation/pages/trainer/onboarding/trainer_onboarding_details_page.dart';
import 'package:hango/presentation/pages/trainer/onboarding/trainer_onboarding_status_page.dart';
import 'package:hango/presentation/pages/trainer/onboarding/trainer_payout_details_page.dart';
import 'package:hango/presentation/pages/trainer/trainer_profile_page.dart';

void main() {
  testWidgets('Payout form separates Tax ID and Citizen ID on mobile', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TrainerPayoutDetailsPage(
            initialProfile: <String, dynamic>{},
            isEmbedded: true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Personal Tax ID (optional)'), findsOneWidget);
    expect(find.text('Citizen ID Number *'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
