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

Future<PickedFile?> pickPdfFile() async {
  final completer = Completer<PickedFile?>();
  final uploadInput = html.InputElement()..type = 'file'..accept = 'application/pdf';
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

StreamSubscription? _dragOverSub;
StreamSubscription? _dropSub;

void setupDragDrop(Function(double clientX, double clientY, PickedFile file) onFileDropped) {
  _dragOverSub?.cancel();
  _dropSub?.cancel();

  _dragOverSub = html.window.onDragOver.listen((event) {
    event.preventDefault();
  });

  _dropSub = html.window.onDrop.listen((event) {
    event.preventDefault();
    final html.MouseEvent mouseEvent = event;
    final html.DataTransfer? dt = (event as dynamic).dataTransfer;
    if (dt != null && dt.files != null && dt.files!.isNotEmpty) {
      final file = dt.files![0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) {
        onFileDropped(
          mouseEvent.client.x.toDouble(),
          mouseEvent.client.y.toDouble(),
          PickedFile(
            name: file.name,
            bytes: reader.result as List<int>,
          ),
        );
      });
    }
  });
}

void cancelDragDrop() {
  _dragOverSub?.cancel();
  _dropSub?.cancel();
  _dragOverSub = null;
  _dropSub = null;
}
