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
  trainerDocTypeCv,
};

const Set<String> _knownTrainerDocumentTypes = {
  trainerDocTypePedagogicalDegree,
  trainerDocTypeTeachingCertificate,
  trainerDocTypeLanguageProficiency,
  trainerDocTypeAcademicTranscript,
  trainerDocTypeCv,
  trainerDocTypeOther,
};

class TrainerDocumentTypeSuggestion {
  const TrainerDocumentTypeSuggestion({
    required this.type,
    required this.score,
    required this.runnerUpScore,
    required this.requiresManualSelection,
  });

  final String type;
  final int score;
  final int runnerUpScore;
  final bool requiresManualSelection;

  bool get isConfident => !requiresManualSelection;
}

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

TrainerDocumentTypeSuggestion suggestTrainerDocumentType({
  String? explicitType,
  String? name,
  String? url,
  String? ocrText,
  String? evidenceText,
  String? issuingInstitution,
  bool? isPedagogical,
}) {
  final normalizedType = explicitType?.trim().toUpperCase();
  final scores = <String, int>{
    trainerDocTypePedagogicalDegree: 0,
    trainerDocTypeTeachingCertificate: 0,
    trainerDocTypeLanguageProficiency: 0,
    trainerDocTypeAcademicTranscript: 0,
    trainerDocTypeCv: 0,
    trainerDocTypeOther: 0,
  };

  if (normalizedType != null &&
      _knownTrainerDocumentTypes.contains(normalizedType)) {
    _addTrainerDocumentScore(scores, normalizedType, 2);
  }

  _scoreTrainerDocumentText(scores, name, multiplier: 2);
  _scoreTrainerDocumentText(scores, url, multiplier: 1);
  _scoreTrainerDocumentText(scores, ocrText, multiplier: 3);
  _scoreTrainerDocumentText(scores, evidenceText, multiplier: 4);
  _scoreTrainerDocumentText(scores, issuingInstitution, multiplier: 1);

  if (isPedagogical == true) {
    _addTrainerDocumentScore(scores, trainerDocTypeTeachingCertificate, 2);
    _addTrainerDocumentScore(scores, trainerDocTypePedagogicalDegree, 1);
    _addTrainerDocumentScore(scores, trainerDocTypeCv, 1);
  }

  final detectedType = _pickBestTrainerDocumentType(scores);
  final detectedScore = scores[detectedType] ?? 0;
  final runnerUpScore = _runnerUpTrainerDocumentScore(scores, detectedType);

  String resolvedType = trainerDocTypeOther;
  int resolvedScore = 0;
  int resolvedRunnerUpScore = runnerUpScore;
  var explicitOnly = false;

  if (normalizedType != null &&
      _knownTrainerDocumentTypes.contains(normalizedType) &&
      detectedScore <= 2) {
    resolvedType = normalizedType;
    resolvedScore = scores[normalizedType] ?? 0;
    explicitOnly = true;
  } else if (detectedScore > 0) {
    resolvedType = detectedType;
    resolvedScore = detectedScore;
  } else if (normalizedType != null &&
      _knownTrainerDocumentTypes.contains(normalizedType)) {
    resolvedType = normalizedType;
    resolvedScore = scores[normalizedType] ?? 0;
    explicitOnly = true;
  } else if (isPedagogical == true) {
    resolvedType = trainerDocTypeTeachingCertificate;
    resolvedScore = scores[trainerDocTypeTeachingCertificate] ?? 0;
  }

  return TrainerDocumentTypeSuggestion(
    type: resolvedType,
    score: resolvedScore,
    runnerUpScore: resolvedRunnerUpScore,
    requiresManualSelection: _requiresManualTrainerDocumentSelection(
      resolvedType: resolvedType,
      score: resolvedScore,
      runnerUpScore: resolvedRunnerUpScore,
      explicitOnly: explicitOnly,
    ),
  );
}

