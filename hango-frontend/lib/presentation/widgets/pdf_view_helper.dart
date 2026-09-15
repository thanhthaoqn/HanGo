import 'package:flutter/material.dart';
import 'pdf_view_stub.dart'
    if (dart.library.html) 'pdf_view_web.dart' as impl;

Widget buildPdfViewWidget({required String url, required String title}) {
  return impl.buildPdfView(url: url, title: title);
}
