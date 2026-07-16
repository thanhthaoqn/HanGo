# HanGo Project: AI Agents Coordination Protocol

> File này là **giao thức duy nhất** cho tất cả AI Agents làm việc trên repo HanGo.
> Đặt ở **gốc repo** để IDE (Antigravity, Cursor, Copilot, Windsurf...) tự động đọc.
> **Single Source of Truth cho requirement: [`/doc/HanGo_Documentation.md`](doc/HanGo_Documentation.md) v1.0**

---

## 0. Nguyên tắc tối cao

1. **`/doc/HanGo_Documentation.md` v1.0 là nguồn chân lý cho requirement.** Code cũ là nguồn chân lý cho implementation đang chạy.
2. Khi **code và doc mâu thuẫn**: **giữ nguyên code**, KHÔNG tự sửa code cho khớp doc. Báo lại theo mẫu §14.
3. **Không tự quyết** khi gặp mơ hồ. Nêu rõ: (1) doc nói gì, (2) code hiện tại làm gì, (3) đề xuất — rồi **chờ xác nhận**.
4. Ưu tiên **thay đổi nhỏ nhất, khu trú (minimal diff)**. Làm đúng task được giao, không hơn.

---

## 1. AI Team Composition & Capabilities

Ba Agent chuyên biệt; mỗi Agent bị giới hạn chặt trong domain của mình:

| Agent Role | Domain Directory | Core Tech Stack | Config Profile |
| :--- | :--- | :--- | :--- |
| **Backend Agent** | `/hango-backend/` | Java 21, Spring Boot, Spring Data JPA, MySQL | [`/doc/agent_backend.md`](doc/agent_backend.md) |
| **Frontend Agent** | `/hango-frontend/` | Flutter, Dart `^3.12.0`, Dio, Clean Architecture | [`/doc/agent_frontend.md`](doc/agent_frontend.md) |
| **QA Agent** | Global (Test suites) | JUnit 5/Mockito (BE), `flutter_test` (FE) | [`/doc/agent_qa.md`](doc/agent_qa.md) |

> **Constraint:** Agent KHÔNG ĐƯỢC sửa file ngoài domain được giao, trừ khi có sự giám sát rõ ràng của Human.

---

## 2. Context Initialization (Nạp ngữ cảnh khi bắt đầu session)

Khi bắt đầu session mới hoặc tiếp nhận task, Agent **PHẢI** đọc theo đúng thứ tự:

1. **Security & Principles:** [`/doc/CONSTITUTION.md`](doc/CONSTITUTION.md)
2. **System Architecture:** [`/doc/ARCHITECTURE.md`](doc/ARCHITECTURE.md)
3. **Business Requirements:** [`/doc/HanGo_Documentation.md`](doc/HanGo_Documentation.md) ← v1.0, ưu tiên tuyệt đối
4. **Current State:** [`/TODO.md`](TODO.md)
5. **Feature Spec** (nếu có): `/doc/specs/0X-<tên-module>.md`

---

## 3. Multi-Agent Workflow & Hand-off Protocol

Để implement bất kỳ feature nào trong 14 module (`§6` của doc), Agent thực hiện theo workflow **Frontend-First**:

1. **Human Trigger:** Human giao task + Figma mockup + chỉ định Agent role.
2. **Phase 1 — Frontend UI & Mock Data (Frontend Agent):**
   - Đọc Spec trong `/doc/specs/` và nghiên cứu Figma.
   - Build UI components trong Flutter đúng pixel.
   - Implement repositories trả **Mock Data (Fake JSON)** để UI hoàn chỉnh chạy được mà không cần API thật.
   - *Hand-off:* Cập nhật `/TODO.md` đánh dấu UI & Mock Data là `Done`.
3. **Phase 2 — Backend API Design (Backend Agent):**
   - Phân tích cấu trúc Mock Data JSON, đọc Spec.
   - Thiết kế DB Schema & Entities.
   - Build API Contracts (DTOs + Controllers) và implement Service logic trong Spring Boot.
   - *Hand-off:* Cập nhật `/TODO.md` đánh dấu API endpoints là `Done`.
4. **Phase 3 — Integration (Frontend Agent):**
   - Thay thế Mock Repositories bằng `dio` API calls thực.
   - *Hand-off:* Cập nhật `/TODO.md` đánh dấu Integration là `Done`.
5. **Phase 4 — QA (QA Agent):**
   - Đọc Acceptance Criteria & Edge Cases trong Spec.
   - Sinh và chạy Unit/Integration/Widget tests theo `/doc/TESTING.md` và `/doc/specs/unit_test_plan.md`.

---

## 4. Global Definition of Done (Tiêu chuẩn hoàn thành)

Agent **KHÔNG ĐƯỢC** check `[x] Done` trong `/TODO.md` nếu chưa pass tất cả:

- [ ] **Compilation:** `0` errors. (Dart analysis 0 issues; Maven build `SUCCESS`).
- [ ] **Linting:** Pass `flutter_lints` (FE); standard Java conventions (BE).
- [ ] **Test Coverage:** Logic mới phải có test; Backend coverage ≥ 80%; tests `PASS 100%`.
- [ ] **Security:** Không hardcode secrets/API keys. JWT + RBAC `@PreAuthorize` trên mọi API mới.
- [ ] **Commit:** Theo Conventional Commits: `feat(auth): add login endpoint`.

