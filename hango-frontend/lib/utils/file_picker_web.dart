// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'file_picker_helper.dart';

Future<PickedFile?> _pickFileFromInput(html.InputElement uploadInput) {
  final completer = Completer<PickedFile?>();

  StreamSubscription? focusSub;

  void completeSafely(PickedFile? file) {
    focusSub?.cancel();
    if (!completer.isCompleted) {
      completer.complete(file);
    }
  }

  // 1. Listen for HTML5 'cancel' event on input (triggered when user cancels file dialog)
  uploadInput.addEventListener('cancel', (event) {
    completeSafely(null);
  });

  // 2. Listen for window focus regaining (fallback for browsers/OS dialogs where cancel event doesn't fire)
  focusSub = html.window.onFocus.listen((_) {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!completer.isCompleted) {
        completeSafely(null);
      }
    });
  });

  // 3. Listen for file selection
  uploadInput.onChange.listen((e) {
    final files = uploadInput.files;
    if (files != null && files.isNotEmpty) {
      final file = files[0];
      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);
      reader.onLoadEnd.listen((e) {
        completeSafely(PickedFile(
          name: file.name,
          bytes: reader.result as List<int>,
        ));
      });
    } else {
      completeSafely(null);
    }
  });

  uploadInput.click();
  return completer.future;
}

Future<PickedFile?> pickImageFile() async {
  final uploadInput = html.InputElement()..type = 'file'..accept = 'image/*';
  return _pickFileFromInput(uploadInput);
}

Future<PickedFile?> pickVideoFile() async {
  final uploadInput = html.InputElement()..type = 'file'..accept = 'video/mp4,video/x-m4v,video/*';
  return _pickFileFromInput(uploadInput);
}

Future<PickedFile?> pickPdfFile() async {
  final uploadInput = html.InputElement()..type = 'file'..accept = 'application/pdf';
  return _pickFileFromInput(uploadInput);
}

Future<PickedFile?> pickImageOrPdfFile() async {
  final uploadInput = html.InputElement()
    ..type = 'file'
    ..accept = 'image/*,application/pdf,.pdf';
  return _pickFileFromInput(uploadInput);
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
