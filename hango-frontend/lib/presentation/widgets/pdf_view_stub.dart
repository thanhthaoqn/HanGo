import 'package:flutter/material.dart';

Widget buildPdfView({required String url, required String title}) {
  return Container(
    width: double.infinity,
    height: double.infinity,
    color: const Color(0xFFF8FAFC),
    child: Center(
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.picture_as_pdf_rounded,
              size: 56,
              color: Color(0xFFDC2626),
            ),
            const SizedBox(height: 12),
            Text(
              title.isNotEmpty ? title : 'PDF Document',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Color(0xFF0F172A),
                fontFamily: 'Outfit',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
