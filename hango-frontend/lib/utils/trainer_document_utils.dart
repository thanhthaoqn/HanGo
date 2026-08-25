import 'dart:convert';

const String trainerDocTypePedagogicalDegree = 'PEDAGOGICAL_DEGREE';
const String trainerDocTypeTeachingCertificate = 'TEACHING_CERTIFICATE';
const String trainerDocTypeLanguageProficiency = 'LANGUAGE_PROFICIENCY';
const String trainerDocTypeAcademicTranscript = 'ACADEMIC_TRANSCRIPT';
const String trainerDocTypeCv = 'TEACHING_CV';
const String trainerDocTypeOther = 'OTHER';

const Set<String> trainerPedagogicalDocumentTypes = {
  trainerDocTypePedagogicalDegree,
  trainerDocTypeTeachingCertificate,
};

const Set<String> _knownTrainerDocumentTypes = {
  trainerDocTypePedagogicalDegree,
  trainerDocTypeTeachingCertificate,
  trainerDocTypeLanguageProficiency,
  trainerDocTypeAcademicTranscript,
  trainerDocTypeCv,
  trainerDocTypeOther,
};

String canonicalTrainerDocumentTitle(String? type, {String? fallbackTitle}) {
  switch ((type ?? '').trim().toUpperCase()) {
    case trainerDocTypePedagogicalDegree:
      return 'Bachelor of English Pedagogy Degree';
    case trainerDocTypeTeachingCertificate:
      return 'TEFL / TESOL Teaching Certificate';
    case trainerDocTypeLanguageProficiency:
      return 'IELTS / Proficiency Certificate';
    case trainerDocTypeAcademicTranscript:
      return 'High School Academic Records';
    case trainerDocTypeCv:
      return 'Professional Teaching CV / Resume';
    default:
      return (fallbackTitle != null && fallbackTitle.trim().isNotEmpty)
          ? fallbackTitle.trim()
          : 'Other Credential Proof';
  }
}

bool isPedagogicalTrainerDocument(String? type) {
  return trainerPedagogicalDocumentTypes.contains(
    (type ?? '').trim().toUpperCase(),
  );
}

Map<String, String> normalizeTrainerDocument(
  Map<dynamic, dynamic> rawDocument,
) {
  final url = rawDocument['url']?.toString().trim() ?? '';
  final name = rawDocument['name']?.toString().trim() ?? '';
  final explicitType = rawDocument['type']?.toString().trim().toUpperCase();
  final type =
      explicitType != null && _knownTrainerDocumentTypes.contains(explicitType)
      ? explicitType
      : trainerDocTypeOther;

  final normalized = <String, String>{
    'type': type,
    'name': name.isNotEmpty ? name : canonicalTrainerDocumentTitle(type),
    'url': url,
  };

  for (final key in const ['issuingInstitution', 'holderName', 'source']) {
    final value = rawDocument[key]?.toString().trim();
    if (value != null && value.isNotEmpty) {
      normalized[key] = value;
    }
  }

  return normalized;
}

List<Map<String, String>> normalizeTrainerDocuments(
  List<dynamic> rawDocuments,
) {
  final normalized = <Map<String, String>>[];
  final seenUrls = <String>{};

  for (final item in rawDocuments) {
    if (item is! Map) continue;
    final document = normalizeTrainerDocument(item);
    final url = document['url'] ?? '';
    if (url.isEmpty || seenUrls.contains(url)) continue;
    seenUrls.add(url);
    normalized.add(document);
  }

  return normalized;
}

List<Map<String, String>> decodeTrainerDocuments({
  dynamic certificates,
  dynamic scoreReportUrl,
  dynamic pedagogicalDegreeUrl,
  dynamic cvUrl,
  dynamic degreeUrl,
  dynamic ieltsUrl,
}) {
  final rawDocuments = <Map<dynamic, dynamic>>[];

  if (certificates is List && certificates.isNotEmpty) {
    for (final item in certificates) {
      if (item is Map) {
        rawDocuments.add(item);
      }
    }
  } else {
    final rawScore = scoreReportUrl?.toString().trim() ?? '';
    if (rawScore.isNotEmpty) {
      if (rawScore.startsWith('[')) {
        try {
          final parsed = jsonDecode(rawScore);
          if (parsed is List) {
            for (final item in parsed) {
              if (item is Map) {
                rawDocuments.add(item);
              }
            }
          }
        } catch (_) {
          rawDocuments.add({
            'type': trainerDocTypeOther,
            'name': 'Score Report / Other Credential',
            'url': rawScore,
          });
        }
      } else {
        rawDocuments.add({
          'type': trainerDocTypeOther,
          'name': canonicalTrainerDocumentTitle(
            trainerDocTypeOther,
            fallbackTitle: 'Score Report / Other Credential',
          ),
          'url': rawScore,
        });
      }
    }

    final pedagogicalUrl = pedagogicalDegreeUrl?.toString().trim() ?? '';
    if (pedagogicalUrl.isNotEmpty) {
      rawDocuments.add({
        'type': trainerDocTypePedagogicalDegree,
        'name': canonicalTrainerDocumentTitle(trainerDocTypePedagogicalDegree),
        'url': pedagogicalUrl,
      });
    }

    final legacyDegree = degreeUrl?.toString().trim() ?? '';
    if (legacyDegree.isNotEmpty) {
      rawDocuments.add({
        'type': trainerDocTypePedagogicalDegree,
        'name': canonicalTrainerDocumentTitle(trainerDocTypePedagogicalDegree),
        'url': legacyDegree,
      });
    }

    final legacyIelts = ieltsUrl?.toString().trim() ?? '';
    if (legacyIelts.isNotEmpty) {
      rawDocuments.add({
        'type': trainerDocTypeLanguageProficiency,
        'name': canonicalTrainerDocumentTitle(
          trainerDocTypeLanguageProficiency,
        ),
        'url': legacyIelts,
      });
    }

    final cvDocumentUrl = cvUrl?.toString().trim() ?? '';
    if (cvDocumentUrl.isNotEmpty) {
      rawDocuments.add({
        'type': trainerDocTypeCv,
        'name': canonicalTrainerDocumentTitle(trainerDocTypeCv),
        'url': cvDocumentUrl,
      });
    }
  }

  return normalizeTrainerDocuments(rawDocuments);
}

Map<String, dynamic> buildTrainerDocumentPayload(
  List<Map<String, String>> documents,
) {
  final normalized = normalizeTrainerDocuments(documents);
  final pedagogicalUrl = normalized
      .where(
        (document) =>
            document['type'] == trainerDocTypePedagogicalDegree ||
            document['type'] == trainerDocTypeTeachingCertificate,
      )
      .map((document) => document['url'] ?? '')
      .firstWhere((url) => url.isNotEmpty, orElse: () => '');
  final cvDocumentUrl = normalized
      .where((document) => document['type'] == trainerDocTypeCv)
      .map((document) => document['url'] ?? '')
      .firstWhere((url) => url.isNotEmpty, orElse: () => '');

  return {
    'certificates': normalized,
    'scoreReportUrl': normalized.isNotEmpty ? jsonEncode(normalized) : '',
    'pedagogicalDegreeUrl': pedagogicalUrl,
    'cvUrl': cvDocumentUrl,
  };
}
