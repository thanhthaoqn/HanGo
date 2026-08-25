import 'package:flutter_test/flutter_test.dart';
import 'package:hango/utils/trainer_document_utils.dart';
import 'package:hango/utils/trainer_onboarding_payload_utils.dart';
import 'package:hango/utils/trainer_onboarding_stage.dart';
import 'package:hango/utils/trainer_onboarding_validation_utils.dart';
import 'package:hango/utils/trainer_revision_notes.dart';

void main() {
  group('Trainer Onboarding Business Logic & Rules', () {
    test('Calculates fixed revenue share based on trainer type', () {
      double getRevenueShare(String trainerType) {
        return trainerType == 'PEER_TUTOR' ? 0.60 : 0.70;
      }

      expect(getRevenueShare('PROFESSIONAL'), 0.70);
      expect(getRevenueShare('PEER_TUTOR'), 0.60);
    });

    test(
      'Validates contact phone number rules (10 digits starting with 03/05/07/08/09)',
      () {
        bool isValidPhoneNumber(String? phone) {
          if (phone == null) return false;
          final trimmed = phone.trim();
          if (trimmed.isEmpty) return false;
          final vnPhoneRegex = RegExp(r'^(03|05|07|08|09)\d{8}$');
          final isDummyNumber =
              RegExp(r'^(\d)\1{9}$').hasMatch(trimmed) ||
              trimmed == '1234567890';
          return vnPhoneRegex.hasMatch(trimmed) && !isDummyNumber;
        }

        expect(isValidPhoneNumber('0912345678'), isTrue);
        expect(isValidPhoneNumber('0388889999'), isTrue);
        expect(isValidPhoneNumber('1234567890'), isFalse);
        expect(isValidPhoneNumber('0000000000'), isFalse);
        expect(isValidPhoneNumber('0123456789'), isFalse);
        expect(isValidPhoneNumber('091234567'), isFalse);
      },
    );

    test(
      'Enforces pedagogical degree requirement for Teacher applications',
      () {
        bool validateTeacherCredentials(
          String trainerType,
          List<Map<String, String>> certificates,
        ) {
          final isTeacher = trainerType == 'PROFESSIONAL';
          if (isTeacher) {
            return certificates.any(
              (certificate) =>
                  isPedagogicalTrainerDocument(certificate['type']),
            );
          }
          return certificates.isNotEmpty;
        }

        final teacherWithDegree = [
          {
            'type': trainerDocTypePedagogicalDegree,
            'name': 'Bachelor of English Pedagogy',
            'url': 'https://cloudinary.com/degree.pdf',
          },
        ];
        final teacherWithoutDegree = [
          {
            'type': trainerDocTypeCv,
            'name': 'Professional Teaching CV',
            'url': 'https://cloudinary.com/cv.pdf',
          },
          {
            'type': trainerDocTypeLanguageProficiency,
            'name': 'High School Transcript',
            'url': 'https://cloudinary.com/transcript.pdf',
          },
        ];
        final tutorWithCertificate = [
          {
            'type': trainerDocTypeLanguageProficiency,
            'name': 'IELTS 8.0 Certificate',
            'url': 'https://cloudinary.com/ielts.pdf',
          },
        ];

        expect(
          validateTeacherCredentials('PROFESSIONAL', teacherWithDegree),
          isTrue,
        );
        expect(
          validateTeacherCredentials('PROFESSIONAL', teacherWithoutDegree),
          isFalse,
        );
        expect(
          validateTeacherCredentials('PEER_TUTOR', tutorWithCertificate),
          isTrue,
        );
      },
    );

    test('Bio minimum length validation', () {
      bool isValidBio(String bio) {
        final trimmed = bio.trim();
        return trimmed.isNotEmpty && trimmed.length >= 50;
      }

      expect(isValidBio('Short bio'), isFalse);
      expect(
        isValidBio(
          'I have over 5 years of experience teaching English at high school and university levels.',
        ),
        isTrue,
      );
    });

    test('Routes a verified trainer without bank details to payout', () {
      final stage = resolveTrainerOnboardingStage({
        'status': 'VERIFIED',
        'trainerType': 'PROFESSIONAL',
        'agreementSigned': true,
        'agreementVersion': trainerAgreementVersion,
        'bankAccount': '',
      });

      expect(stage, TrainerOnboardingStage.payout);
    });

    test('Routes a verified trainer with payout details to trainer home', () {
      final stage = resolveTrainerOnboardingStage({
        'status': 'VERIFIED',
        'trainerType': 'PROFESSIONAL',
        'agreementSigned': true,
        'agreementVersion': trainerAgreementVersion,
        'bankAccount': '0123456789',
      });

      expect(stage, TrainerOnboardingStage.complete);
    });

    test('Requires a new agreement when the accepted version is legacy', () {
      final stage = resolveTrainerOnboardingStage({
        'status': 'VERIFIED',
        'trainerType': 'PROFESSIONAL',
        'agreementSigned': true,
        'agreementVersion': 'legacy-before-20260823',
        'bankAccount': '0123456789',
      });

      expect(stage, TrainerOnboardingStage.agreement);
    });

    test('Agreement save does not resend stale profile fields', () {
      final payload = buildTrainerAgreementDraftPayload();

      expect(payload, {'agreementSigned': true});
      expect(payload.containsKey('phoneNumber'), isFalse);
      expect(payload.containsKey('bankAccount'), isFalse);
      expect(payload.containsKey('certificates'), isFalse);
    });

    test('Explains gateway upload limit errors', () {
      expect(
        trainerUploadFailureMessage(
          statusCode: 413,
          fallbackMessage: 'Unable to upload the trainer document.',
        ),
        'The upload request is too large. Maximum file size is 5MB.',
      );
      expect(
        trainerUploadFailureMessage(
          statusCode: 500,
          fallbackMessage: 'Unable to upload the trainer document.',
        ),
        'Unable to upload the trainer document.',
      );
    });

    test('Keeps trainer revision feedback in its requested section only', () {
      final bioOnly = parseTrainerRevisionNotes('Bio: Add more details');
      expect(bioOnly.bio, 'Add more details');
      expect(bioOnly.certificates, isNull);
      expect(bioOnly.general, isNull);

      final certificatesOnly = parseTrainerRevisionNotes(
        'Certificates: Upload a clearer scan',
      );
      expect(certificatesOnly.bio, isNull);
      expect(certificatesOnly.certificates, 'Upload a clearer scan');
      expect(certificatesOnly.general, isNull);

      final both = parseTrainerRevisionNotes(
        'Bio: Add teaching details | Certificates: Upload a clearer scan',
      );
      expect(both.bio, 'Add teaching details');
      expect(both.certificates, 'Upload a clearer scan');
    });

    test('Treats legacy unlabelled revision feedback as one general note', () {
      final notes = parseTrainerRevisionNotes('Please update your profile');

      expect(notes.bio, isNull);
      expect(notes.certificates, isNull);
      expect(notes.general, 'Please update your profile');
    });

    test('Does not infer document types from uploaded file names', () {
      final documents = normalizeTrainerDocuments([
        {'name': 'Nguyen Van A CV.pdf', 'url': 'https://cloudinary.com/cv.pdf'},
        {
          'name': 'IELTS Academic Result',
          'url': 'https://cloudinary.com/ielts.pdf',
        },
        {
          'name': 'Bachelor of English Pedagogy Degree',
          'url': 'https://cloudinary.com/degree.pdf',
        },
      ]);

      expect(documents[0]['type'], trainerDocTypeOther);
      expect(documents[1]['type'], trainerDocTypeOther);
      expect(documents[2]['type'], trainerDocTypeOther);
    });

    test('Keeps manual document type selected by the user', () {
      final documents = normalizeTrainerDocuments([
        {
          'type': trainerDocTypeTeachingCertificate,
          'name': 'Bachelor of English Pedagogy Degree',
          'url': 'https://cloudinary.com/manual-degree.pdf',
          'source': 'trainer_profile_manual',
        },
      ]);

      expect(documents, hasLength(1));
      expect(documents.first['type'], trainerDocTypeTeachingCertificate);
      expect(documents.first['name'], 'Bachelor of English Pedagogy Degree');
    });

    test(
      'Builds trainer document payload without misusing the first uploaded file',
      () {
        final payload = buildTrainerDocumentPayload([
          {
            'type': trainerDocTypeCv,
            'name': 'Professional Teaching CV / Resume',
            'url': 'https://cloudinary.com/cv.pdf',
          },
          {
            'type': trainerDocTypePedagogicalDegree,
            'name': 'Bachelor of English Pedagogy Degree',
            'url': 'https://cloudinary.com/degree.pdf',
          },
        ]);

        expect(payload['cvUrl'], 'https://cloudinary.com/cv.pdf');
        expect(
          payload['pedagogicalDegreeUrl'],
          'https://cloudinary.com/degree.pdf',
        );
        expect((payload['scoreReportUrl'] as String).startsWith('['), isTrue);
      },
    );

    test('Validates Tax ID and Citizen ID as separate fields', () {
      bool isValidTaxCode(String taxCode) {
        final trimmed = taxCode.trim();
        return trimmed.isEmpty || RegExp(r'^\d{10}(\d{3})?$').hasMatch(trimmed);
      }

      bool isValidCitizenId(String citizenId) {
        return RegExp(r'^\d{12}$').hasMatch(citizenId.trim());
      }

      expect(isValidTaxCode(''), isTrue);
      expect(isValidTaxCode('0101234567'), isTrue);
      expect(isValidTaxCode('0101234567001'), isTrue);
      expect(isValidTaxCode('01012345671'), isFalse);
      expect(isValidCitizenId('001198001234'), isTrue);
      expect(isValidCitizenId('0101234567'), isFalse);
    });
  });
}
