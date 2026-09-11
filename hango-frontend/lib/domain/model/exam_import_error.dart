class ExamImportError {
  final String? sheet;
  final int? row;
  final String? field;
  final String? errorType;
  final String? value;
  final String message;

  const ExamImportError({
    this.sheet,
    this.row,
    this.field,
    this.errorType,
    this.value,
    required this.message,
  });

  factory ExamImportError.fromJson(Map<String, dynamic> json) {
    return ExamImportError(
      sheet: json['sheet'] as String?,
      row: json['row'] as int?,
      field: json['field'] as String?,
      errorType: json['errorType'] as String?,
      value: json['value']?.toString(),
      message: json['message'] as String? ?? 'Unknown import error',
    );
  }
}
