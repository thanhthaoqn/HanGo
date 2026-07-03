/// 3 câu gợi ý fallback (tổng quát) để hiển thị khi chatbox rỗng
/// (chưa hỏi gì hoặc vừa xóa lịch sử).
/// Khi người học bấm gửi, backend sẽ sinh suggestedQuestions chuẩn theo ngữ cảnh bài học.
List<String> defaultLessonAiSuggestedQuestions() => const [
  'Nhìn tổng quan bài học này giúp mình được không?',
  'Trong bài này, phần nào là ý chính cần nhớ nhất?',
  'Cho mình một ví dụ minh họa hoặc tình huống áp dụng của bài học này.',
];
