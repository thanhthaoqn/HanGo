# Feature Specification: FE-05 — Course Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.5 (CRS), §9.3/§9.7 (versioning). Section/Lesson/Quiz **content** authoring is a separate module — see [06-course-content-management.md](06-course-content-management.md) (FE-06/CNT). This spec covers Course **metadata + governance workflow** only.

> ⚠️ **Cập nhật 2026-07-24 để khớp code đã triển khai** (đã tự viết + chạy test trực tiếp trên `CourseManagerDashboardServiceImpl` trong đợt audit này — xem `TEST_AUDIT_REPORT.md`): review workflow **đã được implement**, khác với báo cáo QA trước đó (`qa-report-for-dev-team.md`, 2026-07-19) từng ghi nhận là "chưa có". Thực tế:
> - **Không có** bảng `course_versions` riêng hay cột `current_published_version_id` như §3 mô tả. Versioning thật dựa trên `Course.parentId`/`Course.latestVersionId` (plain `Long`, không phải JPA relation) trên chính bảng `courses` — mỗi version là 1 row `Course` riêng, liên kết qua `parentId`/`code` thay vì qua bảng version tách biệt.
> - **Review API thật:** `GET /api/v1/course-manager/courses/review`, `GET /api/v1/course-manager/courses/{id}/review-detail`, `POST /api/v1/course-manager/courses/{id}/publish`, `POST /api/v1/course-manager/courses/{id}/reject` — không phải `PUT /api/admin/courses/{id}/review` như §2 liệt kê.
> - `CourseServiceImpl.switchCourseVersion`/`getCourseVersionHistory` (learner-facing) đã tồn tại trong code nhưng **chưa có unit test** tính đến 2026-07-24 — xem `TEST_AUDIT_REPORT.md` mục còn thiếu.
> - **Rủi ro đã phát hiện:** có 2 luồng approve/reject riêng biệt cho Course (`TrainerDashboardServiceImpl.approveTrainerCourse`/`rejectTrainerCourseDraft` và `CourseManagerDashboardServiceImpl.publishCourse`/`returnCourseToDraft`) với status và notification khác nhau — xem `AUDIT_REPORT.md` HIGH-04 trước khi coi 2 luồng này là tương đương.

## 1. Business Context
Course Management covers discovery (browse/search/filter by SkillType, price, rating), Trainer authoring of Course **metadata** (title, description, thumbnail, up to **3 SkillTypes** — BR-CRS-04), and the **review/publish workflow** governed by the Course Manager. The backend suggests a price tier (300k/500k/700k VND) from course scale, but the **Trainer sets the final price** (≥0) — FR-CRS-06. Course Manager review is **presentation-only** (template, structure completeness, policy) — never a content/academic review (BR-CRS-01/02); if content needs to change, Course Manager must Reject, not edit. Editing an already-**Published** Course creates a **new version** that goes through Draft → Submit → Review again; the live version keeps serving Learners unchanged until the new version is published (BR-CRS-03, §9.7).

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Course discovery UI: browse/search/filter by SkillType, price, rating, category.
- [ ] Trainer Course creation/edit form: title, description, thumbnail, **select up to 3 SkillTypes**, price (pre-filled with the backend-suggested tier, editable).
- [ ] Trainer "Submit for Review" action; status badge (Draft/Submitted/Rejected/Approved/Published/Archived).
- [ ] Course Manager review queue: Approve/Reject (with reason)/Publish/Unpublish; publish history view.
- [ ] Editing a Published course visibly creates a new Draft version while the live version stays servable to enrolled Learners.

**Backend (Spring Boot):**
- [ ] APIs for Course Discovery (`GET /api/v1/courses`, pagination + filters).
- [ ] Trainer CRUD (`POST /api/v1/courses`, `PUT /api/v1/courses/{id}`) — metadata only; a `POST /api/v1/courses/{id}/submit` moves Draft → Submitted.
- [ ] `CourseService` price-tier suggestion (from Lesson count, Quiz count, video duration) — Trainer can always override (FR-CRS-06).
- [ ] Course Manager review APIs (`PUT /api/v1/admin/courses/{id}/review` approve/reject, `PUT .../publish`, `PUT .../unpublish`).
- [ ] Versioning: editing a Published course clones the live version into a new Draft version (`CourseVersionStatus`); on publish, the live pointer switches and the old version is Archived — never overwritten in place.
- [ ] Integrate Cloudinary API to handle Thumbnail image upload.

## 3. Technical Constraints
- **Database Consistency:** Course identity and Course version are separate entities (`courses` vs `course_versions`); `current_published_version_id` tracks the live pointer.
- **Transaction Management:** Version-clone-on-edit must be wrapped in `@Transactional` to ensure atomicity.
- **SkillType cap:** Enforce max 3 SkillTypes per Course at both DTO validation and DB constraint level (BR-CRS-04) — used for filtering and AI recommendation matching.

## 4. Edge Cases
- **Double Submit:** Prevent users from spam-clicking "Submit for Review"; disable the button during the API call.
- **Concurrent Editing:** If two sessions attempt to edit the same Draft version simultaneously, implement Optimistic Locking (`@Version` in JPA).
- **Empty Course Structure:** Validate that a Course version has at least one Section and one Lesson before allowing Submit (FR-CRS-09 depends on FE-06 content existing).
- **Editing a Published course while Learners are actively enrolled:** Learners must keep seeing the old live version uninterrupted until the new version is Published (§9.7).

## 5. Non-functional Requirements
- **Data Integrity:** Ensure Course ↔ CourseVersion ↔ Section/Lesson hierarchy is mapped via DTOs (never expose `@Entity` directly) to avoid circular-reference issues.
