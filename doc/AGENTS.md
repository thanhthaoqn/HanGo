# AGENTS.md — AI Working Rules cho dự án HanGo

> File này quy định cách **AI agent trong IDE** (Antigravity/Copilot/Cursor...) được phép làm việc trên repo HanGo.
> Đặt file ở **gốc repo** và commit vào Git. Nếu IDE của bạn đọc tên khác (`.cursorrules`, `.windsurfrules`, `.rules`...), hãy đổi tên/nhân bản cho khớp.
> Ký hiệu 📌 = chỗ cần chỉnh theo codebase thật của team.

---

## 0. Nguyên tắc tối cao

1. **CODE hiện tại là nguồn chân lý.** `doc/HanGo_Documentation.md` là tài liệu **tham chiếu**, không phải mệnh lệnh refactor.
2. Khi **code và doc mâu thuẫn**: **giữ nguyên code**, KHÔNG tự sửa code cho khớp doc. Báo lại và đề xuất cập nhật doc.
3. **Không tự quyết** khi gặp mơ hồ. Nêu rõ: (1) doc nói gì, (2) code hiện tại làm gì, (3) đề xuất — rồi **chờ người xác nhận**.
4. Ưu tiên **thay đổi nhỏ nhất, khu trú (minimal diff)**. Làm đúng task được giao, không hơn.

---

## 1. Giữ code hiện tại — chống thay đổi ngoài ý muốn

- Chỉ sửa code khi **được yêu cầu rõ ràng**, hoặc khi **bắt buộc** để hoàn thành task.
- **KHÔNG** refactor, đổi tên, đổi cấu trúc, "dọn dẹp", tối ưu tự phát ngoài phạm vi task.
- **KHÔNG** đụng vào file/module không liên quan đến task.
- Trước khi sửa thứ **đang chạy được**, giải thích lý do; nếu thay đổi lan rộng (>1–2 file hoặc chạm public API/interface), **hỏi trước**.
- Không xóa code cũ chỉ vì "không dùng tới" — có thể đang dùng ở nơi khác. Hỏi trước khi xóa.

---

## 2. Không tự ý (phải hỏi trước)

Các hành động sau **luôn phải xin xác nhận**, kể cả khi có vẻ hợp lý:

- Thêm / gỡ / nâng version **dependency** (Maven/Gradle, pubspec.yaml).
- Thay đổi **DB schema** hoặc tạo/sửa **migration**.
- Đổi **cấu trúc thư mục / package**, đổi tên class-interface public.
- Đổi **config hạ tầng** (application.yml, CORS, security config, cấu hình VNPay/Cloudinary/JWT).
- Thay đổi **API contract** (đổi path, method, request/response shape) của endpoint đã có.
- Chạy lệnh có tác dụng phụ (migration lên DB thật, xóa dữ liệu, deploy).

---

## 3. Cập nhật tài liệu

- Chỉ cập nhật `doc/HanGo_Documentation.md` khi **được yêu cầu**, hoặc khi một **quyết định trong doc đã thực sự bị code thay đổi**.
- Khi cập nhật: **chỉ sửa đúng mục liên quan**, giữ nguyên cấu trúc & style; **không viết lại toàn bộ** file.
- Ghi mọi thay đổi quyết định vào mục **§15 Decision Log** kèm **ngày** và lý do ngắn.
- Không tự động cập nhật doc sau **mỗi** lần chạm code (gây nhiễu). Chỉ khi có thay đổi mang tính quyết định.

---

## 4. Convention — Backend (Java / Spring Boot)

## 5. Convention — Frontend (Flutter)

## 6. Security — BẮT BUỘC

- **RBAC kiểm tra ở backend (service layer)** cho mọi thao tác nhạy cảm; **không tin** dữ liệu/role từ client.
- **KHÔNG** log token, password, OTP, secret, thông tin ngân hàng, dữ liệu cá nhân nhạy cảm.
- Mật khẩu **hash** (bcrypt/argon2), không bao giờ lưu/log plaintext.
- **JWT:** validate chữ ký & hạn; access token ngắn hạn + refresh token; không để lộ secret.
- **VNPay:** luôn **verify checksum (secureHash)** và **đối chiếu amount** với Order trong DB. Xử lý nghiệp vụ quan trọng ở **IPN**, không ở return URL. IPN phải **idempotent** (chống gọi trùng).
- **Secrets** (DB password, JWT secret, VNPay hash secret, Cloudinary key, mail password, AI key) đọc từ **biến môi trường / config ngoài**, **KHÔNG hardcode**, **KHÔNG commit** vào Git.

---

## 7. Database

- Dùng **migration** (Flyway/Liquibase 📌) cho mọi thay đổi schema — không sửa DB tay.
- Không viết migration **phá hủy dữ liệu** (drop column/table, đổi kiểu mất mát) nếu chưa được duyệt.
- Migration chỉ **thêm mới, tiến tới**; không sửa migration đã merge/chạy trên môi trường chung.
- Tôn trọng **versioning** của Course/Exam (§9.7 trong doc): sửa nội dung đã Published tạo version mới, không ghi đè bản live.

---

## 8. Testing & Error Handling

- Viết/không viết test: theo yêu cầu task; **ưu tiên có test cho logic quan trọng** (payment, grading, RBAC, revenue split).
- Dùng **global exception handler** thống nhất; không nuốt lỗi im lặng (`catch` rỗng).
- Không để lộ stack trace / thông tin nội bộ ra response cho client.

---

## 9. Git

- **Commit nhỏ, một mục đích**; message rõ ràng (khuyến nghị dạng `feat:`, `fix:`, `refactor:`, `docs:`).
- Làm trên **feature branch**, không commit thẳng vào `main`/`develop` 📌.
- **KHÔNG** commit: file build, `.env`/secret, thư mục `target/` `build/` `node_modules/`, file IDE cá nhân (đảm bảo có trong `.gitignore`).
- Trước khi kết thúc task: liệt kê **những file đã đổi** và tóm tắt thay đổi để người review đọc diff.

---

## 10. Khi gặp khác biệt so với doc (mẫu phản hồi)

Không tự sửa. Trả lời theo mẫu:
```
⚠️ Phát hiện khác biệt:
- Doc (§...) nói: ...
- Code hiện tại: ...
- Đề xuất: [A] sửa code theo doc / [B] cập nhật doc theo code / [C] khác
→ Chọn hướng nào?
```

---

*AGENTS.md — HanGo. Cập nhật khi convention team thay đổi.*
