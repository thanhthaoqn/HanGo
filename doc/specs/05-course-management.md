# Feature Specification: FE-05 — Course Management

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.5 (CRS), §9.3/§9.7 (versioning). Section/Lesson/Quiz **content** authoring is a separate module — see [06-course-content-management.md](06-course-content-management.md) (FE-06/CNT). This spec covers Course **metadata + governance workflow** only.

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
