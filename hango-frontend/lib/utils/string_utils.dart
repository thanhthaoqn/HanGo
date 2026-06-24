String formatDisplayName(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return 'Anonymous';

  if (trimmed.contains('@')) {
    final parts = trimmed.split('@');
    final local = parts[0];
    final domain = parts[1];

    if (local.length <= 2) {
      return "${local[0]}***@$domain";
    } else {
      final prefix = local.substring(0, 2);
      final suffix = local.substring(local.length - 1);
      final maskedLength = local.length - 3;
      final mask = '*' * (maskedLength > 0 ? maskedLength : 3);
      return "$prefix$mask$suffix@$domain";
    }
  }
  return trimmed;
}

String getInitial(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  
  // If it's a masked email (e.g. te***t@domain.com) or standard string, get first character
  return trimmed[0].toUpperCase();
}
