import 'file_picker_stub.dart'
    if (dart.library.html) 'file_picker_web.dart' as impl;

class PickedFile {
  final String name;
  final List<int> bytes;
  PickedFile({required this.name, required this.bytes});
}

Future<PickedFile?> pickImage() async {
  return impl.pickImageFile();
}

Future<PickedFile?> pickPdf() async {
  return impl.pickPdfFile();
}