String inferTrainerDocumentType({
  String? explicitType,
  String? name,
  String? url,
  String? ocrText,
  String? evidenceText,
  String? issuingInstitution,
  bool? isPedagogical,
}) {
  return suggestTrainerDocumentType(
    explicitType: explicitType,
    name: name,
    url: url,
    ocrText: ocrText,
    evidenceText: evidenceText,
    issuingInstitution: issuingInstitution,
    isPedagogical: isPedagogical,
  ).type;
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
  final explicitType = rawDocument['type']?.toString().trim();
  final source = rawDocument['source']?.toString().trim();
  final type =
      _shouldPreserveManualTrainerDocumentType(
        explicitType: explicitType,
        source: source,
      )
      ? explicitType!.toUpperCase()
      : inferTrainerDocumentType(
          explicitType: explicitType,
          name: name,
          url: url,
          issuingInstitution: rawDocument['issuingInstitution']?.toString(),
          isPedagogical:
              rawDocument['isPedagogical']?.toString().toLowerCase() == 'true',
        );

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

bool _shouldPreserveManualTrainerDocumentType({
  String? explicitType,
  String? source,
}) {
  final normalizedType = explicitType?.trim().toUpperCase();
  final normalizedSource = source?.trim().toLowerCase();

  return normalizedType != null &&
      normalizedType != trainerDocTypeOther &&
      _knownTrainerDocumentTypes.contains(normalizedType) &&
      normalizedSource != null &&
      normalizedSource.endsWith('_manual');
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
        final inferredType = inferTrainerDocumentType(
          name: rawScore,
          url: rawScore,
        );
        rawDocuments.add({
          'type': inferredType,
          'name': canonicalTrainerDocumentTitle(
            inferredType,
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

void _scoreTrainerDocumentText(
  Map<String, int> scores,
  String? rawText, {
  int multiplier = 1,
}) {
  final normalizedText = _normalizeTrainerDocumentText(rawText);
  if (normalizedText.isEmpty) {
    return;
  }

  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypeTeachingCertificate,
    8 * multiplier,
    const [
      'tefl',
      'tesol',
      'celta',
      'teaching certificate',
      'teaching certification',
      'teacher licence',
      'teacher license',
    ],
  );
  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypeTeachingCertificate,
    4 * multiplier,
    const [
      'teaching english',
      'lead trainer',
      'course director',
      'teaching practice',
    ],
  );

  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypeLanguageProficiency,
    8 * multiplier,
    const [
      'ielts',
      'toeic',
      'toefl',
      'aptis',
      'vstep',
      'test report form',
      'international english language testing system',
    ],
  );
  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypeLanguageProficiency,
    5 * multiplier,
    const [
      'trf',
      'british council',
      'idp',
      'cambridge english',
      'cambridge assessment',
      'certificate of proficiency',
    ],
  );
  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypeLanguageProficiency,
    3 * multiplier,
    const ['cefr', 'language proficiency', 'proficiency', 'ngoai ngu'],
  );

  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypePedagogicalDegree,
    8 * multiplier,
    const [
      'the degree of bachelor',
      'degree of bachelor',
      'bachelor of',
      'bang cu nhan',
      'bang tot nghiep',
      'cu nhan',
      'tot nghiep',
      'graduation diploma',
    ],
  );
  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypePedagogicalDegree,
    4 * multiplier,
    const [
      'pedagogy',
      'pedagogical',
      'pedagog',
      'su pham',
      'qualification',
      'degree',
      'diploma',
      'english language teaching',
    ],
  );
  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypePedagogicalDegree,
    1 * multiplier,
    const [
      'university',
      'college of foreign languages',
      'college',
      'dai hoc',
      'faculty of education',
    ],
  );

  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypeAcademicTranscript,
    8 * multiplier,
    const [
      'hoc ba',
      'bang diem',
      'transcript',
      'academic records',
      'report card',
    ],
  );
  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypeAcademicTranscript,
    4 * multiplier,
    const ['hoc luc', 'grade table', 'school year', 'semester', 'grade point'],
  );

  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypeCv,
    8 * multiplier,
    const [
      'curriculum vitae',
      'resume',
      'teacher profile',
      'so yeu ly lich',
      ' cv ',
    ],
  );
  _addScoreIfMatches(
    scores,
    normalizedText,
    trainerDocTypeCv,
    4 * multiplier,
    const [
      'work experience',
      'employment history',
      'teaching experience',
      'career objective',
      'professional summary',
    ],
  );
}

void _addScoreIfMatches(
  Map<String, int> scores,
  String normalizedText,
  String type,
  int points,
  List<String> patterns,
) {
  for (final pattern in patterns) {
    if (_containsTrainerPattern(normalizedText, pattern)) {
      _addTrainerDocumentScore(scores, type, points);
    }
  }
}

void _addTrainerDocumentScore(
  Map<String, int> scores,
  String type,
  int points,
) {
  scores[type] = (scores[type] ?? 0) + points;
}

String _pickBestTrainerDocumentType(Map<String, int> scores) {
  const priority = <String>[
    trainerDocTypeLanguageProficiency,
    trainerDocTypeTeachingCertificate,
    trainerDocTypePedagogicalDegree,
    trainerDocTypeAcademicTranscript,
    trainerDocTypeCv,
    trainerDocTypeOther,
  ];

  var bestType = trainerDocTypeOther;
  var bestScore = -1;

  for (final type in priority) {
    final score = scores[type] ?? 0;
    if (score > bestScore) {
      bestType = type;
      bestScore = score;
    }
  }

  return bestType;
}

int _runnerUpTrainerDocumentScore(Map<String, int> scores, String bestType) {
  var runnerUpScore = 0;
  for (final entry in scores.entries) {
    if (entry.key == bestType) {
      continue;
    }
    if (entry.value > runnerUpScore) {
      runnerUpScore = entry.value;
    }
  }
  return runnerUpScore;
}

bool _requiresManualTrainerDocumentSelection({
  required String resolvedType,
  required int score,
  required int runnerUpScore,
  required bool explicitOnly,
}) {
  if (resolvedType == trainerDocTypeOther) {
    return true;
  }

  if (score <= 0) {
    return true;
  }

  if (explicitOnly) {
    return true;
  }

  if (score < 8) {
    return true;
  }

  if (score - runnerUpScore < 4) {
    return true;
  }

  return false;
}

bool _containsTrainerPattern(String normalizedText, String pattern) {
  return normalizedText.contains(_normalizeTrainerDocumentText(pattern));
}

String _normalizeTrainerDocumentText(String? rawText) {
  if (rawText == null || rawText.trim().isEmpty) {
    return '';
  }

  var normalized = rawText.toLowerCase();
  const replacements = <String, String>{
    r'[àáạảãâầấậẩẫăằắặẳẵ]': 'a',
    r'[èéẹẻẽêềếệểễ]': 'e',
    r'[ìíịỉĩ]': 'i',
    r'[òóọỏõôồốộổỗơờớợởỡ]': 'o',
    r'[ùúụủũưừứựửữ]': 'u',
    r'[ỳýỵỷỹ]': 'y',
    r'[đ]': 'd',
  };

  replacements.forEach((pattern, replacement) {
    normalized = normalized.replaceAll(RegExp(pattern), replacement);
  });

  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  if (normalized.isEmpty) {
    return '';
  }

  return ' $normalized ';
}