---

## 5. Coding Conventions

> Quy tắc chi tiết (kiến trúc N-Tier, Lombok/DTO/MapStruct, màu sắc & responsive Flutter, Riverpod, Null Safety...) đã định nghĩa đầy đủ tại [`CONSTITUTION.md`](doc/CONSTITUTION.md) §2–5, bổ sung theo domain tại [`agent_backend.md`](doc/agent_backend.md) / [`agent_frontend.md`](doc/agent_frontend.md). Agent đã đọc các file này ở bước Context Initialization (§2) — **không lặp lại nội dung ở đây**, chỉ cross-check khi có nghi vấn.

---

## 6. Security — Bắt buộc

> Quy tắc đầy đủ tại [`CONSTITUTION.md`](doc/CONSTITUTION.md) §6. Nhắc nhanh 2 điểm agent hay quên:
- Secrets (DB password, JWT secret, VNPay hash secret, Cloudinary key, AI key) đọc từ **biến môi trường** — không hardcode, không commit vào Git.
- **VNPay:** xử lý nghiệp vụ ở **IPN** (không phải return URL), luôn verify checksum + amount, IPN phải **idempotent**.

---

## 7. Database

> Quy tắc naming/relationship tại [`CONSTITUTION.md`](doc/CONSTITUTION.md) §5. Riêng cho multi-agent workflow:
- Dùng **migration** (Flyway/Liquibase) cho mọi thay đổi schema — không sửa DB tay; không sửa migration đã merge/chạy trên môi trường chung.
- Tôn trọng **versioning** của Course/Exam ([`HanGo_Documentation.md`](doc/HanGo_Documentation.md) §9): sửa nội dung đã Published tạo version mới, không ghi đè bản live.

---

## 8. Testing & Error Handling

- Ưu tiên có test cho logic quan trọng: payment, grading, RBAC, revenue split (xem thứ tự ưu tiên đầy đủ tại [`agent_qa.md`](doc/agent_qa.md) §3).
- Dùng **global exception handler** thống nhất; không nuốt lỗi im lặng (`catch` rỗng); không để lộ stack trace ra response cho client.
- Chi tiết chiến lược & test cases: [`TESTING.md`](doc/TESTING.md) và [`specs/unit_test_plan.md`](doc/specs/unit_test_plan.md).

---

## 9. Git

> Branching model & commit convention đầy đủ tại [`CONSTITUTION.md`](doc/CONSTITUTION.md) §8. Riêng cho multi-agent workflow:
- Không commit: file build, `.env`/secret, `target/` `build/` `.dart_tool/`, file IDE cá nhân.
- Trước khi kết thúc task: liệt kê những file đã đổi và tóm tắt thay đổi.

---

## 10. Không tự ý — Phải xin xác nhận

Các hành động sau **luôn phải xin xác nhận trước**, kể cả khi có vẻ hợp lý:

- Thêm / gỡ / nâng version **dependency** (Maven `pom.xml`, `pubspec.yaml`).
- Thay đổi **DB schema** hoặc tạo/sửa **migration**.
- Đổi **cấu trúc thư mục / package**, đổi tên class/interface public.
- Đổi **config hạ tầng** (`application.yml`, CORS, security config, VNPay/Cloudinary/JWT).
- Thay đổi **API contract** (path, method, request/response shape) của endpoint đã có.
- Chạy lệnh có tác dụng phụ (migration lên DB thật, xóa dữ liệu, deploy).

---

## 11. Escalation Boundaries (Lằn ranh đỏ — Dừng lại và gọi Human)

Agent **PHẢI DỪNG**, revert về trạng thái ổn định cuối cùng, và log vào mục `🛑 Escalated to Human` của `/TODO.md` nếu:

- **3-Attempt Rule:** Agent thất bại 3 lần liên tiếp fix cùng một compilation error / failing test / bug.
- **Dependency Modification:** Cần cài library mới chưa được phê duyệt.
- **Architectural Conflict:** Phát hiện mâu thuẫn giữa doc spec và DB Schema thực tế / `/doc/ARCHITECTURE.md`.
- **Destructive Action:** Task yêu cầu drop DB table, xóa core module, rewrite global config (`pom.xml`, `pubspec.yaml`).

---

## 12. Cập nhật tài liệu

- Chỉ cập nhật `/doc/HanGo_Documentation.md` khi **được yêu cầu** hoặc khi **một quyết định trong doc đã thực sự bị code thay đổi**.
- Khi cập nhật: **chỉ sửa đúng mục liên quan**, giữ nguyên cấu trúc & style; không viết lại toàn bộ file.
- Ghi mọi thay đổi quyết định vào **§14 Decision Log** kèm ngày và lý do ngắn.
- Không tự động cập nhật doc sau mỗi lần chạm code (gây nhiễu).

---

## 13. Khi gặp khác biệt Doc vs Code (Mẫu phản hồi)

```
⚠️ Phát hiện khác biệt:
- Doc (§...) nói: ...
- Code hiện tại: ...
- Đề xuất: [A] sửa code theo doc / [B] cập nhật doc theo code / [C] khác
→ Chọn hướng nào?
```

---

*AGENTS.md — HanGo v1.0. Cập nhật khi convention team thay đổi.*
