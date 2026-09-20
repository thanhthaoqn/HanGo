import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

String prepareContent(String raw) {
  if (raw.isEmpty) return raw;
  String text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  if (text.contains(r'\n') && !text.contains('\n')) {
    text = text.replaceAll(r'\n', '\n');
  }
  text = text.replaceAllMapped(
    RegExp(r'(^|\n)[\t ]*[•●⁃]\s*'),
    (m) => '${m.group(1)}- ',
  );
  return text;
}

bool isHtmlContent(String text) {
  final htmlRegex = RegExp(
    r'<(p|div|h[1-6]|ul|ol|li|table|thead|tbody|tr|td|th|br|span|section|article|header|footer|b|i|strong|em)\b[^>]*>',
    caseSensitive: false,
  );
  return htmlRegex.hasMatch(text);
}

void main() {
  group('Lesson Content Hybrid Rendering Tests', () {
    test('Detects HTML properly', () {
      expect(isHtmlContent('<p>Chào các bạn</p>'), isTrue);
      expect(isHtmlContent('<div>Hello <b>world</b></div>'), isTrue);
      expect(isHtmlContent('Line 1<br/>Line 2'), isTrue);
      expect(isHtmlContent('<ul><li>Item</li></ul>'), isTrue);
    });

    test('Non-HTML plain text and markdown are not classified as HTML', () {
      expect(isHtmlContent('# Tiêu đề bài học\n**In đậm**'), isFalse);
      expect(isHtmlContent('Chào các em học sinh.\nHôm nay học bài mới.'), isFalse);
      expect(isHtmlContent('Giá trị x < 5 và y > 3'), isFalse);
    });

    test('Normalizes Windows CRLF to LF', () {
      final input = "Dòng 1\r\nDòng 2\r\nDòng 3";
      final output = prepareContent(input);
      expect(output, equals("Dòng 1\nDòng 2\nDòng 3"));
    });

    test('Normalizes literal escaped newlines from Excel/JSON', () {
      final input = r'Dòng 1\nDòng 2\nDòng 3';
      final output = prepareContent(input);
      expect(output, equals("Dòng 1\nDòng 2\nDòng 3"));
    });

    test('Normalizes unicode bullets to standard markdown bullets', () {
      final input = "Các từ vựng:\n• 학교: trường học\n• 선생님: giáo viên";
      final output = prepareContent(input);
      expect(output, equals("Các từ vựng:\n- 학교: trường học\n- 선생님: giáo viên"));
    });

    test('Handles mixed bullets and plain text', () {
      final input = "• Điểm 1\n• Điểm 2\nĐoạn văn thường";
      final output = prepareContent(input);
      expect(output, equals("- Điểm 1\n- Điểm 2\nĐoạn văn thường"));
    });

    testWidgets('MarkdownBody renders plain text with softLineBreak without collapsing lines',
        (WidgetTester tester) async {
      final plainText = prepareContent("Chào các em!\nHôm nay học bài mới.\nChúc các em học tốt!");
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkdownBody(
              data: plainText,
              softLineBreak: true,
            ),
          ),
        ),
      );

      expect(find.textContaining('Chào các em!'), findsOneWidget);
      expect(find.textContaining('Hôm nay học bài mới.'), findsOneWidget);
      expect(find.textContaining('Chúc các em học tốt!'), findsOneWidget);
    });
  });
}

