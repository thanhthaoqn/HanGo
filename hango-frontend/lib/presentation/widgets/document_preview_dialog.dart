import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../utils/language_manager.dart';
import 'pdf_view_helper.dart';

bool isTrustedTrainerDocumentUrl(String value) {
  final uri = Uri.tryParse(value.trim());
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.toLowerCase() == 'res.cloudinary.com';
}

void showDocumentPreviewDialog(BuildContext context, String title, String url) {
  final isVi = LanguageManager.isVi;
  final cleanUrl = url.trim();
  if (!isTrustedTrainerDocumentUrl(cleanUrl)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isVi
              ? 'Liên kết tài liệu không hợp lệ.'
              : 'The document link is not trusted.',
        ),
      ),
    );
    return;
  }
  final isPdf =
      cleanUrl.toLowerCase().endsWith('.pdf') ||
      cleanUrl.toLowerCase().contains('.pdf?') ||
      cleanUrl.toLowerCase().contains('/pdf/');

  showDialog(
    context: context,
    builder: (context) {
      return Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 850, maxHeight: 700),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title.isNotEmpty
                          ? title
                          : (isPdf ? 'PDF Document' : 'Document Preview'),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        fontFamily: 'Outfit',
                        color: Color(0xFF0F172A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Body content: PDF vs Image
              Expanded(
                child: isPdf
                    ? buildPdfViewWidget(
                        url: cleanUrl,
                        title: title.isNotEmpty ? title : 'PDF Document',
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          cleanUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                color: const Color(0xFFF8FAFC),
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.broken_image_rounded,
                                      size: 48,
                                      color: Color(0xFF94A3B8),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      isVi
                                          ? 'Không thể tải ảnh xem trước.'
                                          : 'Failed to load image preview.',
                                      style: const TextStyle(
                                        color: Color(0xFF64748B),
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ElevatedButton.icon(
                                      onPressed: () async {
                                        final uri = Uri.parse(cleanUrl);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(
                                            uri,
                                            mode:
                                                LaunchMode.externalApplication,
                                          );
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.open_in_new_rounded,
                                        size: 16,
                                      ),
                                      label: Text(
                                        isVi
                                            ? 'Mở liên kết trực tiếp'
                                            : 'Open Direct Link',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF28B79B,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
