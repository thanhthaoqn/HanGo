import 'file_picker_helper.dart';

Future<PickedFile?> pickImageFile() async => throw UnsupportedError('Stub');

Future<PickedFile?> pickVideoFile() async => throw UnsupportedError('Stub');

Future<PickedFile?> pickPdfFile() async => throw UnsupportedError('Stub');

Future<PickedFile?> pickImageOrPdfFile() async => throw UnsupportedError('Stub');


void setupDragDrop(Function(double clientX, double clientY, PickedFile file) onFileDropped) {}
void cancelDragDrop() {}
