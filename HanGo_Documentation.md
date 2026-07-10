# HanGo — Project Documentation (Requirements & Development Baseline)

> **Version:** 0.9 — tài liệu gốc (single source of truth) cho requirement + AI code.
> **Ngôn ngữ:** Tiếng Việt, thuật ngữ nghiệp vụ & kỹ thuật giữ nguyên English để đồng bộ code.
> **Ký hiệu:** `FR` = Functional Requirement · `BR` = Business Rule · 📌 = mục còn để mở (không chặn v1).
> **Phạm vi tài liệu:** mô tả nghiệp vụ + functional + conceptual model. **Không** bao gồm REST endpoints hay DDL (đã có codebase); phần AI chỉ mô tả chức năng.

---

## Mục lục

1. [Giới thiệu & Phạm vi](#1-giới-thiệu--phạm-vi)
2. [Thuật ngữ (Glossary)](#2-thuật-ngữ-glossary)
3. [Mô hình kinh doanh](#3-mô-hình-kinh-doanh)
4. [Actors, Roles & Phân quyền](#4-actors-roles--phân-quyền)
5. [Tech Stack & Architecture](#5-tech-stack--architecture)
6. [Bản đồ tính năng (Feature Map)](#6-bản-đồ-tính-năng-feature-map)
7. [Functional Requirements theo module](#7-functional-requirements-theo-module)
8. [Global Business Rules](#8-global-business-rules)
9. [Vòng đời, State Machines & Versioning](#9-vòng-đời-state-machines--versioning)
10. [Cross-module Workflows](#10-cross-module-workflows)
11. [AI Features](#11-ai-features)
12. [Conceptual Data Model](#12-conceptual-data-model)
13. [Enums tổng hợp](#13-enums-tổng-hợp)
14. [Non-Functional Requirements](#14-non-functional-requirements)
15. [Decision Log & Future Items](#15-decision-log--future-items)

---

## 1. Giới thiệu & Phạm vi

### 1.1 Sản phẩm

**HanGo (Smart Language Self-Study Platform)** là Learning Management System chuyên biệt cho việc học và ôn thi môn **Tiếng Anh THPT Quốc Gia**, kết hợp ba thành phần trong một nền tảng:

- **LMS** — quản lý nội dung & tiến độ học.
- **Course Marketplace** — Trainer phân phối, Learner mua/học Course.
- **AI-powered Learning Platform** — AI hỗ trợ cả người dạy và người học.

HanGo **không tự sản xuất nội dung**; nền tảng kết nối Trainer (tạo Course) với Learner (học), và kiểm soát chất lượng xuất bản qua Course Manager.

### 1.2 Trong phạm vi (In-scope, v1)

- 14 module chức năng (xem §6), triển khai trên **nền web**.
- Toàn bộ luồng: đăng ký/onboarding → tạo & duyệt nội dung → học & luyện đề → recommendation → thanh toán & doanh thu.

### 1.3 Ngoài phạm vi (Out-of-scope, v1)

Ứng dụng mobile app native (làm sau nếu còn thời gian), refund/hoàn tiền, tự động payout cho Trainer, giới hạn & tính phí AI, đa ngôn ngữ giao diện, GroupType trong course-authoring (v1 chỉ dùng GroupType để hiển thị Exam), pass-score cho Quiz, lớp học trực tiếp, nhắn tin trực tiếp, forum, gamification, chứng chỉ hoàn thành, hỗ trợ môn khác ngoài Tiếng Anh THPT.

---

## 2. Thuật ngữ (Glossary)

| Thuật ngữ | Định nghĩa |
|---|---|
| **Course** | Khóa học do Trainer tạo, gồm nhiều Section. |
| **Section** | Chương/phần trong Course, chứa nhiều Lesson. |
| **Lesson** | Bài học nhỏ nhất; chứa nhiều **LessonBlock** (text/video/pdf/image) và có thể có Quiz. |
| **LessonBlock** | Một khối nội dung trong Lesson (ưu tiên text trước, rồi tới media/file). |
| **Quiz** | Bài luyện tập trong Lesson, dùng câu hỏi từ Question Bank (tái sử dụng). |
| **Exam** | Bài thi độc lập với Course, mô phỏng đề THPT, dùng câu hỏi riêng. |
| **Question Bank** | Kho câu hỏi tái sử dụng của Trainer, phục vụ Quiz. |
| **QuestionGroup** | Nhóm câu hỏi dùng chung ngữ liệu (passage). |
| **Attempt** | Một lần Learner làm Quiz/Exam; được phép nhiều lần. |
| **SkillType** | Loại kỹ năng của câu hỏi/khóa học (Grammar, Reading...); dùng cho phân tích & gợi ý. |
| **Weakness Analysis** | Phân tích điểm yếu theo SkillType sau khi làm Exam. |
| **Recommendation** | Gợi ý Course/lộ trình dựa trên kết quả Exam. |
| **Trainer** | Người tạo nội dung; hai loại: Professional / Peer Tutor. |
| **Course Manager** | Người kiểm duyệt trình bày & xuất bản nội dung. |
| **Monthly Statement** | Báo cáo doanh thu hàng tháng của Trainer. |

---

## 3. Mô hình kinh doanh

### 3.1 Loại hình

Marketplace-based Learning Management System — HanGo là nền tảng trung gian, thu phí qua chia sẻ doanh thu.

### 3.2 Revenue Sharing

| Loại Trainer | Trainer nhận | HanGo nhận |
|---|---|---|
| **Professional Trainer** | 70% | 30% |
| **Peer Tutor** | 60% | 40% |

**Quy tắc doanh thu:**
- Course **đầu tiên** của mỗi Trainer **bắt buộc miễn phí**; sau đó tự do đặt free/paid.
- Course trả phí: Learner thanh toán qua HanGo (VNPay) → ghi nhận doanh thu theo Course → cuối kỳ tổng hợp thành Monthly Statement → Trainer xác nhận → **Administrator** chi trả (chuyển khoản thủ công + ghi nhận).

### 3.3 Định giá Course (Price Tier)

Backend **tự đánh giá quy mô Course** (số Lesson, số Quiz, thời lượng video...) để **gợi ý** một mức giá tham chiếu:

| Quy mô | Gợi ý |
|---|---|
| Lớn (nhiều nội dung/quiz/thời lượng dài) | 700.000 VND |
| Trung bình | 500.000 VND |
| Nhỏ | 300.000 VND |

> Backend chỉ **gợi ý**; **Trainer chốt giá cuối cùng** (≥ 0 VND). Công thức tính quy mô sẽ được làm rõ ở giai đoạn sau.

### 3.4 Stakeholders

**Internal:** Administrator, Course Manager, Trainer, Learner.
**External:** Guest, Payment Gateway (VNPay), AI Provider, Email Service, Media/File Storage (Cloudinary).

---

## 4. Actors, Roles & Phân quyền

### 4.1 Nguyên tắc

- **One account, one primary role:** mỗi người dùng có **một** tài khoản với **một** primary role (Learner / Trainer / CourseManager / Administrator).
- **Trainer dual-mode:** tài khoản **Trainer bao gồm cả năng lực Learner**, chuyển qua **UI mode switch** (Trainer mode ⇄ Learner mode):
  - *Trainer mode:* dùng đầy đủ chức năng Trainer.
  - *Learner mode:* enroll/mua/học Course của Trainer khác, làm Quiz/Exam, nhận Recommendation; các chức năng Trainer bị **làm mờ (disabled)**.
  - Đây là UI/session state, không phải role thứ hai; permission = năng lực Trainer ∪ năng lực Learner. CourseManager & Administrator **không** có Learner mode.
- **Ownership:** mọi Course/Question thuộc về Trainer tạo ra; chỉ owner được sửa.
- **Governance:** nội dung phải qua kiểm duyệt trước khi Published.
- **Separation of duties:** Course Manager lo **chất lượng nội dung**; Administrator lo **user + tài chính + hệ thống**. Course Manager **không** tham gia doanh thu.

### 4.2 Mô tả role

| Role | Vai trò | Giới hạn chính |
|---|---|---|
| **Guest** | Chưa đăng nhập; xem nội dung công khai, đăng ký. | Không xem Lesson; không làm Quiz/Exam. |
| **Learner** | Học, luyện đề, nhận recommendation. | Không tạo nội dung; không publish. |
| **Trainer** | Tạo Course/Lesson/Quiz/Exam; quản lý Question Bank; theo dõi doanh thu. Có **Learner mode**. | Không tự publish; không duyệt; không quản lý user. |
| **Course Manager** | Review & publish nội dung (chỉ trình bày). Tạo Exam. | Không sửa nội dung Course; không chia doanh thu. |
| **Administrator** | Quản trị user, role, doanh thu, hệ thống, AI. | Không sửa nội dung Course của Trainer. |

### 4.3 RBAC Matrix

> ✅ được phép · ❌ không · **Own** = chỉ trên tài nguyên do mình sở hữu.

| Resource / Action | Guest | Learner | Trainer | Course Manager | Admin |
|---|:--:|:--:|:--:|:--:|:--:|
| Register / Login / Reset password (OTP) | ✅ | ✅ | ✅ | ✅ | ✅ |
| View / Update own Profile | ❌ | ✅ | ✅ | ✅ | ✅ |
| Submit Trainer Application | ✅ | ✅ | ❌ | ❌ | ❌ |
| Review / Approve Trainer Application | ❌ | ❌ | ❌ | ❌ | ✅ |
| Browse / Search / View Course & Exam | ✅ | ✅ | ✅ | ✅ | ✅ |
| View Lesson content | ❌ | ✅ (enrolled) | ✅ Own | ✅ | ✅ |
| Create / Update / Archive Course | ❌ | ❌ | ✅ Own | ❌ | ❌ |
| Submit Course for review | ❌ | ❌ | ✅ Own | ❌ | ❌ |
| Review / Approve / Publish Course | ❌ | ❌ | ❌ | ✅ | ❌ |
| Manage Section / Lesson / Quiz / Media | ❌ | ❌ | ✅ Own | ❌ | ❌ |
| Manage Question Bank | ❌ | ❌ | ✅ Own | ❌ | ❌ |
| Create / Update Exam | ❌ | ❌ | ✅ (→review) | ✅ (self-publish) | ❌ |
| Review / Publish Exam | ❌ | ❌ | ❌ | ✅ | ❌ |
| Enroll / Purchase / Continue Course | ❌ | ✅ | ✅ (Learner mode) | ❌ | ❌ |
| Attempt Quiz / Exam | ❌ | ✅ | ✅ (Learner mode) | ❌ | ❌ |
| Rate Course | ❌ | ✅ | ✅ (Learner mode) | ❌ | ❌ |
| View Recommendation | ❌ | ✅ | ✅ (Learner mode) | ❌ | ❌ |
| Comment / Reply (Lesson & Quiz) | ❌ | ✅ | ✅ | ❌ | ❌ |
| Moderate Comment | ❌ | ❌ | ❌ | ❌ | ✅ |
| AI Content Generation | ❌ | ❌ | ✅ | ❌ | ❌ |
| AI Learning Assistant | ❌ | ✅ | ✅ (Learner mode) | ❌ | ❌ |
| View own Revenue / Confirm Statement | ❌ | ❌ | ✅ Own | ❌ | ✅ |
| Generate Statement / Confirm Payment / Record Transfer | ❌ | ❌ | ❌ | ❌ | ✅ |
| User Management / Assign Role / Permissions | ❌ | ❌ | ❌ | ❌ | ✅ |
| Platform Dashboard / Analytics / AI Usage / Audit log | ❌ | ❌ | ❌ | (content) | ✅ (full) |

---

## 5. Tech Stack & Architecture

| Thành phần | Lựa chọn |
|---|---|
| **Frontend** | **Flutter** — target **Web** ở v1 (mobile app để giai đoạn sau). Mọi role dùng chung web app, phân vùng UI theo role. |
| **Backend** | **Java + Spring Boot**, REST API |
| **Kiến trúc** | Monolith, layered / clean architecture |
| **Database** | **MySQL 8.0** |
| **Auth** | **JWT** (access token + refresh token); chỉ email/mật khẩu (không social login ở v1) |
| **Realtime** | **WebSocket** (dùng cho Notification) |
| **Media / File** | **Cloudinary** (video, pdf, ảnh của Lesson) |
| **Payment** | **VNPay** (tiền tệ **VND**) |
| **Email** | Email Service cho **OTP verification** (bắt buộc) & thông báo |
| **AI** | LLM API (đã tích hợp; chi tiết tích hợp ngoài phạm vi tài liệu này) |
| **Deployment** | **AWS** |
| **Source control** | **GitHub** |

**Nguyên tắc kiến trúc chính:**
- Phân quyền RBAC kiểm tra ở **mọi API** (không tin frontend).
- Payment/business logic quan trọng xử lý ở **server + IPN webhook**, không dựa vào return URL.
- Media không lưu trong DB; DB chỉ giữ **URL Cloudinary**.

---

## 6. Bản đồ tính năng (Feature Map)

```
FE-01 Authentication
├── Register (+ Email OTP Verification)
├── Login
├── Forgot Password
├── Reset Password
└── Logout

FE-02 Profile Management
├── View Profile
├── Update Profile
├── Change Password
└── View Learning Profile

FE-03 Role & Permission Management
├── Account Management (view / activate-deactivate / create)
├── Role Management (assign / update)
├── Permission Management (view / configure)
└── Platform Monitoring (dashboard & analytics / AI usage / audit log)

FE-04 Trainer Onboarding
├── Trainer Application (submit / upload documents / track status)
├── Application Review (review / approve-reject)
└── Trainer Activation

FE-05 Course Management
├── Course Discovery (browse / search / filter)
├── Course Authoring (create / update / archive)
└── Course Review (submit / review / approve-reject / publish-unpublish)

FE-06 Course Content Management
├── Manage Section
├── Manage Lesson (LessonBlock: text-first + media)
├── Manage Quiz
├── Upload File (Cloudinary)
└── Import Content (Excel)

FE-07 Question Bank Management
├── Create Question
├── Manage Question
└── AI Generate Question & Explanation

FE-08 Exam Management
├── Create Exam (Trainer & Course Manager)
├── Manage Exam Structure
├── Approve / Reject
├── Publish Exam
├── Take Exam (timer + auto-submit)
├── Exam Result
└── View Attempt History

FE-09 AI Assistant
├── Learning Assistant (explain concept / question / answer / Q&A)
└── Content Generation (quiz-question / explanation)

FE-10 Learning Management
├── Course Enrollment
├── Learning Progress
├── Continue Learning
├── Lesson Learning
├── Quiz Attempt
├── Learning History
└── Rate Course

FE-11 Recommendation
├── Weakness Analysis (by SkillType)
├── Rule-based Recommendation
├── AI Recommendation
└── AI Learning Pathway

FE-12 Payment & Revenue
├── Course Purchase (VNPay)
├── View Order Status
├── Manage Revenue
├── Confirm Revenue (Trainer)
└── Revenue Settlement (Admin)

FE-13 Comment Management
├── View Comments
├── Comment (Lesson & Quiz)
├── Reply Comment
└── Moderate Comment (Admin)

FE-14 Notification
├── Realtime In-app Notification (WebSocket)
└── Email Notification
```

---

## 7. Functional Requirements theo module

> Mỗi module: **Actors · Functional Requirements · Business Rules**.

### 7.1 Authentication (`AUTH`)
**Actors:** Guest, mọi role đã đăng nhập.

| ID | Requirement |
|---|---|
| FR-AUTH-01 | Đăng ký tài khoản bằng email, mật khẩu, họ tên. |
| FR-AUTH-02 | Gửi **OTP** qua email; tài khoản chỉ active sau khi xác minh OTP thành công (**bắt buộc**). |
| FR-AUTH-03 | Đăng nhập bằng email + mật khẩu; cấp **access token + refresh token** (JWT). |
| FR-AUTH-04 | Quên mật khẩu → nhận OTP qua email. |
| FR-AUTH-05 | Đặt lại mật khẩu sau khi xác minh OTP. |
| FR-AUTH-06 | Đăng xuất, thu hồi token/session. |

**BR-AUTH-01:** email là định danh duy nhất.
**BR-AUTH-02:** mật khẩu theo chuẩn phổ biến hiện nay (tối thiểu 8 ký tự, gồm chữ và số).

### 7.2 Profile Management (`PROF`)
**Actors:** Learner, Trainer, Course Manager, Admin.

| ID | Requirement |
|---|---|
| FR-PROF-01 | Xem profile cá nhân. |
| FR-PROF-02 | Cập nhật profile (họ tên, avatar, số điện thoại). |
| FR-PROF-03 | Đổi mật khẩu (yêu cầu mật khẩu hiện tại). |
| FR-PROF-04 | Learner xem **Learning Profile**: khóa đã học, tiến độ, lịch sử Exam, điểm yếu. |
| FR-PROF-05 | Trainer có trang public profile / brand page (thương hiệu, bio, danh sách Course). 📌 |

### 7.3 Role & Permission Management (`RBAC`)
**Actors:** Administrator.

| ID | Requirement |
|---|---|
| FR-RBAC-01 | Xem danh sách tài khoản; tìm kiếm & lọc theo role/status. |
| FR-RBAC-02 | Activate / Deactivate (lock/unlock) tài khoản. |
| FR-RBAC-03 | Tạo tài khoản thủ công (ví dụ Course Manager). |
| FR-RBAC-04 | Gán / cập nhật role. |
| FR-RBAC-05 | Xem & cấu hình permission theo role. 📌 *(tĩnh hay động)* |
| FR-RBAC-06 | Dashboard & Analytics toàn nền tảng (user, course, enrollment, doanh thu, top courses). |
| FR-RBAC-07 | Giám sát AI Usage (lượt, token, chi phí). |
| FR-RBAC-08 | Xem **audit log** các hành động quản trị (approve/publish/payment). |

### 7.4 Trainer Onboarding (`TRN`)
**Actors:** Guest/Learner (nộp), Administrator (duyệt).

| ID | Requirement |
|---|---|
| FR-TRN-01 | Nộp đơn Trainer, chọn loại **Professional** hoặc **Peer Tutor**. |
| FR-TRN-02 | Điền thông tin cá nhân, phone, CCCD (optional), **thông tin ngân hàng** (để nhận chi trả). |
| FR-TRN-03 | Upload minh chứng theo loại (Professional: bằng cấp/chứng chỉ/kinh nghiệm; Peer Tutor: điểm THPTQG/chứng chỉ/minh chứng). |
| FR-TRN-04 | Theo dõi trạng thái đơn. |
| FR-TRN-05 | Admin xem thông tin & minh chứng; Approve/Reject kèm ghi chú. |
| FR-TRN-06 | Khi Approve → kích hoạt tài khoản Trainer, lưu TrainerType & RevenueShareRate. |

**BR-TRN-01:** Trainer phải qua duyệt Admin.
**BR-TRN-02:** Course **đầu tiên bắt buộc miễn phí**.

### 7.5 Course Management (`CRS`)
**Actors:** Guest/Learner (discovery), Trainer (authoring), Course Manager (review).

| ID | Requirement |
|---|---|
| FR-CRS-01 | Browse Course đã Published. |
| FR-CRS-02 | Search Course theo từ khóa. |
| FR-CRS-03 | Filter theo category, tags, SkillType, giá, rating. |
| FR-CRS-04 | Xem chi tiết Course (mô tả, cấu trúc, giá, rating, Trainer, SkillType). Guest không xem nội dung Lesson. |
| FR-CRS-05 | Trainer tạo Course (metadata + chọn **tối đa 3 SkillType** thể hiện nội dung chính). |
| FR-CRS-06 | Trainer cập nhật Course (Draft/Rejected); backend **gợi ý price tier** theo quy mô, Trainer chốt giá. |
| FR-CRS-07 | Trainer archive Course. |
| FR-CRS-08 | Trainer xem thống kê enroll/doanh thu Course mình. |
| FR-CRS-09 | Trainer submit Course để duyệt. |
| FR-CRS-10 | Course Manager xem hàng chờ & review. |
| FR-CRS-11 | Course Manager Approve/Reject (kèm lý do). |
| FR-CRS-12 | Course Manager Publish/Unpublish. |
| FR-CRS-13 | Course Manager xem lịch sử publish. |

**BR-CRS-01:** Course Manager **chỉ kiểm tra trình bày** (template, metadata, cấu trúc, đầy đủ Lesson/Quiz, chính sách), **không** kiểm tra chuyên môn.
**BR-CRS-02:** Course Manager **không sửa** nội dung; cần đổi → Reject.
**BR-CRS-03:** sửa Course đã Published → tạo **version mới** cần duyệt lại; bản live giữ nguyên (xem §9.7).
**BR-CRS-04:** mỗi Course gắn **tối đa 3 SkillType** — dùng cho filter & AI recommendation.

### 7.6 Course Content Management (`CNT`)
**Actors:** Trainer (owner).

| ID | Requirement |
|---|---|
| FR-CNT-01 | Quản lý Section: tạo/sửa/xóa/sắp xếp. |
| FR-CNT-02 | Quản lý Lesson: tạo/sửa/xóa/sắp xếp; soạn nội dung bằng **LessonBlock** (ưu tiên text, có thể chèn thêm video/pdf/image). |
| FR-CNT-03 | Quản lý Quiz trong Lesson: tạo Quiz, thêm câu hỏi từ Question Bank. |
| FR-CNT-04 | Upload file (Video/PDF/Image) lên **Cloudinary**. |
| FR-CNT-05 | Import Content từ **file Excel (.xlsx)** theo template. |

**BR-CNT-01:** cấu trúc: Course → Section → Lesson → (LessonBlock, Quiz).

### 7.7 Question Bank Management (`QB`)
**Actors:** Trainer (owner).

| ID | Requirement |
|---|---|
| FR-QB-01 | Tạo Question: SkillType, Difficulty, QuestionType, Content, Explanation, Options (A/B/C/D), đáp án đúng, Visibility. |
| FR-QB-02 | Tạo QuestionGroup dùng chung passage (SharedContent). *(v1: GroupType chủ yếu phục vụ Exam.)* |
| FR-QB-03 | Xem/sửa/xóa/tìm kiếm Question theo SkillType, Difficulty, Visibility. |
| FR-QB-04 | Đặt Visibility Public/Private. |
| FR-QB-05 | AI Generate Question & Explanation (bản nháp → Trainer sửa). |

**BR-QB-01:** mỗi Question có **đúng 1 SkillType**.
**BR-QB-02:** Question của Quiz tái sử dụng được; Question của Exam khóa theo Exam.

### 7.8 Exam Management (`EXM`)
**Actors:** Trainer & Course Manager (tạo/duyệt), Learner (làm bài).

| ID | Requirement |
|---|---|
| FR-EXM-01 | Trainer hoặc Course Manager tạo Exam (metadata + cấu trúc). |
| FR-EXM-02 | Tạo Exam Questions **riêng** cho Exam. |
| FR-EXM-03 | Trainer submit → Course Manager Approve/Reject; Course Manager publish. Exam do Course Manager tạo được self-publish. |
| FR-EXM-04 | Learner start & làm Exam với **đếm giờ + auto-submit** khi hết giờ. |
| FR-EXM-05 | Submit → **auto-grade**; xem điểm (thang 10), đáp án đúng, giải thích. |
| FR-EXM-06 | Làm lại **không giới hạn**; xem attempt history trong Exam detail. |
| FR-EXM-07 | Kết quả Exam kích hoạt Weakness Analysis & Recommendation (§7.11). |

**BR-EXM-01:** Exam mô phỏng đề THPTQG Tiếng Anh **mới nhất**: **40 câu, 50 phút, thang điểm 10** (mỗi câu 0,25đ), trắc nghiệm 1 đáp án.
**BR-EXM-02:** Exam độc lập với Course, đề ổn định.

### 7.9 AI Assistant (`AI`)
**Actors:** Learner (learning), Trainer (content).

| ID | Requirement |
|---|---|
| FR-AI-01 | Learner: Explain Concept / Explain Question / Explain Answer / Answer Learning Questions. |
| FR-AI-02 | Trainer: Generate Quiz-Question, Generate Explanation. |
| FR-AI-03 | Mọi lượt gọi AI được log (feature, token, cost) cho monitoring. |

**BR-AI-01:** đầu ra AI cho Trainer là **bản nháp**; Trainer phải sửa & chịu trách nhiệm trước khi Submit.
**BR-AI-02:** v1 **không giới hạn** hạn mức AI (chỉ log); limit/cost để giai đoạn sau.

### 7.10 Learning Management (`LRN`)
**Actors:** Learner (và Trainer ở Learner mode).

| ID | Requirement |
|---|---|
| FR-LRN-01 | Enroll Course miễn phí; Course trả phí enroll sau khi thanh toán (§7.12). |
| FR-LRN-02 | Xem "My Learning" — các Course đã tham gia. |
| FR-LRN-03 | Học Lesson (LessonBlock). |
| FR-LRN-04 | Continue Learning — quay lại đúng vị trí. |
| FR-LRN-05 | Theo dõi Progress (% = số Lesson hoàn thành / tổng Lesson). |
| FR-LRN-06 | Quiz Attempt: start/submit/review; **không giới hạn** số lần; xem attempt history. |
| FR-LRN-07 | Learning History — lịch sử học & làm bài. |
| FR-LRN-08 | Rate Course (sao + nhận xét) cho Course đã enroll. |

**BR-LRN-01:** chỉ Learner đã enroll mới xem nội dung Lesson & làm Quiz.
**BR-LRN-02:** học **tuần tự theo Lesson** — hoàn thành Lesson N mới mở Lesson N+1 (Quiz không bắt buộc để mở Lesson kế tiếp).
**BR-LRN-03:** Lesson "hoàn thành" khi Learner đánh dấu hoàn thành / xem hết nội dung.
**BR-LRN-04:** mỗi Learner rate **đúng một lần** / Course.
**BR-LRN-05:** Course mua rồi truy cập **trọn đời**.

### 7.11 Recommendation (`REC`)
**Actors:** hệ thống (cho Learner) sau Exam.

| ID | Requirement |
|---|---|
| FR-REC-01 | Weakness Analysis theo **SkillType** từ ExamAttempt. |
| FR-REC-02 | Rule-based Recommendation: map SkillType yếu → Course có gắn SkillType đó. |
| FR-REC-03 | AI Recommendation cá nhân hóa. |
| FR-REC-04 | AI Learning Pathway: sinh lộ trình học. |

**BR-REC-01:** matching dựa trên **tối đa 3 SkillType** gắn ở mỗi Course.

### 7.12 Payment & Revenue (`PAY`)
**Actors:** Learner (mua), Trainer (doanh thu), Administrator (settlement).

| ID | Requirement |
|---|---|
| FR-PAY-01 | Learner mua Course trả phí qua **VNPay**. |
| FR-PAY-02 | Tạo Order; theo dõi trạng thái (Pending/Paid/Completed/Failed). |
| FR-PAY-03 | Nhận **IPN** từ VNPay → verify checksum + amount → **auto** mark Paid → **auto-enroll** (idempotent). |
| FR-PAY-04 | **Auto** ghi nhận doanh thu theo Course, chia tỷ lệ theo TrainerType (70/30 · 60/40). |
| FR-PAY-05 | Trainer xem doanh thu, sales, enroll statistics. |
| FR-PAY-06 | **Auto** generate Monthly Statement cuối kỳ. |
| FR-PAY-07 | Trainer confirm Monthly Statement. |
| FR-PAY-08 | Admin **chuyển khoản thủ công** cho Trainer rồi **record transfer** (đánh dấu Paid). |

**BR-PAY-01:** Course miễn phí không tạo Order (đi thẳng Enroll).
**BR-PAY-02:** doanh thu chỉ ghi nhận khi Order = Paid.
**BR-PAY-03 — auto vs manual:** *pay-in* (mua, xác nhận thanh toán, ghi doanh thu, sinh statement) là **tự động**; *payout* (chuyển tiền cho Trainer) là **thủ công** ở v1, auto-payout để future.
**BR-PAY-04:** kỳ doanh thu theo tháng, timezone **Asia/Ho_Chi_Minh**; **kỳ chốt có thể cấu hình** (để phục vụ test), không hard-code cứng.

### 7.13 Comment Management (`CMT`)
**Actors:** Learner, Trainer (comment/reply), Administrator (moderate).

| ID | Requirement |
|---|---|
| FR-CMT-01 | Xem danh sách comment trong **Lesson và Quiz**. |
| FR-CMT-02 | Đăng comment trong Lesson/Quiz. |
| FR-CMT-03 | Reply comment (nested). |
| FR-CMT-04 | **Administrator** moderate (ẩn/xóa) comment vi phạm. |

**BR-CMT-01:** comment gắn ở Lesson & Quiz; ở cấp Course chỉ có **Rating** (không comment).

### 7.14 Notification (`NTF`)
**Actors:** tất cả role.

| ID | Requirement |
|---|---|
| FR-NTF-01 | **Realtime in-app notification** qua **WebSocket**; xem & đánh dấu đã đọc. |
| FR-NTF-02 | Trigger cho **Learner**: mua thành công, Course cập nhật, reply comment. |
| FR-NTF-03 | Trigger cho **Trainer**: có người enroll, có comment, Course/Exam được duyệt/từ chối, Statement cần confirm. |
| FR-NTF-04 | Gửi **email** cho sự kiện quan trọng (OTP verify, reset password, mua thành công, duyệt Trainer). |

---

## 8. Global Business Rules

- **BR-G01 — One account, one primary role:** riêng Trainer có Learner mode qua UI switch; không tạo tài khoản thứ hai.
- **BR-G02 — First course free:** Course đầu tiên của mỗi Trainer bắt buộc miễn phí.
- **BR-G03 — Revenue split:** Professional 70/30, Peer Tutor 60/40, theo TrainerType.
- **BR-G04 — Two-step governance:** nội dung qua Course Manager review trước khi Published.
- **BR-G05 — Presentation-only review:** Course Manager không đánh giá chuyên môn; trách nhiệm học thuật thuộc Trainer.
- **BR-G06 — Content ownership:** chỉ owner (Trainer) được sửa Course/Question.
- **BR-G07 — Quiz vs Exam sourcing:** Quiz dùng Question Bank (tái sử dụng); Exam dùng câu hỏi riêng (khóa theo Exam).
- **BR-G08 — Unlimited attempts:** Quiz & Exam làm lại không giới hạn; lưu toàn bộ attempt.
- **BR-G09 — AI is draft-only:** đầu ra AI cần Trainer duyệt/sửa trước khi publish.
- **BR-G10 — Re-approval + versioning:** sửa Course/Exam đã Published tạo version mới cần duyệt lại; bản live giữ nguyên (§9.7).
- **BR-G11 — Separation of duties:** Course Manager không cầm tiền; Admin quản lý & chi trả doanh thu.

---

## 9. Vòng đời, State Machines & Versioning

### 9.1 Account
```
Guest --Register+OTP--> Learner
Guest/Learner --Apply+Admin Approve--> Trainer
Learner/Trainer --Admin lock--> Locked --Unlock--> (previous role)
```

### 9.2 Trainer Application
```
Draft --Submit--> Submitted --Approve--> Approved(→Trainer)
                              --Reject--> Rejected --Resubmit--> Submitted
```

### 9.3 Course (theo từng version — §9.7)
```
Draft --Submit--> Submitted --Reject--> Rejected --Edit--> Draft
                              --Approve--> Approved --Publish--> Published
Published --Edit--> [version mới: Draft → ... → Published, live pointer chuyển]
Published --Unpublish/Archive--> Archived
```

### 9.4 Exam
```
(Trainer)   Draft --Submit--> Submitted --Approve--> Approved --Publish--> Published --Archive--> Archived
(CourseMgr) Draft --Publish(self)--> Published --Archive--> Archived
```

### 9.5 Order (VNPay)
```
Pending --IPN success--> Paid --enroll done--> Completed
Pending --IPN fail/timeout--> Failed
```

### 9.6 Monthly Statement
```
Generated --Trainer confirm--> TrainerConfirmed --Admin transfer+record--> Paid
```

### 9.7 Versioning (Course & Exam)
- Tách **identity** (Course/Exam — thứ Learner enroll/tham chiếu) khỏi **version** (nội dung sửa được, có lifecycle riêng).
- Mỗi identity có nhiều version; `CurrentPublishedVersion` trỏ tới version đang live.
- Sửa nội dung đã Published:
```
1. Trainer sửa → tạo VersionMới = clone version live, status = Draft
2. VersionMới: Draft → Submit → Review → (Reject↺ / Approve → Publish)
3. Khi VersionMới Published → live pointer chuyển, version cũ Archived
* Suốt 1–2, Learner vẫn học version live cũ, không gián đoạn.
```
- Section/Lesson/Quiz & Exam Questions thuộc về **một version**.

---

## 10. Cross-module Workflows

### 10.1 Trainer Onboarding → First Course
```
Guest/Learner → Submit Application (+bank info) → Upload Documents → Admin Review
→ Approve → Trainer Activated → Create First (Free) Course → Submit
→ Course Manager Review → Publish
```

### 10.2 Course Authoring → Learning
```
Trainer: Create Course (chọn ≤3 SkillType) → Sections → Lessons (LessonBlock) → Quiz
→ Submit → Course Manager Review → Approve → Publish
→ Learner: Enroll/Purchase → học tuần tự Lesson → Quiz Attempt → Progress → Rate Course
```

### 10.3 Exam → Recommendation
```
Trainer/Course Manager: Create Exam → Exam Questions → Publish
→ Learner: Attempt (40 câu/50 phút, timer) → Auto Grade (thang 10)
→ Weakness Analysis (SkillType) → Rule-based + AI Recommendation → AI Learning Pathway
```

### 10.4 Payment (VNPay pay-in) → Settlement
```
Learner: Purchase → tạo Order (Pending) → redirect VNPay payment URL → thanh toán
→ VNPay gọi IPN → backend verify checksum + amount → Order = Paid (idempotent) → auto-enroll
→ auto RevenueRecord (split theo TrainerType)
--- cuối kỳ ---
Admin: auto-generate Monthly Statement → Trainer Confirm
→ Admin chuyển khoản thủ công → record transfer → Statement = Paid
```

---

## 11. AI Features

> Phần AI đã được tích hợp; dưới đây mô tả **chức năng**, không mô tả cách tích hợp kỹ thuật.

| Nhóm | Chức năng | Người dùng | Ghi chú |
|---|---|---|---|
| Learning Assistant | Explain Concept / Question / Answer, Answer Learning Questions | Learner | Hỗ trợ trong lúc học & sau khi làm bài |
| Content Generation | Generate Quiz-Question, Generate Explanation | Trainer | Bản nháp — Trainer duyệt/sửa |
| Recommendation | AI Recommendation, AI Learning Pathway | Hệ thống (cho Learner) | Dựa trên Weakness Analysis + SkillType của Course |
| Monitoring | AI Usage log & dashboard | Admin | Đếm lượt/token/chi phí |

**Ràng buộc:** v1 không giới hạn hạn mức; mọi lượt gọi được log.

---

## 12. Conceptual Data Model

> Mức **conceptual** để tham chiếu & làm rõ nghiệp vụ (schema MySQL đã triển khai là nguồn chính thức về cột cụ thể). Mọi bảng ngầm định có `CreatedAt`, `UpdatedAt`.

### 12.1 Identity
- **User** — `UserID`, `Email (unique)`, `PasswordHash`, `FullName`, `Phone`, `AvatarURL`, `Role`, `Status`, `IsVerified`
- **TrainerProfile** — `TrainerID (→User)`, `TrainerType`, `RevenueShareRate`, `Bio`, `BrandName`, `BankInfo`
- **TrainerApplication** — `ApplicationID`, `UserID`, `TrainerType`, `Phone`, `NationalID?`, `BankInfo`, `Documents`, `Status`, `ReviewedBy`, `ReviewNote`

### 12.2 Course Structure (versioned)
- **Course** *(identity)* — `CourseID`, `TrainerID`, `CategoryID`, `CurrentPublishedVersionID?`, `OverallStatus`
- **CourseVersion** — `CourseVersionID`, `CourseID`, `VersionNumber`, `Title`, `Description`, `ThumbnailURL`, `Price`, `IsFirstFree`, `Status`, `ReviewedBy?`, `PublishedAt`
- **CourseSkillType** — `CourseID`, `SkillType` *(tối đa 3/Course)*
- **Category** — `CategoryID`, `Name` · **Tag** — `TagID`, `Name` · **CourseTag** — `CourseID`, `TagID`
- **Section** — `SectionID`, `CourseVersionID`, `Title`, `OrderIndex`
- **Lesson** — `LessonID`, `SectionID`, `Title`, `OrderIndex`
- **LessonBlock** — `BlockID`, `LessonID`, `BlockType` (Text/Video/PDF/Image), `Content` / `MediaURL` (Cloudinary), `OrderIndex`

### 12.3 Learning
- **Enrollment** — `EnrollmentID`, `LearnerID`, `CourseID`, `EnrolledAt`, `Source` (Free/Purchase), `Status`
- **LessonProgress** — `ProgressID`, `LearnerID`, `LessonID`, `IsCompleted`, `LastPosition`, `CompletedAt`
- **Review** — `ReviewID`, `LearnerID`, `CourseID`, `Rating (1–5)`, `Comment` — *unique (LearnerID, CourseID)*
- **Comment** — `CommentID`, `TargetType` (Lesson/Quiz), `TargetID`, `UserID`, `ParentCommentID?`, `Content`, `Status`

### 12.4 Assessment
- **Quiz** — `QuizID`, `LessonID`, `Title`
- **QuizQuestion** — `QuizID`, `QuestionID`, `OrderIndex`
- **QuestionGroup** — `QuestionGroupID`, `TrainerID`, `Visibility`, `GroupType?`, `SharedContent`
- **Question** — `QuestionID`, `QuestionGroupID?`, `TrainerID`, `ExamVersionID?`, `Visibility`, `SkillType`, `GroupType?`, `QuestionType` (SingleChoice), `Difficulty`, `Content`, `Explanation`, `CorrectAnswer`
- **Option** — `OptionID`, `QuestionID`, `Content`, `IsCorrect`
- **Exam** *(identity)* — `ExamID`, `CreatedBy`, `CurrentPublishedVersionID?`, `OverallStatus`
- **ExamVersion** — `ExamVersionID`, `ExamID`, `VersionNumber`, `Title`, `TotalQuestions (40)`, `DurationMinutes (50)`, `MaxScore (10)`, `Status`, `PublishedAt`
- **QuizAttempt** — `AttemptID`, `LearnerID`, `QuizID`, `AttemptNumber`, `Score`, `SubmittedAt`
- **ExamAttempt** — `AttemptID`, `LearnerID`, `ExamVersionID`, `AttemptNumber`, `Score`, `StartedAt`, `SubmittedAt`
- **AttemptAnswer** — `AnswerID`, `AttemptID`, `AttemptKind`, `QuestionID`, `SelectedOption`, `IsCorrect`

> Câu hỏi Exam gắn `ExamVersionID` + `Visibility=Private` (khóa vào version, không tái sử dụng).

### 12.5 Recommendation
- **WeaknessAnalysis** — `AnalysisID`, `ExamAttemptID`, `LearnerID`, `SkillType`, `CorrectCount`, `TotalCount`, `Score`
- **Recommendation** — `RecommendationID`, `LearnerID`, `ExamAttemptID`, `RecommendedCourseIDs`, `AISuggestion`, `LearningPathway`

### 12.6 Payment & Revenue
- **Order** — `OrderID`, `LearnerID`, `CourseID`, `Amount (VND)`, `Status`, `VnpayTxnRef`, `VnpayTransactionNo`
- **RevenueRecord** — `RevenueID`, `OrderID`, `TrainerID`, `CourseID`, `GrossAmount`, `TrainerShare`, `PlatformShare`, `Period`
- **MonthlyStatement** — `StatementID`, `TrainerID`, `Period`, `TotalGross`, `TrainerAmount`, `Status`, `ConfirmedAt`, `TransferRef`

### 12.7 Platform Services
- **Notification** — `NotificationID`, `UserID`, `Type`, `Content`, `IsRead`
- **AIUsageLog** — `LogID`, `UserID`, `Feature`, `TokensUsed`, `Cost`
- **AuditLog** — `LogID`, `ActorID`, `Action`, `TargetType`, `TargetID`, `Timestamp`

### 12.8 Quan hệ chính (text)
```
User 1—1 TrainerProfile ; User 1—* TrainerApplication
User(Trainer) 1—* Course 1—* CourseVersion 1—* Section 1—* Lesson 1—* LessonBlock
Course 1—* CourseSkillType (≤3) ; Lesson 1—* Quiz *—* Question 1—* Option
Exam 1—* ExamVersion 1—* Question
User(Learner) 1—* Enrollment *—1 Course
User(Learner) 1—* ExamAttempt *—1 ExamVersion 1—* WeaknessAnalysis
ExamAttempt 1—1 Recommendation
User(Learner) 1—* Order 1—1 RevenueRecord
TrainerProfile 1—* MonthlyStatement
Comment: TargetType(Lesson|Quiz)
```

---

## 13. Enums tổng hợp

| Enum | Giá trị |
|---|---|
| Role | Learner · Trainer · CourseManager · Administrator |
| ActiveMode *(Trainer UI)* | TrainerMode · LearnerMode |
| TrainerType | Professional · PeerTutor |
| AccountStatus | Active · Locked |
| ApplicationStatus | Draft · Submitted · Approved · Rejected |
| CourseVersionStatus | Draft · Submitted · Rejected · Approved · Published · Archived |
| CourseOverallStatus | HasDraft · Published · Archived |
| ExamVersionStatus | Draft · Submitted · Approved · Published · Archived |
| LessonBlockType | Text · Video · PDF · Image |
| QuestionType | SingleChoice |
| Difficulty | Easy · Medium · Hard |
| Visibility | Public · Private |
| SkillType | Conversation/Short Sentences · Synonym · Antonym · Pronunciation · Grammar · Sentence Meaning · Sentence Combining · Fill in Blank · Reading Comprehension · Arrangement |
| GroupType (nullable, v1 dùng cho Exam) | Notice Completion · Flyer Completion · Passage Arrangement · Information Gap Filling · Reading Comprehension |
| OrderStatus | Pending · Paid · Completed · Failed |
| StatementStatus | Generated · TrainerConfirmed · Paid |
| CommentTargetType | Lesson · Quiz |
| CommentStatus | Visible · Hidden |
| NotificationType | PurchaseSuccess · CourseUpdated · CommentReply · NewEnrollment · ContentApproved · ContentRejected · StatementReady |

---

## 14. Non-Functional Requirements

- **NFR-01 Security:** mật khẩu hash (bcrypt/argon2); auth JWT (access+refresh); RBAC ở mọi API; verify checksum VNPay; chống OWASP Top 10.
- **NFR-02 Privacy:** CCCD/minh chứng/bank info lưu an toàn, chỉ Admin xem.
- **NFR-03 Payment integrity:** IPN idempotent (chống IPN trùng); đối chiếu amount; xử lý business logic ở server, không ở return URL.
- **NFR-04 Performance:** danh sách phản hồi nhanh, có phân trang; media qua CDN Cloudinary.
- **NFR-05 Realtime:** notification đẩy qua WebSocket.
- **NFR-06 Reliability:** Exam timer + auto-submit chính xác; auto-grade nhất quán.
- **NFR-07 Auditability:** log hành động quản trị (approve/publish/payment) & AI usage.
- **NFR-08 Language/UI:** toàn bộ giao diện **Tiếng Anh** (English mặc định, không đa ngôn ngữ v1); web (Flutter Web), hướng responsive.
- **NFR-09 Config:** kỳ chốt doanh thu **cấu hình được** (phục vụ test), không hard-code.

---

## 15. Decision Log & Future Items

### 15.1 Đã chốt (v1)

| Vấn đề | Quyết định |
|---|---|
| Client | **Web** (Flutter Web) cho mọi role; app sau |
| Backend / DB | **Java Spring Boot** REST, **MySQL 8.0**, monolith, JWT (access+refresh) |
| Payment / tiền tệ | **VNPay**, **VND**; pay-in auto, payout thủ công |
| Media storage | **Cloudinary** |
| Email verify | **Bắt buộc**, qua **OTP** |
| Sửa nội dung đã Published | Duyệt lại + **versioning** |
| Trainer học/mua Course khác | **Có** — Learner mode qua UI switch |
| Exam | THPTQG mới nhất: **40 câu / 50 phút / thang 10**, timer + auto-submit |
| Quiz | không giới hạn giờ, chưa có pass-score |
| SkillType / GroupType | enum cố định; v1 tập trung **SkillType**; GroupType chỉ cho Exam |
| Course tagging | Trainer chọn **≤3 SkillType** → dùng cho AI gợi ý & pathway |
| Định giá | backend gợi ý tier (300k/500k/700k), **Trainer chốt** |
| Learning | tuần tự theo **Lesson**; truy cập trọn đời |
| Rate Course | **1 lần** / Learner / Course |
| Comment | ở **Lesson & Quiz**; Course chỉ Rating; moderation = **Admin** |
| Notification | **realtime WebSocket** + email; có cho cả Trainer |
| Import | **Excel (.xlsx)** |
| Retake | không giới hạn |
| Doanh thu | Admin quản lý & chi trả; kỳ theo tháng (Asia/Ho_Chi_Minh), **cấu hình được** |
| UI language | **English** |
| Audit log | có (mức cơ bản) |

### 15.2 Future phase (ngoài v1)

Mobile app; refund policy & auto-payout; AI usage limit & cost model; pass-score cho Quiz; GroupType trong course-authoring & analytics; đa ngôn ngữ giao diện; công thức price-tier chi tiết; role Finance riêng.

---

*Hết tài liệu — HanGo Project Documentation v3.0.*
