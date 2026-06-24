import 'dart:async';
import 'dart:html' as html;
import 'dart:convert';
import 'dart:typed_data';

Future<Map<String, dynamic>?> pickImage() async {
  final completer = Completer<Map<String, dynamic>?>();
  final html.FileUploadInputElement input = html.FileUploadInputElement();
  input.accept = 'image/*';
  input.click();

  input.onChange.listen((e) {
    if (input.files!.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = input.files![0];
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    reader.onLoadEnd.listen((e) {
      final base64String = reader.result as String;
      // Also get bytes
      final bytesReader = html.FileReader();
      bytesReader.readAsArrayBuffer(file);
      bytesReader.onLoadEnd.listen((e) {
        final bytes = bytesReader.result as Uint8List;
        completer.complete({
          'base64': base64String,
          'bytes': bytes,
          'name': file.name,
        });
      });
    });
  });
  
  return completer.future;
}
