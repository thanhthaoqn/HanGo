// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

final Set<String> _registeredPdfViews = <String>{};

Widget buildPdfView({required String url, required String title}) {
  final cleanUrl = url.trim();
  final viewType = 'hango-pdf-${cleanUrl.hashCode.abs()}';

  if (!_registeredPdfViews.contains(viewType)) {
    _registeredPdfViews.add(viewType);
    ui_web.platformViewRegistry.registerViewFactory(
      viewType,
      (int viewId) {
        final iframe = html.IFrameElement()
          ..src = cleanUrl
          ..style.border = 'none'
          ..style.width = '100%'
          ..style.height = '100%'
          ..setAttribute('type', 'application/pdf');
        return iframe;
      },
    );
  }

  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: HtmlElementView(viewType: viewType),
  );
}
