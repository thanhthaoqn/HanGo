import 'package:flutter_test/flutter_test.dart';
import 'package:hango/utils/trainer_document_utils.dart';

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
            return certificates.any((c) {
              final name = (c['name'] ?? '').toLowerCase();
              return name.contains('pedagog') ||
                  name.contains('su pham') ||
                  name.contains('supham') ||
                  name.contains('bachelor') ||
                  name.contains('teaching');
            });
          }
          return certificates.isNotEmpty;
        }

        final teacherWithDegree = [
          {
            'name': 'Bachelor of English Pedagogy',
            'url': 'https://cloudinary.com/degree.pdf',
          },
        ];
        final teacherWithoutDegree = [
          {
            'name': 'High School Transcript',
            'url': 'https://cloudinary.com/transcript.pdf',
          },
        ];
        final tutorWithCertificate = [
          {
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

    test('Bio experience minimum length validation', () {
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

    test('Normalizes trainer documents into stable document types', () {
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

      expect(documents[0]['type'], trainerDocTypeCv);
      expect(documents[1]['type'], trainerDocTypeLanguageProficiency);
      expect(documents[2]['type'], trainerDocTypePedagogicalDegree);
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

    test(
      'Infers degree and IELTS types from strong institution and document clues',
      () {
        expect(
          inferTrainerDocumentType(
            name:
                'Vietnam National University Hanoi College of Foreign Languages diploma',
          ),
          trainerDocTypePedagogicalDegree,
        );

        expect(
          inferTrainerDocumentType(
            name: 'British Council IELTS Test Report Form',
          ),
          trainerDocTypeLanguageProficiency,
        );
      },
    );

    test('Prefers TEFL evidence over a wrong AI degree guess', () {
      expect(
        inferTrainerDocumentType(
          explicitType: trainerDocTypePedagogicalDegree,
          name: 'Bachelor of English Pedagogy Degree',
          ocrText: 'TEFL International TESOL Certification',
          evidenceText:
              'TEFL International TESOL Certification Lead Trainer Course Director',
          issuingInstitution: 'Harvard University',
          isPedagogical: true,
        ),
        trainerDocTypeTeachingCertificate,
      );
    });

    test('Requires manual selection when the suggestion is too weak', () {
      final suggestion = suggestTrainerDocumentType(
        explicitType: trainerDocTypeOther,
        name: 'Other Credential Proof',
      );

      expect(suggestion.type, trainerDocTypeOther);
      expect(suggestion.requiresManualSelection, isTrue);
      expect(suggestion.isConfident, isFalse);
    });

    test('Does not require manual selection for strong TEFL evidence', () {
      final suggestion = suggestTrainerDocumentType(
        name: 'TEFL International TESOL Certification',
        ocrText: 'TESL TESOL TEFL',
        evidenceText: 'TEFL International TESOL Certification',
      );

      expect(suggestion.type, trainerDocTypeTeachingCertificate);
      expect(suggestion.requiresManualSelection, isFalse);
      expect(suggestion.isConfident, isTrue);
    });
  });
}
