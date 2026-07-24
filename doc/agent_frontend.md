# HanGo Frontend Agent Guidelines

> Config Profile cho **Frontend Agent** (`/hango-frontend/`). Quy tắc chung (màu sắc, responsive, widget architecture, state management, null safety) đã có đầy đủ tại [`CONSTITUTION.md`](CONSTITUTION.md) §2–3. Đọc file đó trước; chỉ dùng file này để tra nhanh domain-specific.

## 1. Stack

Flutter (Dart `^3.12.0`) · Web-first (render đầy đủ Web trước, sau đó responsive cho Mobile/Tablet).

*(Cập nhật 2026-07-24 để khớp code thật: dự án hiện **không** dùng Riverpod hay `go_router` — cả hai đều không phải dependency trong `pubspec.yaml` và không xuất hiện trong code. State management thật: 1 `ChangeNotifierProvider<AppState>` (package `provider`) ở gốc app + `StatefulWidget`/`setState()` ở từng trang. Routing thật: `Navigator.push`/`MaterialPageRoute` thủ công, không có route table tập trung. Xem `AUDIT_REPORT.md` HIGH-06/HIGH-07 và `ROADMAP.md` nếu cân nhắc adopt Riverpod/go_router cho version sau.)*

## 2. Quick-reference checklist (chi tiết → CONSTITUTION.md)

- Màu: Primary `#20B486`, Background `#F8FAFC`, Text `#1E293B`. **Không** dùng Blue mặc định của Material.
- Desktop: sidebar cố định 240px. Mobile/Tablet: Drawer (Hamburger). Wrap bằng `LayoutBuilder`/`MediaQuery`.
- Không viết toàn bộ UI một màn hình trong một file — **lưu ý:** một số trang hiện tại đã phình rất lớn (`admin_dashboard_page.dart` ~5648 dòng, `learner_home_page.dart` ~3071 dòng); tránh thêm code mới vào các file này, ưu tiên tách widget con khi sửa.
- Không gọi API / validate / xử lý state phức tạp trong `build()`. Với code hiện tại: giữ logic trong các hàm `_fetchX()`/`_handleX()` của `State` class và gọi qua `setState()`, theo đúng pattern đang dùng trong toàn bộ `presentation/pages/` — không tự ý đổi một trang riêng lẻ sang Riverpod.
- Tuân thủ Null Safety; tránh lạm dụng `!`, luôn có fallback/default value.
- Gọi API qua `package:http` theo pattern hiện có trong `data/repositories/`/`data/services/` (không dùng `dio` dù có trong `pubspec.yaml` — dependency này hiện chưa dùng ở đâu).

## 3. Testing Requirements

- Widget Test cho shared components; Unit Test cho model/business logic thuần (không có Notifier/Controller pattern trong code hiện tại — chỉ có `StatefulWidget` state nội bộ).
- **Trạng thái thật:** chỉ 2 file test tồn tại (1 model test, 1 widget test) — gần như toàn bộ 67 trang chưa có test nào. Xem `AUDIT_REPORT.md` HIGH-08 và `TEST_AUDIT_REPORT.md` để biết ưu tiên đề xuất.
- Xem thứ tự ưu tiên theo module tại [`agent_qa.md`](agent_qa.md) §3–4.
