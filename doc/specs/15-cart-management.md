# Feature Specification: FE-15 — Cart Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.15 (CART). Module mới tách riêng trong Feature Map 19-module (2026-08-10) — trước đây gộp chung vào Payment & Revenue.

## 1. Business Context
Giỏ hàng cho Learner (và Trainer ở Learner mode) gom nhiều Course trước khi checkout. Hỗ trợ cả khách chưa đăng nhập (lưu local) — tự động đồng bộ vào giỏ DB ngay khi đăng nhập.

## 2. Acceptance Criteria

**Frontend (Flutter, `cart_page.dart` — tab trong `LearnerShellPage`):**
- [ ] View cart list — hiển thị toàn bộ Course trong giỏ kèm giá.
- [ ] Add cart item — từ `CourseCard` (grid catalog) hoặc `CourseDetailPage` (toggle), không phải từ chính trang Cart.
- [ ] Remove cart item — xoá optimistic ở UI trước, đồng bộ server sau.
- [ ] Checkout — tách Course free (enroll ngay, không qua thanh toán) và Course trả phí (mở `PaymentQrDialog`).
- [ ] Guest cart (chưa đăng nhập) lưu `SharedPreferences`, tự merge vào giỏ DB khi đăng nhập (`CartManager.syncGuestCartOnLogin`).

**Backend (Spring Boot, `CartController` base `/api/v1/cart`, không có `@PreAuthorize`, tự check đăng nhập trong code):**
- [ ] `GET /` — tự lọc bỏ (không xoá row) Course đã enroll khỏi danh sách hiển thị.
- [ ] `POST /items` — chặn nếu đã enroll; nếu đã có trong giỏ thì bỏ qua êm (không lỗi).
- [ ] `DELETE /items/{courseId}`, `DELETE /` (clear toàn bộ).
- [ ] `POST /sync` — merge danh sách `courseIds` từ giỏ khách vào giỏ DB, bỏ qua id đã enroll hoặc đã có sẵn.

## 3. Technical Constraints
- **Không có role-gate riêng** — mọi role đã đăng nhập dùng chung được giỏ hàng của chính mình (kể cả Trainer/Admin, không riêng Learner).
- **Item "stale" (đã enroll nhưng vẫn còn row trong `cart_items`)** không bị xoá tự động khi `GET /` — chỉ bị ẩn khỏi kết quả trả về, cần biết trước nếu debug số lượng row trong bảng `cart_items`.

## 4. Edge Cases
- **Add lại Course đã có trong giỏ:** không báo lỗi, coi như no-op.
- **Add Course đã enroll:** chặn với thông báo rõ ràng ("Bạn đã sở hữu khóa học này").
- **Thanh toán thành công (kể cả free):** dọn item tương ứng khỏi giỏ ngay (xem [14-payment-revenue.md](14-payment-revenue.md)).

## 5. Non-functional Requirements
- **UX:** thao tác thêm/xoá giỏ hàng cập nhật UI ngay (optimistic), không chờ round-trip server mới phản hồi.
