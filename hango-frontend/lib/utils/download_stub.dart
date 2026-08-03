import 'dart:io';
import 'package:file_picker/file_picker.dart';

void downloadBytes({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) async {
  try {
    String? outputFile = await FilePicker.platform.saveFile(
      dialogTitle: 'Save template file',
      fileName: filename,
    );

    if (outputFile != null) {
      final file = File(outputFile);
      await file.writeAsBytes(bytes);
    }
  } catch (e) {
    print('Error saving file: $e');
  }
}
