import 'package:flutter/material.dart';
import '../../../domain/model/exam_import_error.dart';

/// Popup listing every row/field-level error found while validating an
/// Excel exam import, so the user can fix all of them in one pass instead
/// of re-uploading once per error.
class ExamImportErrorDialog extends StatelessWidget {
  final List<ExamImportError> errors;

  const ExamImportErrorDialog({super.key, required this.errors});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline, color: Color(0xFFDC2626)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Import failed: ${errors.length} error${errors.length == 1 ? '' : 's'} found',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Outfit',
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Please fix the following issues in your Excel file and re-upload.',
                style: TextStyle(
                  fontSize: 14,
                  fontFamily: 'Outfit',
                  color: Color(0xFF475569),
                ),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          const Color(0xFFF8FAFC),
                        ),
                        columns: const [
                          DataColumn(label: Text('Sheet')),
                          DataColumn(label: Text('Row')),
                          DataColumn(label: Text('Field')),
                          DataColumn(label: Text('Error')),
                        ],
                        rows: errors
                            .map(
                              (e) => DataRow(
                                cells: [
                                  DataCell(Text(e.sheet ?? '-')),
                                  DataCell(Text(e.row?.toString() ?? '-')),
                                  DataCell(Text(e.field ?? '-')),
                                  DataCell(
                                    ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 320,
                                      ),
                                      child: Text(
                                        e.message,
                                        style: const TextStyle(
                                          color: Color(0xFF1E293B),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF20B486),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
