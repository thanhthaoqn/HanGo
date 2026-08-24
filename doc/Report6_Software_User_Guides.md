# CAPSTONE PROJECT REPORT
## Report 6 – Software User Guides
### Project: HanGo — Smart Language Self-Study Platform

*(Compiled from the current `dev`/`fix-code-v2` codebase — see [`doc/HanGo_Documentation.md`](HanGo_Documentation.md) for the full functional specification this guide summarizes.)*

---

## Table of Contents

- [I. Record of Changes](#i-record-of-changes)
- [II. Release Package \& User Guides](#ii-release-package--user-guides)
  - [1. Deliverable Package](#1-deliverable-package)
  - [2. Installation Guides](#2-installation-guides)
    - [2.1 System Requirements](#21-system-requirements)
    - [2.2 Installation Instructions](#22-installation-instructions)
  - [3. User Manual](#3-user-manual)
    - [3.1 Overview](#31-overview)
    - [3.2 Trainer Onboarding Workflow](#32-trainer-onboarding-workflow)
    - [3.3 Course Creation \& Approval Workflow](#33-course-creation--approval-workflow)
    - [3.4 Entry Exam \& AI Recommendation Workflow](#34-entry-exam--ai-recommendation-workflow)
    - [3.5 User Learning Workflow](#35-user-learning-workflow)

---

## I. Record of Changes

| Date | A/M/D* | In charge | Change Description |
|---|---|---|---|
| 12/08/2026 | A | Pham Minh Duc | Initiate document |
| 12/08/2026 | A | Pham Minh Duc | Add II. Release Package & User Guides (Deliverable Package, Installation Guides) |
| 12/08/2026 | A | Pham Minh Duc | Add 3.2 Course Creation & Approval Workflow, 3.3 User Learning Workflow |
| 12/08/2026 | M | Pham Minh Duc | Corrected 3.2/3.3 against direct source verification (course-creation entry point, price field, reject gating) |
| 12/08/2026 | A | Pham Minh Duc | Add 3.2 Trainer Onboarding Workflow and 3.4 Entry Exam & AI Recommendation Workflow; renumbered subsequent sections |

*A – Added · M – Modified · D – Deleted*

---

## II. Release Package & User Guides

### 1. Deliverable Package

| No | Deliverable Item | Sub-items | Type | Version |
|---|---|---|---|---|
| **Code Package** | | | | |
| 1 | Backend | `hango-backend/` (Java 17, Spring Boot 4.0.6) | source | 1.0 |
| 2 | Frontend | `hango-frontend/` (Flutter, Dart `^3.12.0`, Web target) | source | 1.0 |
| **Database** | | | | |
| 3 | Database scripts | `hango-backend/db/*.sql` (schema managed via Hibernate; `ddl-auto=validate` in production) | sql | 1.0 |
| **Documents** | | | | |
| 4 | Project Documentation | `doc/HanGo_Documentation.md` — single source of truth (business + functional + conceptual model) | md | 2.0 |
| 5 | System Architecture | `doc/ARCHITECTURE.md` | md | 1.0 |
| 6 | Security & Coding Constitution | `doc/CONSTITUTION.md` | md | 1.0 |
| 7 | Deployment Guide | `DEPLOY_GUIDE.md` (AWS EC2 + Docker Compose + Nginx + GitHub Actions CI/CD) | md | 1.0 |
| 8 | Weekly Progress Reports | `doc/weekly-reports.md` | md | 1.0 |
| 9 | Software User Guide | `doc/Report6_Software_User_Guides.md` (this document) | md | 1.0 |
| **Testing** | | | | |
| 10 | Testing Strategy | `doc/test_doc/TESTING.md` | md | 1.0 |
| 11 | Unit Test Plan | `doc/test_doc/unit_test_plan.md` + `hango-backend/src/test/java/...` | md/java | 1.0 |
| 12 | Integration Test Plan | `doc/test_doc/integration_test_plan.md` + `doc/test_doc/itc-sheet-*.csv` (17 module sheets) | md/csv | 2.0 |
| 13 | System Test Plan | `doc/test_doc/system_test_plan.md` + `doc/test_doc/sys-sheet-*.csv` (13 end-to-end workflow sheets) | md/csv | 1.0 |
| **Feature Roadmap** | | | | |
| 14 | Feature Implementation Status | `TODO.md` (checklist across the 19 functional modules) | md | 1.0 |

> HanGo is developed as a single monorepo (`hango-backend/` + `hango-frontend/` + `doc/` in one Git repository), rather than separate Frontend/Backend repositories.

---

### 2. Installation Guides

#### 2.1 System Requirements

**Minimum Software Requirements:**
- Operating System: Windows 10/11, macOS, or Linux (64-bit) — the stack (Java, Flutter, MySQL) is cross-platform; this guide uses Windows commands where they differ.
- Architecture: 64-bit (x64) required.

**Minimum Hardware Requirements:**
- CPU: Intel Core i5 / AMD Ryzen 5 or equivalent (4 cores+).
- RAM: 8 GB (16 GB recommended, since the JVM, MySQL, and Flutter web build all run locally at once).
- Free Disk Space: 15 GB minimum (SSD recommended).
- Stable internet connection (required for Gradle/Maven/pub dependency downloads and calling Cloudinary/Gemini/PayOS/Gmail SMTP).

**Required Accounts / External Services (all configured through `application.properties`):**
- MySQL 8.0 server instance.
- Cloudinary account (media hosting for lesson video/PDF/image, avatars, Trainer verification documents).
- Google Cloud project with an OAuth 2.0 Client ID (Google Sign-In) and access to the **Gemini** API (AI Assistant, AI Recommendation, AI Learning Pathway).
- Gmail account with an **App Password** (SMTP, used for OTP/verification/notification emails).
- PayOS merchant account (sandbox is sufficient for local testing) — client ID, API key, checksum key.
- GitHub account (repository access, CI/CD via GitHub Actions).

#### 2.2 Installation Instructions

##### 2.2.1 Required Tools Installation

**STEP 1: Install Git**
1. Download from: https://git-scm.com/downloads
2. Run the installer.
3. Verify: `git --version`

**STEP 2: Install Java 17 JDK**
1. Download a JDK 17 distribution (e.g. Eclipse Temurin 17).
2. Install it and set `JAVA_HOME`.
3. Verify: `java -version` (the backend targets `java.version=17` in `hango-backend/pom.xml`; a Maven wrapper `mvnw`/`mvnw.cmd` is included, so a separate Maven install is optional).

**STEP 3: Install MySQL 8.0**
1. Download from: https://dev.mysql.com/downloads/mysql/
2. Run the installer and remember the password set for the `root`/admin user.
3. Verify: `mysql --version`

**STEP 4: Install Flutter SDK**
1. Download from: https://docs.flutter.dev/get-started/install (Dart SDK `^3.12.0`, per `hango-frontend/pubspec.yaml`).
2. Add the `flutter/bin` folder to your PATH.
3. Verify: `flutter doctor` (make sure Chrome is detected, since HanGo's frontend targets **Web** in v1).

**STEP 5: Install Visual Studio Code (recommended)**
1. Download from: https://code.visualstudio.com/
2. Install the Flutter, Dart, and Java extension packs.

**STEP 6: Clone the Repository**
```bash
git clone https://github.com/thanhthaoqn/HanGo.git
cd HanGo
```
This single repository contains both `hango-backend/` and `hango-frontend/`.

##### 2.2.2 Backend Setup (Spring Boot)

**STEP 1: Create the MySQL Database**
```sql
CREATE DATABASE hango_db;
```

**STEP 2: Configure Environment**
1. Navigate to `hango-backend/src/main/resources`.
2. Copy the example config file:
   ```bash
   cp application.properties.example application.properties
   ```
3. Edit `application.properties` and fill in real values for:
   - `spring.datasource.username` / `spring.datasource.password` — your MySQL credentials.
   - `hango.jwt.secret` — any long random string.
   - `cloudinary.cloud-name` / `cloudinary.api-key` / `cloudinary.api-secret` — from your Cloudinary dashboard.
   - `google.client-id` — from Google Cloud Console (OAuth 2.0 Client ID).
   - `spring.mail.username` / `spring.mail.password` — a Gmail address and its App Password.
   - `payos.client-id` / `payos.api-key` / `payos.checksum-key` — from your PayOS merchant dashboard.
4. On the **first run only**, temporarily set `spring.jpa.hibernate.ddl-auto=update` so Hibernate creates the schema from the JPA entities (the committed default is `validate`, which requires the schema to already exist — there is no Flyway/Liquibase migration tool in this project yet). Switch it back to `validate` after the first successful startup.

**STEP 3: Run the Backend**
```bash
cd hango-backend
# Windows
mvnw.cmd spring-boot:run
# macOS/Linux
./mvnw spring-boot:run
```
The API starts at `http://localhost:8080` (base paths `/api/auth`, `/api/v1/...`).

##### 2.2.3 Frontend Setup (Flutter)

**STEP 1: Install Dependencies**
```bash
cd hango-frontend
flutter pub get
```

**STEP 2: Run the App**
```bash
flutter run -d chrome
```
The frontend's default API base URL is `http://localhost:8080` (see `hango-frontend/lib/utils/config.dart`), matching the backend's default port, so no extra configuration is needed for a local run.

---

### 3. User Manual

#### 3.1 Overview

**HanGo (Smart Language Self-Study Platform)** is a Learning Management System focused on learning and reviewing for the **Vietnamese national high-school English exam (THPT Quốc Gia)**. It combines three layers in one platform:

- **LMS** — course content and learning-progress management.
- **Course Marketplace** — Trainers author and publish Courses; Learners browse, purchase, and study them.
- **AI-powered learning** — an in-lesson AI Assistant, AI-generated Course recommendations, and an AI Learning Pathway after Exam attempts.

HanGo itself does not produce learning content — it connects **Trainers** (who author Courses/Exams) with **Learners** (who study them), with quality gated by a **Course Manager** review step before content goes live. There are four roles in the system:

| Role | Purpose |
|---|---|
| **Learner** | Browses/purchases/enrolls in Courses, studies Lessons, takes Quizzes/Exams, receives AI recommendations, rates Courses. |
| **Trainer** | Authors Courses/Sections/Lessons/Quizzes, manages a Question Bank, authors Exams, tracks revenue. A Trainer account also has a **Learner mode** to study other Trainers' Courses. |
| **Course Manager** | Reviews and publishes/rejects/hides Course and Exam submissions, manages Exam Matrices, handles support tickets, and settles Trainer revenue. |
| **Administrator** | Manages accounts, roles & permissions, reviews Trainer applications, moderates comments, and monitors the platform dashboard / AI usage / audit log. |

The walkthroughs below cover the platform's central journeys: becoming a Trainer (§3.2), authoring a Course through to publication (§3.3), taking the Entry Exam to receive an AI recommendation (§3.4), and enrolling in and completing a Course (§3.5).

---

#### 3.2 Trainer Onboarding Workflow

> A Trainer account is granted **immediately** on choosing this path — Admin review only gates the ability to **publish/sell** a Course later, not access to the Trainer Dashboard itself (see `doc/HanGo_Documentation.md` §7.5, BR-TRN-01).

**Step 1: Start Onboarding (Learner)**

**Step 1.1 — Choose the Trainer Path**
- Either toggle **"Trainer"** (instead of "Learner") on the **Register** screen when creating a new account, or, as an existing Learner, open the **Home** screen and click the **"Become a Trainer"** call-to-action.

*(Screenshot: Register screen — Learner/Trainer toggle)*
*(Screenshot: Home screen — Become a Trainer banner)*

**Step 1.2 — Choose a Teaching Type**
- On the **"Teach on HanGo"** screen, choose one of two cards: **"Teacher"** (for school/university teachers or exam-center lecturers with formal degrees; 70/30 revenue split) or **"Tutor"** (for students/teaching assistants/peers with a strong THPT QG score or IELTS result; 60/40 revenue split).
- Click **"Proceed with profile"**. A toast confirms **"Trainer role initialized successfully!"** — the Trainer role is granted at this point, before any review.

*(Screenshot: Teach on HanGo screen — Teacher / Tutor selection)*

**Step 2: Complete the Application**

**Step 2.1 — Review & Sign the Agreement**
- On the **"System Rules & Policies"** screen, scroll through the three articles (Revenue Share & Settlement, First Course Free Policy, Content Copyrights & Compliance) to the bottom — this unlocks the **"Continue to Profile"** button.

*(Screenshot: System Rules & Policies screen)*

**Step 2.2 — Fill in the Teaching Profile**
- On the **"Complete Teaching Profile"** screen, fill in:
  - **1. Personal Information** — upload an avatar, select **Gender**, and enter a **Contact Phone Number** (Vietnamese format).
  - **2. Bio** — a personal introduction field (minimum 50 characters).
  - **3. Degrees & Certificates** — click **"Add Degree & Certificate"** to upload at least one credential (a Teacher application specifically requires a pedagogical degree/teaching certificate; a Tutor application accepts transcripts, English certificates, or competition awards).
- Click **"Submit Application for Review"**. A toast confirms **"Application submitted for review successfully!"**, and the status screen now shows **"Application Under Review"**.

*(Screenshot: Complete Teaching Profile screen)*

**Step 3: Admin Review (Administrator)**

**Step 3.1 — Review the Application**
- Log in as an **Administrator** and open the Trainer Applications list, filterable by **"All Applications"**, **"Awaiting Review"**, **"Approved Applications"**, and **"Rejected Applications"**.
- Open an application under **"Awaiting Review"** to see the Trainer's bio, phone, and uploaded credentials.

*(Screenshot: Admin — Trainer Applications list)*

**Step 3.2 — Approve or Reject**
- Click **"Approve Application"** to confirm (the revenue-share rate defaults to 70% for Teacher / 60% for Tutor and can be overridden), which sets the profile to **VERIFIED**.
- Or click **"Reject Application"**, enter a note on the Bio and/or Certificates explaining what needs fixing, and submit — the Trainer can then revise and resubmit (repeating Step 2.2).

*(Screenshot: Admin — Approve/Reject Application actions)*

**Step 4: Finish Setup (Trainer)**

**Step 4.1 — Set Up Payout**
- Once VERIFIED, the Trainer's status screen shows **"Application Approved!"** with a **"Setup Payout"** action (the Agreement is already signed from Step 2.1).
- Fill in **Beneficiary Bank Name**, **Bank Account Number**, **Account Owner Name** (uppercase), and **Tax Identification Number**, then click **"Complete Setup"**.
- A toast confirms **"Payout details saved successfully! Welcome to your Trainer Dashboard."** and the Trainer lands on their **Trainer Dashboard**, now able to build and submit Courses (§3.3) — though **publishing/selling** still requires the profile to be VERIFIED, which it now is.

*(Screenshot: Setup Payout screen)*
*(Screenshot: Trainer Dashboard screen)*

---

#### 3.3 Course Creation & Approval Workflow

**Step 1: Course Creation (Trainer)**

**Step 1.1 — Access Course Management**
- Log in as a **Trainer** whose profile has been **verified** by an Administrator (§3.2 — an unverified Trainer can still build Draft content but cannot submit it for review).
- On the left sidebar, select **"Courses"** — this opens the **Course Management** page.

*(Screenshot: Trainer Dashboard — Course Management screen)*

> A plain Trainer account has no "create a blank course" button anywhere in the UI — the **Course Management** page only offers **"Download Template"** and **"Import Excel"**. The only way a Trainer creates a new course is the Excel bulk-import path below; a Course Manager/Admin account additionally has a manual "Create Course" form of its own (out of scope for this Trainer-focused walkthrough).

**Step 1.2 — Create the Initial Draft via Excel Import**
- Click **"Download Template"** to get `Hango_Course_Import_Template.xlsx`.
- Fill in the Sections/Lessons (and Questions, if desired) rows.
- Click **"Import Excel"** and select the completed file.

*(Screenshot: Course Management screen — Download Template / Import Excel buttons)*

- An **"Import Successful"** dialog appears (with a note that some formatting issues were auto-resolved); confirm with **"I Understand, Continue"**. A toast reports the imported counts, e.g. *"Imported 1 course, 3 sections, 9 lessons."*
- The new course appears in **Course Management** as a **DRAFT**, regardless of any status written in the sheet.

*(Screenshot: Import Successful dialog)*

**Step 1.3 — Refine Course Metadata (Introduction step)**
- Open the new Draft course to enter **Edit Course**. The left panel lists two steps under "Course Content Management": **"Introduction"** and **"Syllabus"** — Introduction is active first.
- Review/adjust:
  - **Course Name** (required)
  - **Course Code** and **Version** — both read-only/auto-generated, not editable.
  - **System Auto-Price** — a read-only price automatically computed from the Trainer's profile type, Academic Level, Lesson count, and total duration; tap the refresh icon (tooltip *"Refresh system price (Base + Lessons + Duration)"*) to recompute it after adding content (toast: **"Price re-evaluated successfully"**). There is no field to type in a custom price.
  - **Category** (required, single-select dropdown) and **Academic Level** (single-select dropdown).
  - **Description** (required) and **Objectives**.
  - Under **"Course Media"**: **Course Thumbnail** upload.
- If this is the Trainer's very first course, a green banner reads: *"Congratulations! This is your first course. It will automatically be published as a Free course to help you build your student base."*
- Click **"Save"**.

*(Screenshot: Edit Course screen — Introduction step)*

**Step 1.4 — Build the Syllabus (Sections & Lessons)**
- Open the course's **Syllabus** step.
- In the **"NEW SECTION"** form, enter a **Section Name** (Code/Description optional) and click **"Add Section"**. Repeat for every Section needed — Sections are appended in the order created; there is no drag-and-drop reorder, so re-ordering means deleting and re-adding.

*(Screenshot: Edit Course screen — Syllabus step, Add Section form)*

- On a Section card, click the **"Manage Lessons"** icon, then **"Add Lesson"**.
- Choose a Lesson type — **Video** or **Text**:
  - **Text**: enter Lesson Title, Learning Objectives, Estimated Time, and the Markdown body content; optionally attach an image and a PDF (both show an upload-progress indicator).
  - **Video**: enter the Lesson Title and upload a **Video Lecture** file.
- Click **Save**. Repeat for every Lesson in the Section (Lessons are also append-ordered).

*(Screenshot: Add Lesson screen — Text lesson editor)*
*(Screenshot: Add Lesson screen — Video lesson editor)*

> Both the **Section** editor and the **Lesson** editor are reached from this Syllabus step — a Lesson's content-type picker offers three tiles: **Lesson / Text**, **Video / Lecture**, and **Quiz / Test**.

**Step 1.5 — Attach a Quiz to a Lesson (optional)**
- Add a Lesson of type **Quiz**, or open an existing Lesson's quiz editor, and click **"Add from Question Bank"**.
- Select one or more existing single-choice questions from your Question Bank.
- Click **"Save"**/**"Save Changes"**.

*(Screenshot: Lesson Quiz editor — Add from Question Bank)*

**Step 2: Request Approval (Trainer)**

**Step 2.1 — Submit for Review**
- Open the Draft course via **Edit Course**. While the course is in Draft, a **"Progress Overview"** card appears in the left panel with a **"Submit for Review"** button.
- Ensure the course has at least one Section and Lesson (submitting an empty syllabus is blocked with a validation message).
- Click **"Submit for Review"**.

*(Screenshot: Edit Course screen — Progress Overview card, Submit for Review button)*

- A toast confirms **"Course submitted for review successfully!"**; the course's badge changes from yellow **Draft** to blue **Pending Approval** in My Courses, and it now appears in the Course Manager's review queue.

*(Screenshot: My Courses screen — course with Pending Approval badge)*

> If the Trainer's profile is not yet verified, submitting instead opens an **"Approval required"** popup explaining that the Trainer profile must be completed/approved first, and the course stays in Draft.

**Step 3: Approval Review (Course Manager)**

**Step 3.1 — Access the Review Queue**
- Log in as a **Course Manager** (or Administrator).
- On the left sidebar, select **"Courses"**, then open the **"Pending"** tab.

*(Screenshot: Course Manager Dashboard — Courses screen, Pending tab)*

**Step 3.2 — Review the Course**
- Click the submitted course to open its review dialog. The left pane lists every Section/Lesson in the syllabus, with the Lesson content on the right.
- Open **every Lesson** at least once — a banner reads *"Review all lessons to enable publishing."*, and both the **"Publish Course"** and the **"Reject"** buttons stay disabled until every lesson has been viewed.

*(Screenshot: Course Review dialog — syllabus pane and Publish/Reject actions)*

**Step 3.3 — Approve & Publish**
- Once every lesson has been opened, click the now-enabled **"Publish Course"** button, then confirm in the **"Publish course?"** dialog by clicking **"Publish"**.
- A toast confirms **"Course published successfully."**; the course status becomes **PUBLISHED**, moves to the **Published** tab, and the Trainer receives an approval notification.

*(Screenshot: Course Review dialog — Publish confirmation)*

**Step 3.4 — Reject (if the course needs changes)**
- Once every lesson has been opened, click the now-enabled **"Reject"** button to open the **"Rejection Checklist"**.
- Check one or more applicable issue categories — **"General Info (Title, Description, Image)"**, **"Lesson Content (Video, Reading Material)"**, **"Quiz & Assessment"**, **"Other Issues"** — each reveals its own detail text box to describe the problem. At least one category must be checked.
- Click **"Reject"**, then confirm in the **"Return to draft?"** dialog by clicking **"Return"**.
- A toast confirms **"Course returned to draft."**; the Trainer sees the itemized rejection notes on the course in My Courses and is notified; the Trainer edits the course and repeats Step 2.

*(Screenshot: Course Review dialog — Rejection Checklist)*

**Step 3.5 — Hide / Unhide a Published Course**
- Open a Published course in the review dialog and click **"Hide Course"**, then confirm. A toast confirms **"Course hidden successfully."** — already-enrolled Learners keep access via My Learning even while the course is hidden from the public catalog.
- To restore visibility, reopen it and click **"Unhide Course"** (the confirmation dialog labels this action **"Unhide & Publish"**). A toast confirms **"Course unhidden and published successfully."**

*(Screenshot: Course Review dialog — Hide/Unhide actions)*

**Step 4: Editing a Published Course (Versioning)**
- A Trainer editing an already-Published course (via **"Edit / Create New Version"**) does not modify the live version in place. Saving a change creates a new **Draft** version (toast: **"A new draft has been created. You are now editing the draft."**); the course card shows both a green **PUBLISHED** badge and a yellow **Editing Draft** badge.
- The new Draft version repeats Steps 1.3–3.5 (edit metadata/syllabus → Submit → Course Manager review → Publish). Learners already enrolled keep studying the previously-live content, uninterrupted, until the new version is published — at which point the live pointer switches, the old version is archived, and enrolled Learners are notified of the update.

*(Screenshot: My Courses screen — course card with PUBLISHED + Editing Draft badges)*

---

#### 3.4 Entry Exam & AI Recommendation Workflow

> HanGo seeds one fixed, always-available assessment (internally Exam ID 999, "Global Entry Placement Test") used to bootstrap a new Learner's AI Learning Pathway. Unlike ordinary Exams (§3.5 Step 3), it has its own instructions screen and is offered proactively rather than found in the Exams list.

**Step 1: Take the Entry Exam**

**Step 1.1 — Accept the Prompt**
- On first visits to the **Home** screen, a Learner who has not yet completed the Entry Exam sees an **"Entry Exam!"** popup: *"Take the entry exam so the system can generate a personalized learning pathway specifically for you."*
- Click **"Take now"** (or **"Later"** to dismiss it for now).

*(Screenshot: Home screen — Entry Exam! popup)*

**Step 1.2 — Read the Instructions**
- The **"Exam Instructions"** screen lists what to check **"Before you start"**: Stable Connection, No Pausing, Focus Mode.
- Click **"Start Exam Now"**.

*(Screenshot: Exam Instructions screen)*

**Step 1.3 — Answer & Submit**
- Answer the questions using the same timed interface as a regular Exam (§3.5 Step 3.2) and click **"Submit Exam"**, then confirm.

*(Screenshot: Entry Exam — question screen)*

**Step 2: Receive the AI Recommendation**

**Step 2.1 — View the Result & Recommendations**
- The **Exam Result** screen shows the score and Skill Breakdown as usual, plus a **Recommendations** panel that loads automatically: an AI-written weakness summary and up to three course cards tagged **"AI Recommended"**, matched to the weakest skill from this attempt.

*(Screenshot: Exam Result screen — Recommendations panel)*

**Step 2.2 — View the AI Learning Pathway**
- On the top navigation bar, open **"Pathway"**. Once an Exam attempt exists, HanGo generates a personalized route automatically — a sequence of Course nodes, each with a reason ("Unlocked because you completed the previous course.", etc.) — no separate "Generate" click is needed.
- Before any Exam has been attempted, this screen instead reads: *"No active pathway yet. Finish an exam to let AI build a route for you."*
- From here, a Learner can also click the **"AI Mentor"** action to chat about their pathway, or open **"Edit Goal"** to adjust target score/deadline/hours-per-week and have the schedule recomputed.

*(Screenshot: Learning Pathway screen — node roadmap)*

---

#### 3.5 User Learning Workflow

**Step 1: Browse & Enroll in a Course**

**Step 1.1 — Browse the Catalog**
- Log in as a **Learner** (or continue as a guest — browsing does not require login).
- On the top navigation bar, select **"Courses"**.

*(Screenshot: Home screen — top navigation bar)*

- Use the search bar, the **Free/Paid** filter, and the rating filter (**All ratings / 4.5+ / 4.0+ / 3.5+**) to narrow the list — only Published courses appear.

*(Screenshot: Course catalog screen with search and filters)*

**Step 1.2 — Open a Course**
- Click a course card to open its detail page: title, description, price, Trainer info, rating, and syllabus outline.

*(Screenshot: Course Detail screen)*

**Step 1.3a — Enroll in a Free Course**
- Click **"Enroll now"**, then confirm **"Yes, Enroll"** in the **"Confirm Enrollment"** dialog. There is no cart/checkout step for free courses.
- The course immediately appears in **My Learning** at 0% progress, and the course's Trainer is notified of the new enrollment.

*(Screenshot: Confirm Enrollment dialog)*

**Step 1.3b — Purchase a Paid Course**
- On the course detail page, click **"Buy Now"** to check out that single course directly, or click **"Add to Cart"** (the button then reads **"Go to Cart"**) to add it alongside other courses first.
- Open the **Shopping Cart** (repeat "Add to Cart" for multiple courses; the checkout dialog title reflects the item count, e.g. **"Checkout 2 courses in cart"**).

*(Screenshot: Shopping Cart screen)*

- Click **"Scan QR Code Checkout"**. A PayOS QR code and checkout link appear, with the hint *"Button above will automatically open VietQR PayOS for your checkout."*
- Complete the payment on the PayOS side. Once PayOS confirms the transaction, the app shows a **Payment Success** state, the purchased course(s) are removed from the Cart automatically, and enrollment happens immediately — no manual step needed.

*(Screenshot: PayOS QR checkout dialog)*
*(Screenshot: Payment Success screen)*

- Past transactions (including this one) are viewable anytime under **Profile > Payment History**.

*(Screenshot: Payment History screen)*

**Step 2: Learn a Lesson**

**Step 2.1 — Open the Course**
- Right after enrolling, the course detail page's primary action becomes **"Study Now"**. From then on, open the course from **My Learning**'s "In Progress" tab by clicking **"Continue learning"** — this resumes at the last-visited Lesson (or the first Lesson, for a freshly enrolled course).

*(Screenshot: My Learning screen)*

**Step 2.2 — Study the Lesson**
- Read the Lesson content (text/video) and download any attached materials (image/PDF).

*(Screenshot: Lesson screen — content view)*

- Click **"Mark as Completed"**. The button becomes a static **"Lesson Completed"** badge, the sidebar shows a checkmark next to the lesson, and a separate **"Next Lesson"** button appears to advance — completion does not auto-navigate.

*(Screenshot: Lesson screen after marking complete)*

**Step 2.3 — Do the Lesson's Quiz (if attached)**
- Click **"Start"** (or **"Retake Quiz"** for a repeat attempt) on the Lesson's Quiz.
- Answer the single-choice questions and submit. The grade is recorded in the **Attempts** table below the quiz (unlimited retakes — every attempt is kept).

*(Screenshot: Lesson Quiz screen)*

- Click **"Review"** on any attempt to see each question's correct/incorrect marking (green/red) alongside the explanation text.

*(Screenshot: Quiz Review screen)*

**Step 2.4 — Track Progress**
- **My Learning**'s Resume Learning card shows a progress bar (completed Lessons ÷ total Lessons); it updates immediately after each Lesson completion.

*(Screenshot: My Learning — progress bar)*

**Step 3: Take an Exam**

> Exams are independent, timed assessments (distinct from a Lesson's Quiz) — accessed from the top navigation bar's **"Exams"** tab.

**Step 3.1 — Open an Exam**
- Open the **Exams** list and click a published Exam's card — this opens that Exam's own detail page, which shows its description, submission rules (*"The time will start counting down. When there are 2 minutes left, the clock will turn red... Your results will appear after you press Submit."*), and any past attempts.

*(Screenshot: Exam list screen)*
*(Screenshot: Exam detail page — rules and Start Exam button)*

**Step 3.2 — Start and Answer**
- Click **"Start Exam"** (or **"Retake Exam"** if you've attempted it before).
- The full question set appears with a **"Question `<n>` of `<total>`"** counter, a countdown timer based on the Exam's configured duration, and a right-hand question palette showing an **"Answered: X / Y"** count. Answers are cached locally, so navigating away and back does not lose progress.

*(Screenshot: Exam Taking screen — question, timer, and answer palette)*

**Step 3.3 — Submit the Exam**
- Click **"Submit Exam"**, then confirm in the **"Confirm Submission"** dialog (*"Are you sure you want to submit your test? You have answered X of Y questions."*) by clicking **"Submit"** — or let the timer reach 0:00 for an automatic submission.
- The score (0–10 scale) is computed on the server from the stored correct answers, not from anything calculated on the device.

*(Screenshot: Confirm Submission dialog)*

**Step 3.4 — View the Result & Attempt History**
- The **Exam Result** screen shows the total score (out of 10) plus Total/Correct/Incorrect counts and a Skill Breakdown.
- Under **Attempt History**, click **"Review"** on any attempt (the current one or an older one) to see, per question, your selected option next to the correct option.

*(Screenshot: Exam Result screen)*
*(Screenshot: Exam Review screen)*

**Step 4: Completion, Certificate & Feedback**

**Step 4.1 — Course Completion & Certificate**
- Completing the final Lesson brings the enrollment to 100% and **COMPLETED** status. The last Lesson's screen shows a **"Claim Certificate"** action in place of "Next Lesson".
- Tapping it opens the **Course Completed** screen with a **"CERTIFICATE OF COMPLETION"** banner, and **"Download PDF"** / **"Share to LinkedIn"** actions. The course also moves to My Learning's **Completed** tab, and both there and on the course detail page a **"View Certificate"** button reopens this certificate at any time.

*(Screenshot: Course Completed screen — certificate)*

**Step 4.2 — Rate & Give Feedback**
- The same Course Completed screen includes a rating section, **"How was your learning experience?"** (*"Leave a rating to guide future learners"*): choose a 1–5 star rating, optionally write feedback, then click **"Submit Feedback"** — a confirmation reads **"Thank You For Your Feedback!"**.
- The rating can also be added or edited later from the course's **Review** tab via **"Write a Review"** (labeled **"Edit Review"** if you've already rated it) — a dialog with a star **Rating** field and an optional **"Review Content"** field (500-character limit). The course's average rating and star-count breakdown update immediately after each submission.

*(Screenshot: Course Completed screen — rating and feedback section)*
*(Screenshot: Course Detail screen — Write a Review dialog)*

---
