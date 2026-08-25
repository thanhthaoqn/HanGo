class TrainerRevisionNotes {
  const TrainerRevisionNotes({this.bio, this.certificates, this.general});

  final String? bio;
  final String? certificates;
  final String? general;

  bool get hasAny => bio != null || certificates != null || general != null;
}

TrainerRevisionNotes parseTrainerRevisionNotes(String? rawNotes) {
  final notes = rawNotes?.trim() ?? '';
  if (notes.isEmpty) {
    return const TrainerRevisionNotes();
  }

  final sectionPattern = RegExp(
    r'(?:^|\s*\|\s*)(Bio|Certificates):\s*(.*?)(?=\s*\|\s*(?:Bio|Certificates):|$)',
    caseSensitive: false,
    dotAll: true,
  );
  final matches = sectionPattern.allMatches(notes).toList();
  if (matches.isEmpty) {
    return TrainerRevisionNotes(general: notes);
  }

  String? bio;
  String? certificates;
  for (final match in matches) {
    final section = match.group(1)?.toLowerCase();
    final message = match.group(2)?.trim();
    if (message == null || message.isEmpty) {
      continue;
    }

    if (section == 'bio') {
      bio = message;
    } else if (section == 'certificates') {
      certificates = message;
    }
  }

  return TrainerRevisionNotes(bio: bio, certificates: certificates);
}
