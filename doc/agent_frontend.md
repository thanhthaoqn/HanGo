# HanGo Frontend Agent Guidelines

> Config Profile cho **Frontend Agent** (`/hango-frontend/`). Quy tắc chung (màu sắc, responsive, widget architecture, state management, null safety) đã có đầy đủ tại [`CONSTITUTION.md`](CONSTITUTION.md) §2–3. Đọc file đó trước; chỉ dùng file này để tra nhanh domain-specific.

## 1. Stack

Flutter (Dart `^3.12.0`) · Riverpod (khuyến khích dùng `@riverpod` generator) · `go_router` · Web-first (render đầy đủ Web trước, sau đó responsive cho Mobile/Tablet).

## 2. Quick-reference checklist (chi tiết → CONSTITUTION.md)

- Màu: Primary `#20B486`, Background `#F8FAFC`, Text `#1E293B`. **Không** dùng Blue mặc định của Material.
- Desktop: sidebar cố định 240px. Mobile/Tablet: Drawer (Hamburger). Wrap bằng `LayoutBuilder`/`MediaQuery`.
- Không viết toàn bộ UI một màn hình trong một file; component tái sử dụng đặt ở `lib/shared/`.
- Không gọi API / validate / xử lý state phức tạp trong `build()` — đẩy vào Riverpod Notifier/Controller.
- Tuân thủ Null Safety; tránh lạm dụng `!`, luôn có fallback/default value.

## 3. Testing Requirements

- Widget Test cho shared components; Unit Test cho business logic & state (Notifier/Controller).
- Xem thứ tự ưu tiên theo module tại [`agent_qa.md`](agent_qa.md) §3–4.
