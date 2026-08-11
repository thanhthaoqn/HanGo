# Feature Specification: FE-05 — Trainer Application Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.5 (TRN), §9.2 (state machine). Formerly `04-trainer-onboarding.md`; renamed/renumbered 2026-08-10 to match the current Feature Map naming.

> ⚠️ Trạng thái đơn thật trên `TrainerProfile.status` là `PENDING_VERIFICATION → AWAITING_APPROVAL → VERIFIED` (hoặc `SUSPENDED`) — **không phải** `Draft/Submitted/Approved/Rejected`. Vai trò **Trainer** (và quyền vào Trainer Dashboard tạo Course/Exam ở Draft) được cấp **ngay khi** chọn role lúc Register hoặc gọi `become-trainer` — **không** chờ Admin duyệt hồ sơ trước; Admin duyệt chỉ chặn ở bước publish/bán Course.

## 1. Business Context
Để trở thành Trainer trên HanGo, Learner/Guest nộp đơn gồm minh chứng chuyên môn, thông tin ngân hàng, và loại Trainer (Teacher/`PROFESSIONAL` hoặc Tutor/`PEER_TUTOR`). Administrator duyệt đơn để đảm bảo chất lượng giảng dạy.

## 2. Acceptance Criteria

**Frontend (Flutter, `presentation/pages/trainer/onboarding/`):**
- [ ] `trainer_type_selection_page.dart` — chọn loại Trainer.
- [ ] `trainer_onboarding_details_page.dart` — bio (≥50 ký tự), phone, minh chứng/CV upload, avatar/giới tính, autosave draft.
- [ ] `trainer_payout_details_page.dart` — bank name/account/account name/tax code.
- [ ] `trainer_onboarding_agreement_page.dart` — scroll-to-bottom-gated, checkbox ký thoả thuận.
- [ ] `trainer_onboarding_status_page.dart` — hiển thị trạng thái (`AWAITING_APPROVAL`/`SUSPENDED`/cần sửa lại) + ghi chú của Admin.
- [ ] Admin: `admin_trainer_reviews_page.dart` — hàng chờ duyệt (filter theo status), Approve/Reject kèm ghi chú + dialog chỉnh `revenueShare`.

**Backend (Spring Boot, `TrainerOnboardingController`, base `/api/v1`):**
- [ ] `POST /trainers/become-trainer` — gán role Trainer ngay, tạo `TrainerProfile{status=PENDING_VERIFICATION}`, `revenueShare` mặc định 0.70(`PROFESSIONAL`)/0.60(`PEER_TUTOR`).
- [ ] `GET /trainers/profile`, `PUT /trainers/profile` (lưu nháp — chặn nếu `AWAITING_APPROVAL`/`SUSPENDED`).
- [ ] `POST /trainers/profile/submit` — validate bio≥50 ký tự, phone regex `^(03|05|07|08|09)\d{8}$` (không số lặp/dãy), giới tính, avatar, minh chứng → `AWAITING_APPROVAL`, thông báo mọi Admin.
- [ ] `GET /admin/trainer-profiles` (Admin) — danh sách/tìm kiếm.
- [ ] `PUT /admin/trainer-profiles/{id}/review` (Admin) — chỉ khi set `VERIFIED` mới áp dụng/validate `revenueShare` (0.50–0.95 nếu ghi đè); gửi email + notification dù kết quả là gì.

## 3. Technical Constraints
- **Security:** endpoint review chỉ Admin (`hasAuthority('MANAGE_ACCOUNTS_ROLES') or hasRole('ADMINISTRATOR')`); endpoint self-service chỉ cần đăng nhập.
- **File Storage:** minh chứng upload thẳng lên Cloudinary, DB chỉ lưu URL (`scoreReportUrl`, cột LONGTEXT).
- **Schema fragile:** `TrainerProfile` có `@PostConstruct` tự chạy `ALTER TABLE`/`DROP COLUMN` lúc backend khởi động để dọn field cũ (`slogan`, `target_*`, `ielts_url`...) — không có migration tool, sửa entity này cần cẩn trọng.

## 4. Edge Cases
- **Thiếu minh chứng khi submit:** chặn submit, không chuyển `AWAITING_APPROVAL`.
- **Request for edit (đơn không `VERIFIED`):** Trainer sửa & submit lại được (trừ khi `SUSPENDED` — không cho sửa draft tiếp).
- **Course đầu tiên bắt buộc miễn phí** — kiểm tra ở module Course, không phải module này.
- **Admin gửi `status` lạ (ngoài 3 giá trị nghiệp vụ):** hiện **không có whitelist server-side** chặn — cần cẩn trọng ở phía client/API contract, không nên coi server tự bảo vệ khỏi input sai.

## 5. Non-functional Requirements
- **Notification:** submit/review đều bắn notification thật (không chỉ email) — Admin nhận khi có đơn mới, Trainer nhận khi có kết quả duyệt.
