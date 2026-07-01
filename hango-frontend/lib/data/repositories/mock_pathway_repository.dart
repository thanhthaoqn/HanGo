import '../../domain/entities/learning_pathway.dart';

class MockPathwayRepository {
  Future<LearningPathway> getMyPathway() async {
    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    final Map<String, dynamic> mockJson = {
      "roadmap_id": "RM_USER_99",
      "mentor_summary": "Chào bạn, qua bài thi vừa rồi, thầy nhận thấy bạn đang yếu phần 'Mệnh đề quan hệ' và 'Từ vựng chủ đề Giáo dục'. Thầy đã thiết kế riêng cho bạn lộ trình 4 bước dưới đây để củng cố lại kiến thức từ cơ bản đến nâng cao nhé.",
      "nodes": [
        {
          "step": 1,
          "course_id": "C_GR_01",
          "course_title": "Ôn tập Mệnh đề quan hệ (Cơ bản)",
          "tags": ["#Grammar", "#Foundation"],
          "status": "Completed",
          "reason_why": "Đây là kiến thức nền tảng bạn bị sai ở câu Q_102. Nắm vững phần này giúp bạn tự tin làm các câu hỏi ngữ pháp liên quan.",
          "progress_percent": 100
        },
        {
          "step": 2,
          "course_id": "C_GR_02",
          "course_title": "Bài tập áp dụng Mệnh đề quan hệ",
          "tags": ["#Practice", "#Grammar"],
          "status": "In_Progress",
          "reason_why": "Thực hành là cách tốt nhất để ghi nhớ kiến thức. Bài tập này sẽ giúp bạn luyện tập cấu trúc vừa học.",
          "progress_percent": 45
        },
        {
          "step": 3,
          "course_id": "C_VOB_01",
          "course_title": "Từ vựng: Education & Learning",
          "tags": ["#Vocabulary"],
          "status": "Locked",
          "reason_why": "Bạn đã làm sai câu Q_115 thuộc chủ đề Education. Khóa học này cung cấp các từ vựng cốt lõi thường gặp.",
          "progress_percent": 0
        },
        {
          "step": 4,
          "course_id": "C_RD_01",
          "course_title": "Đọc hiểu: Education in the Future",
          "tags": ["#Reading", "#Advanced"],
          "status": "Locked",
          "reason_why": "Bước cuối cùng là áp dụng từ vựng và ngữ pháp vào bài đọc hiểu thực tế để tăng cường kỹ năng Reading.",
          "progress_percent": 0
        }
      ]
    };

    return LearningPathway.fromJson(mockJson);
  }
}
