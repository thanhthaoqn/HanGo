import 'download_stub.dart' if (dart.library.html) 'download_web.dart' as impl;

void downloadBytes({
  required List<int> bytes,
  required String filename,
  required String mimeType,
}) {
  impl.downloadBytes(bytes: bytes, filename: filename, mimeType: mimeType);
}
