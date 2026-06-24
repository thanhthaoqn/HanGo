// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'file_picker_helper.dart';

Future<PickedFile?> pickImageFile() async {
  final completer = Completer<PickedFile?>();
  final uploadInput = html.InputElement()..type = 'file'..accept = 'image/*';
  uploadInput.click();

  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) {
        completer.complete(PickedFile(
          name: file.name,
          bytes: reader.result as List<int>,
        ));
      });
    } else {
      completer.complete(null);
    }
  });

  return completer.future;
}
