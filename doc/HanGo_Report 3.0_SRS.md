<!-- Copy and paste the converted output. -->

<!-----

You have some errors, warnings, or alerts. If you are using reckless mode, turn it off to see useful information and inline alerts.
* ERRORs: 0
* WARNINGs: 0
* ALERTS: 1

Conversion time: 22.532 seconds.


Using this Markdown file:

1. Paste this output into your source file.
2. See the notes and action items below regarding this conversion run.
3. Check the rendered output (headings, lists, code blocks, tables) for proper
   formatting and use a linkchecker before you publish this page.

Conversion notes:

* Docs™ to Markdown version 2.0β2
* Tue Jun 16 2026 06:10:46 GMT-0700 (Pacific Daylight Time)
* Source doc: HanGo_Report 3.0_SRS
* Tables are currently converted to HTML tables.
* This document has images: check for >>>>>  gd2md-html alert:  inline image link in generated source and store images to your server. NOTE: Images in exported zip file from Google Docs may not appear in  the same order as they do in your doc. Please check the images!


WARNING:
You have 9 H1 headings. You may want to use the "H1 -> H2" option to demote all headings by one level.

----->


<p style="color: red; font-weight: bold">>>>>>  gd2md-html alert:  ERRORs: 0; WARNINGs: 1; ALERTS: 1.</p>
<ul style="color: red; font-weight: bold"><li>See top comment block for details on ERRORs and WARNINGs. <li>In the converted Markdown or HTML, search for inline alerts that start with >>>>>  gd2md-html alert:  for specific instances that need correction.</ul>

<p style="color: red; font-weight: bold">Links to alert messages:</p><a href="#gdcalert1">alert1</a>

<p style="color: red; font-weight: bold">>>>>> PLEASE check and correct alert issues and delete this message and the inline alerts.<hr></p>


**Software Requirements Specification**

***HanGo-Smart Language Self-Study Platform(SLSSP)- Report 3***


<table>
  <tr>
   <td><strong>Project Name</strong>
   </td>
   <td>
HanGo - Smart Language Self-Study Platform
   </td>
  </tr>
  <tr>
   <td><strong>Vision & Scope Ref</strong>
   </td>
   <td>Vision & Scope Document v1.0.0
   </td>
  </tr>
  <tr>
   <td><strong>RTW Ref</strong>
   </td>
   <td>HanGo_RTW.xlsx (Requirements Traceability Workbook)
   </td>
  </tr>
  <tr>
   <td><strong>SRS Version</strong>
   </td>
   <td>v0.9
   </td>
  </tr>
  <tr>
   <td><strong>Date Created</strong>
   </td>
   <td>31/05/2026
   </td>
  </tr>
  <tr>
   <td><strong>Last Updated</strong>
   </td>
   <td>16/06/2026
   </td>
  </tr>
  <tr>
   <td><strong>Author(s)</strong>
   </td>
   <td>SEP490_G92
   </td>
  </tr>
  <tr>
   <td><strong>Reviewer(s)</strong>
   </td>
   <td>HieuHT42
   </td>
  </tr>
  <tr>
   <td><strong>Status</strong>
   </td>
   <td>Draft
   </td>
  </tr>
</table>





# Document Change History


<table>
  <tr>
   <td><strong>Version</strong>
   </td>
   <td><strong>Date</strong>
   </td>
   <td><strong>Changes</strong>
   </td>
   <td><strong>Author</strong>
   </td>
  </tr>
  <tr>
   <td>v0.9
   </td>
   <td>08/06/2026
   </td>
   <td>Modify Feature Description
   </td>
   <td>TungNT
   </td>
  </tr>
  <tr>
   <td>v0.9
   </td>
   <td>15/06/2026
   </td>
   <td>Modify Data Requirement
   </td>
   <td>TungNT
   </td>
  </tr>
  <tr>
   <td>V0.9 
   </td>
   <td>16/06/2026
   </td>
   <td>Modify 
   </td>
   <td>
   </td>
  </tr>
</table>





# Part 1 — System Overview


## 1.1  System Objective & Business Context

HanGo is a smart English exam preparation platform that integrates structured learning, standardized exam practice, performance analysis, and an AI Learning Assistant to help learners prepare more effectively for the Vietnamese National High School Graduation Examination. 


## 1.2  Technical Scope


<table>
  <tr>
   <td><strong>Dimension</strong>
   </td>
   <td><strong>In Technical Scope</strong>
   </td>
   <td><strong>Notes</strong>
   </td>
  </tr>
  <tr>
   <td>Modules
   </td>
   <td>Authentication, Account Management, Course Management, Course Content Management, Question Bank Management, Exam Management, Recommendation System, AI Learning Assistant, Learning Progress, Flashcard Management, Comment Management, Task Management, Analytics Dashboard, Notification 
   </td>
   <td>Core modules implemented and maintained by HanGo. 
   </td>
  </tr>
  <tr>
   <td>Integrations
   </td>
   <td>OAuth2 Authentication Service; AI Service (Question Generation API); AI Agent Service (Learning Assistant); Email Service; File Storage Service 
   </td>
   <td>OAuth2: Read/Write. AI Service: Request/Response. AI Agent: Conversational interaction. Email Service: Outbound notifications. File Storage: Upload/Delete/Download. 
   </td>
  </tr>
  <tr>
   <td>Tech Stack
   </td>
   <td>Flutter (Front-end); Java Spring Boot (Back-end); MySQL 8.0; GitHub; Viettel IDC 
   </td>
   <td>High-level technologies and infrastructure used by the system. 
   </td>
  </tr>
  <tr>
   <td>Data Boundary
   </td>
   <td>HanGo owns and manages users, roles, courses, sections, lessons, quizzes, questions, exams, exam attempts, recommendations, learning progress, flashcards, comments, tasks, analytics, and notifications. 
   </td>
   <td>Authentication tokens, email delivery infrastructure, AI models, and file storage infrastructure are managed by external services. 
   </td>
  </tr>
  <tr>
   <td>Excluded (Tech)
   </td>
   <td>Real-time video conferencing; Third-party LMS integration; Speaking & Listening evaluation engine; Official certification issuance; Advanced gamification services 
   </td>
   <td>Refer to V&S Limitations & Exclusions.
   </td>
  </tr>
</table>



```
Diagram Placeholder — 4. Business Modeling 
INSERT HERE: Context Diagram showing the system and all external entities.
Show data flows in (solid arrows) and out (dashed arrows) for each entity.
Recommended tool: draw.io  |  Export PNG and embed at full content width.
```



## 1.3  System Roles


```
Guidance — 1.3
List roles for requirement authoring and access-control specification only.
Full stakeholder analysis (interests, concerns): V&S Section 1.3.
Full Permission Matrix (Role × Feature × CRUD action): RTW.xlsx Sheet 4.
Full Use Case List: RTW.xlsx Sheet 2.

This section has three parts:
  (a) Roles table — role name, access level, primary feature areas
  (b) Excel reference box — Permission Matrix in RTW.xlsx
  (c) Excel reference box + diagram placeholder — UC List + Use Case Diagram
```



<table>
  <tr>
   <td><strong>Role</strong>
   </td>
   <td><strong>Access Level</strong>
   </td>
   <td><strong>Primary Feature Areas</strong>
   </td>
  </tr>
  <tr>
   <td>Learner
   </td>
   <td>Internal 
   </td>
   <td>Authentication, Course Learning, Learning Progress, Flashcard Management, Exam Management, Recommendation System, AI Learning Assistant, Comment Management, Notification 
   </td>
  </tr>
  <tr>
   <td>Trainer
   </td>
   <td>Internal 
   </td>
   <td>Authentication, Course Management, Course Content Management, Question Bank Management, Exam Management, Task Management, Notification 
   </td>
  </tr>
  <tr>
   <td>Training Lead
   </td>
   <td>Internal 
   </td>
   <td>Authentication, Course Review & Publishing, Exam Review, Task Management, Trainer Workload Monitoring, Comment Moderation, Analytics Dashboard, Notification 
   </td>
  </tr>
  <tr>
   <td>Administrator 
   </td>
   <td>Internal 
   </td>
   <td>Authentication, Account Management, Permission Management, Analytics Dashboard 
   </td>
  </tr>
</table>



```
Permission Matrix → [ProjectName]_RTW.xlsx Sheet 4
Detailed Role x Feature x Action permission matrix (F/E/R/O/— per action).
Update RTW.xlsx Sheet 4 when roles or feature access rules change.
```



```
Use Case List → [ProjectName]_RTW.xlsx Sheet 2
Full Use Case List with: UC ID, Name, Primary Actor, Secondary Actor(s),
Pre/Postcondition, Related FT-xx, Related SC-xx, Priority, Status.
To add/update/deprecate a UC: edit RTW.xlsx Sheet 2 directly.
Then update the Use Case Diagram below.
```



```
Diagram Placeholder — Use Case Diagram (System Overview)
INSERT HERE: One high-level Use Case Diagram — all actors + grouped use cases.
This is a SUMMARY diagram. Do NOT draw one diagram per individual use case.
Actors: internal roles on left, external systems on right.
Group use cases by module inside the system boundary rectangle.
Use UML notation: stick figures, ovals, lines, <<include>> / <<extend>> where applicable.
For individual UC detail: RTW.xlsx Sheet 2 + Scenarios in Part 2.
Tool: draw.io  |  Export PNG and embed at full content width.
```



## 1.4  Glossary


```
Guidance — 1.4
Define SRS-specific technical and domain terms that appear in Scenarios,
Feature Descriptions, and Acceptance Criteria.
Do NOT repeat general business terms already defined in V&S.
Always include: AC-xx, NAC-xx, BV-xx conventions.
```



<table>
  <tr>
   <td><strong>Term</strong>
   </td>
   <td><strong>Definition</strong>
   </td>
   <td><strong>Used in</strong>
   </td>
  </tr>
  <tr>
   <td>[Key domain term]
   </td>
   <td>[Plain-language definition]
   </td>
   <td>[FT-xx, SC-xx]
   </td>
  </tr>
  <tr>
   <td>AC-xx
   </td>
   <td>Acceptance Criterion — a positive, testable condition for feature completion
   </td>
   <td>All FT-xx
   </td>
  </tr>
  <tr>
   <td>NAC-xx
   </td>
   <td>Negative Acceptance Criterion — failure/rejection/boundary-breach test condition
   </td>
   <td>All FT-xx
   </td>
  </tr>
  <tr>
   <td>BV-xx
   </td>
   <td>Boundary Value note — defines valid/invalid ranges for a specific constraint
   </td>
   <td>All FT-xx
   </td>
  </tr>
  <tr>
   <td>BR-xx
   </td>
   <td>Business Rule ID — full definition in RTW.xlsx Sheet 6
   </td>
   <td>All FT-xx
   </td>
  </tr>
</table>



## 1.5  Feature Traceability Bridge (V&S → SRS)


```
Guidance — 1.5
Full traceability (FE-xx → FT-xx → UC → Scenario → Data → NFR → BR → Test → Sprint)
is maintained in RTW.xlsx Sheet 3.
This section contains only a quick-reference summary table (FE → FT mapping).
Every V&S Feature (FE-xx) must have a corresponding SRS Feature (FT-xx).
Any FE-xx without an FT-xx is unspecified — flag as Pending.
```



```
Full traceability matrix → [ProjectName]_RTW.xlsx Sheet 3
Maintained in: RTW.xlsx Sheet 3: Feature Traceability Matrix
```



<table>
  <tr>
   <td><strong>V&S Feature (FE-xx)</strong>
   </td>
   <td><strong>Feature Name in V&S</strong>
   </td>
   <td><strong>Maps to SRS (FT-xx)</strong>
   </td>
   <td><strong>Status</strong>
   </td>
  </tr>
  <tr>
   <td>FE-01
   </td>
   <td>[Feature name]
   </td>
   <td>FT-01
   </td>
   <td>Specified / Pending
   </td>
  </tr>
  <tr>
   <td>FE-02
   </td>
   <td>[Feature name]
   </td>
   <td>[FT-xx]
   </td>
   <td>Pending
   </td>
  </tr>
  <tr>
   <td>[Add rows]
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
  </tr>
</table>



# Part 2 — Scenario / Narrative


```
Guidance — Part 2
Scenarios describe real-world business flows in natural language.
Reviewed and approved by stakeholders BEFORE Feature Descriptions are written.

Rules for writing good scenarios:
  • Use a specific persona name (not just a role label) — makes flows tangible
  • Include context: device, time of day, prior state
  • Keep to 1–3 paragraphs per scenario
  • Always include 1–2 most important exception / alternate flows
  • Do NOT describe UI elements or implementation details
  • Do NOT list features — describe what a real person does and experiences

Diagram: add Activity or Sequence Diagram after narratives with complex branching
or cross-system interactions (see placeholder below each scenario).

Close Part 2 with a Scenario List table summarising all scenarios.
```



## SC-01 — [Scenario Name]


```
Guidance — Scenario header table
Fill in: Business Flow (verb phrase), Primary Actor (the role driving the flow),
Pre-condition (system/data state required before flow starts),
Post-condition (guaranteed state after successful completion),
Related Feature (V&S FE-xx → SRS FT-xx), Related UC (RTW.xlsx Sheet 2).
```



<table>
  <tr>
   <td><strong>Business Flow</strong>
   </td>
   <td>[Verb phrase describing the end-to-end action]
   </td>
  </tr>
  <tr>
   <td><strong>Primary Actor</strong>
   </td>
   <td>[Role name]
   </td>
  </tr>
  <tr>
   <td><strong>Pre-condition</strong>
   </td>
   <td>[What must be true before this flow can start]
   </td>
  </tr>
  <tr>
   <td><strong>Post-condition</strong>
   </td>
   <td>[Guaranteed system state after successful completion]
   </td>
  </tr>
  <tr>
   <td><strong>Related Feature</strong>
   </td>
   <td>[FE-xx (V&S)] → [FT-xx (SRS)]
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>[UC-xx (RTW.xlsx Sheet 2)]
   </td>
  </tr>
</table>


**Narrative:**

*[Write 1–3 paragraphs. Name your persona. Include context. Describe what happens, not how it is implemented. Use past/present tense consistently.]*

**Key Exception / Alternate Flows:**


```
Guidance — exception flows
List 1–2 most important failure or alternate paths.
Format: [Trigger]: [What the system does] — [Outcome for the user].
Do not attempt to cover every edge case here — that belongs in NAC-xx in Part 3.
```



```
Diagram Placeholder — [SC-xx Diagram Type]
INSERT HERE: [Activity Diagram / Sequence Diagram] for this scenario.
Activity Diagram: for flows with multiple decision branches.
Sequence Diagram: for flows with significant cross-system interactions.
Tool: draw.io  |  File: [ProjectName]_[SC-xx]_[DiagramType].drawio
```



## SC-02 — [Next Scenario]

*(Repeat SC structure above for each scenario. Aim for 4–8 scenarios covering the most important business flows.)*


## Scenario List


```
Guidance — Scenario List
Summarise all scenarios in one table for quick navigation.
Every Feature Description in Part 3 must link to at least one scenario.
```



<table>
  <tr>
   <td><strong>ID</strong>
   </td>
   <td><strong>Scenario Name</strong>
   </td>
   <td><strong>Primary Actor</strong>
   </td>
   <td><strong>Maps to Feature(s)</strong>
   </td>
   <td><strong>Priority</strong>
   </td>
  </tr>
  <tr>
   <td>SC-01
   </td>
   <td>[Name]
   </td>
   <td>[Actor]
   </td>
   <td>[FT-xx]
   </td>
   <td>High/Medium/Low
   </td>
  </tr>
  <tr>
   <td>SC-02
   </td>
   <td>[Name]
   </td>
   <td>[Actor]
   </td>
   <td>[FT-xx]
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td>SC-0N
   </td>
   <td>[Add rows as needed]
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
  </tr>
</table>



## SC-01 — Take Exam and Receive Learning Recommendations


```
Guidance — Scenario header table
Fill in: Business Flow (verb phrase), Primary Actor (the role driving the flow),
Pre-condition (system/data state required before flow starts),
Post-condition (guaranteed state after successful completion),
Related Feature (V&S FE-xx → SRS FT-xx), Related UC (RTW.xlsx Sheet 2).
```



<table>
  <tr>
   <td><strong>Business Flow</strong>
   </td>
   <td>Complete an exam and receive personalized learning recommendations
   </td>
  </tr>
  <tr>
   <td><strong>Primary Actor</strong>
   </td>
   <td>Learner
   </td>
  </tr>
  <tr>
   <td><strong>Pre-condition</strong>
   </td>
   <td>Learner has a valid account and is logged into the system. At least one published exam is available.
   </td>
  </tr>
  <tr>
   <td><strong>Post-condition</strong>
   </td>
   <td>Exam results are stored. Weakness analysis is generated. Relevant course recommendations are displayed to the learner.
   </td>
  </tr>
  <tr>
   <td><strong>Related Feature</strong>
   </td>
   <td>FE-05 Exam Management → FE-06 Recommendation
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-01 Take Exam, UC-02 View Exam Result, UC-03 Receive Course Recommendation
   </td>
  </tr>
</table>


**Narrative:**

On a weekend evening, Minh, a grade 12 student preparing for the National High School Graduation English Exam, wants to evaluate his current proficiency. He selects an available exam and completes all questions within the allocated time.

After submission, HanGo evaluates the attempt, analyzes performance across SkillType and GroupType categories, identifies weak areas, and generates personalized learning recommendations. Minh reviews the results and recommended courses before deciding which learning path to pursue next.

**Key Exception / Alternate Flows:**


```
Guidance — exception flows
List 1–2 most important failure or alternate paths.
Format: [Trigger]: [What the system does] — [Outcome for the user].
Do not attempt to cover every edge case here — that belongs in NAC-xx in Part 3.
```


EX-01 — Exam Time Expires

If the exam time limit is reached before the learner submits, the system automatically submits the current attempt and generates results using the answered questions.

EX-02 — Exam Interrupted

If the learner leaves the exam unexpectedly, the system saves the current progress and allows the learner to resume later.

EX-03 — No Matching Recommendation

If no predefined recommendation rule is matched, the system recommends general foundational courses related to the learner's weakest categories.


```
Diagram Placeholder — [SC-xx Diagram Type]
INSERT HERE: [Activity Diagram / Sequence Diagram] for this scenario.
Activity Diagram: for flows with multiple decision branches.
Sequence Diagram: for flows with significant cross-system interactions.
Tool: draw.io  |  File: [ProjectName]_[SC-xx]_[DiagramType].drawio
```



## SC-02 Learn Course with AI Learning Assistant


```
Guidance — Scenario header table
Fill in: Business Flow (verb phrase), Primary Actor (the role driving the flow),
Pre-condition (system/data state required before flow starts),
Post-condition (guaranteed state after successful completion),
Related Feature (V&S FE-xx → SRS FT-xx), Related UC (RTW.xlsx Sheet 2).
```



<table>
  <tr>
   <td><strong>Business Flow</strong>
   </td>
   <td>Learn course content with contextual AI learning support
   </td>
  </tr>
  <tr>
   <td><strong>Primary Actor</strong>
   </td>
   <td>Learner
   </td>
  </tr>
  <tr>
   <td><strong>Pre-condition</strong>
   </td>
   <td>Learners are logged in and enrolled in a course. The course is published and contains at least one lesson.
   </td>
  </tr>
  <tr>
   <td><strong>Post-condition</strong>
   </td>
   <td>Learning progress is updated and learner receives contextual learning support from the AI Learning Assistant.
   </td>
  </tr>
  <tr>
   <td><strong>Related Feature</strong>
   </td>
   <td>FE-04 Course Content Management → FE-07 AI Learning Assistant → FE-08 Learning Progress
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>[UC-xx (RTW.xlsx Sheet 2)]
   </td>
  </tr>
</table>


**Narrative:**

After receiving course recommendations from a previous exam, Minh enrolls in a Reading Comprehension course. While studying a lesson, he encounters a reading technique that he does not fully understand. Instead of leaving the course to search for answers elsewhere, Minh asks the AI Learning Assistant for clarification.

The AI uses the current lesson content, course materials, and Minh’s learning profile to provide contextual explanations and additional examples. Minh continues learning, completes the lesson activities, and his learning progress is updated automatically.

**Key Exception / Alternate Flows:**


```
Guidance — exception flows
List 1–2 most important failure or alternate paths.
Format: [Trigger]: [What the system does] — [Outcome for the user].
Do not attempt to cover every edge case here — that belongs in NAC-xx in Part 3.
```


EX-01 — Question Outside Course Scope

If the learner asks a question unrelated to the current lesson or course, the AI politely declines and redirects the learner back to relevant learning topics.

EX-02 — Lesson Completed Without AI Interaction

The learner may complete the lesson without interacting with the AI assistant. Learning progress is still updated normally.

EX-03 — AI Cannot Find Relevant Context

If sufficient context is unavailable, the AI informs the learner that it cannot confidently answer and recommends reviewing related course materials.


```
Diagram Placeholder — [SC-xx Diagram Type]
INSERT HERE: [Activity Diagram / Sequence Diagram] for this scenario.
Activity Diagram: for flows with multiple decision branches.
Sequence Diagram: for flows with significant cross-system interactions.
Tool: draw.io  |  File: [ProjectName]_[SC-xx]_[DiagramType].drawio
```



## SC-03 Create & Publish Course


```
Guidance — Scenario header table
Fill in: Business Flow (verb phrase), Primary Actor (the role driving the flow),
Pre-condition (system/data state required before flow starts),
Post-condition (guaranteed state after successful completion),
Related Feature (V&S FE-xx → SRS FT-xx), Related UC (RTW.xlsx Sheet 2).
```



<table>
  <tr>
   <td><strong>Business Flow</strong>
   </td>
   <td>Create, review, and publish a course
   </td>
  </tr>
  <tr>
   <td><strong>Primary Actor</strong>
   </td>
   <td>Trainer
   </td>
  </tr>
  <tr>
   <td><strong>Pre-condition</strong>
   </td>
   <td>Trainer has an active account and is assigned a content creation task.
   </td>
  </tr>
  <tr>
   <td><strong>Post-condition</strong>
   </td>
   <td>The course is published and available to learners, or returned to the trainer for revision. 
   </td>
  </tr>
  <tr>
   <td><strong>Related Feature</strong>
   </td>
   <td>FE-03 Course Management → FE-04 Course Content Management → FE-09 Task Management
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>[UC-xx (RTW.xlsx Sheet 2)]
   </td>
  </tr>
</table>


**Narrative:**

After receiving a task from the Training Lead, Linh, a Trainer, creates a new course focused on Reading Comprehension. She organizes the course into sections and lessons, adds learning materials, and prepares practice content.

Once the course is complete, Linh submits it for review. The Training Lead evaluates the content quality and either approves the course for publication or rejects it with feedback for revision. When approved, the course becomes available to learners on the platform.

**Key Exception / Alternate Flows:**


```
Guidance — exception flows
List 1–2 most important failure or alternate paths.
Format: [Trigger]: [What the system does] — [Outcome for the user].
Do not attempt to cover every edge case here — that belongs in NAC-xx in Part 3.
```


EX-01 — Course Rejected

If the Training Lead identifies quality issues, the course is rejected and returned to the Trainer with comments for revision.

EX-02 — Incomplete Content

If mandatory course information or lesson content is missing, the system prevents submission and requires completion before review.


```
Diagram Placeholder — [SC-xx Diagram Type]
INSERT HERE: [Activity Diagram / Sequence Diagram] for this scenario.
Activity Diagram: for flows with multiple decision branches.
Sequence Diagram: for flows with significant cross-system interactions.
Tool: draw.io  |  File: [ProjectName]_[SC-xx]_[DiagramType].drawio
```



## SC-04 Create & Publish Exam


```
Guidance — Scenario header table
Fill in: Business Flow (verb phrase), Primary Actor (the role driving the flow),
Pre-condition (system/data state required before flow starts),
Post-condition (guaranteed state after successful completion),
Related Feature (V&S FE-xx → SRS FT-xx), Related UC (RTW.xlsx Sheet 2).
```



<table>
  <tr>
   <td><strong>Business Flow</strong>
   </td>
   <td>Create, review, and publish an exam
   </td>
  </tr>
  <tr>
   <td><strong>Primary Actor</strong>
   </td>
   <td>Trainer
   </td>
  </tr>
  <tr>
   <td><strong>Pre-condition</strong>
   </td>
   <td>Trainer has an active account and is assigned an exam creation task.
   </td>
  </tr>
  <tr>
   <td><strong>Post-condition</strong>
   </td>
   <td>The exam is published and available for learners, or returned for revision.
   </td>
  </tr>
  <tr>
   <td><strong>Related Feature</strong>
   </td>
   <td>FE-05 Exam Management → FE-09 Task Management
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>[UC-xx (RTW.xlsx Sheet 2)]
   </td>
  </tr>
</table>


**Narrative:**

After receiving an exam creation task, Linh, a Trainer, creates a new mock exam based on the National High School Graduation English Exam structure. She creates question groups, individual questions, assigns SkillType and GroupType classifications, and provides answer explanations for each question.

Once the exam is completed, Linh submits it for review. The Training Lead evaluates the exam structure, question quality, classifications, and explanations. If approved, the exam becomes available for learners. Otherwise, it is returned to the Trainer with feedback for revision.

**Key Exception / Alternate Flows:**


```
Guidance — exception flows
List 1–2 most important failure or alternate paths.
Format: [Trigger]: [What the system does] — [Outcome for the user].
Do not attempt to cover every edge case here — that belongs in NAC-xx in Part 3.
```


EX-01 — Exam Rejected

If the Training Lead finds incorrect answers, poor explanations, or inappropriate classifications, the exam is rejected and returned for correction.

EX-02 — Missing Required Information

If questions, answers, explanations, SkillType, or GroupType classifications are incomplete, the system prevents exam submission.


```
Diagram Placeholder — [SC-xx Diagram Type]
INSERT HERE: [Activity Diagram / Sequence Diagram] for this scenario.
Activity Diagram: for flows with multiple decision branches.
Sequence Diagram: for flows with significant cross-system interactions.
Tool: draw.io  |  File: [ProjectName]_[SC-xx]_[DiagramType].drawio
```



## SC-05 Task Assignment Workflow


```
Guidance — Scenario header table
Fill in: Business Flow (verb phrase), Primary Actor (the role driving the flow),
Pre-condition (system/data state required before flow starts),
Post-condition (guaranteed state after successful completion),
Related Feature (V&S FE-xx → SRS FT-xx), Related UC (RTW.xlsx Sheet 2).
```



<table>
  <tr>
   <td><strong>Business Flow</strong>
   </td>
   <td>Assign and manage content creation tasks
   </td>
  </tr>
  <tr>
   <td><strong>Primary Actor</strong>
   </td>
   <td>Training Lead
   </td>
  </tr>
  <tr>
   <td><strong>Pre-condition</strong>
   </td>
   <td>Training Lead and Trainer accounts exist and are active.
   </td>
  </tr>
  <tr>
   <td><strong>Post-condition</strong>
   </td>
   <td>A task is assigned, reviewed, and completed through the approval workflow.
   </td>
  </tr>
  <tr>
   <td><strong>Related Feature</strong>
   </td>
   <td>FE-09 Task Management 
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>[UC-xx (RTW.xlsx Sheet 2)]
   </td>
  </tr>
</table>


**Narrative:**

At the beginning of a content production cycle, Huy, a Training Lead, identifies the need for a new course covering Reading Comprehension at the Basic level. He creates a task describing the required content, expected difficulty level, and submission deadline, then assigns the task to Linh, a Trainer.

Linh works on the assigned content and submits it for review after completion. Huy reviews the submitted work and either approves it or returns it with revision feedback. The workflow continues until the task satisfies the required quality standards and is marked as completed.

**Key Exception / Alternate Flows:**


```
Guidance — exception flows
List 1–2 most important failure or alternate paths.
Format: [Trigger]: [What the system does] — [Outcome for the user].
Do not attempt to cover every edge case here — that belongs in NAC-xx in Part 3.
```


EX-01 — Task Rejected

If the submitted content does not meet quality requirements, the Training Lead rejects the submission and provides feedback for revision.

EX-02 — Deadline Missed

If the Trainer fails to submit before the deadline, the task remains overdue and can be reassigned or extended by the Training Lead.

EX-03 — Task Reassigned

If the assigned Trainer becomes unavailable, the Training Lead may reassign the task to another Trainer.


```
Diagram Placeholder — [SC-xx Diagram Type]
INSERT HERE: [Activity Diagram / Sequence Diagram] for this scenario.
Activity Diagram: for flows with multiple decision branches.
Sequence Diagram: for flows with significant cross-system interactions.
Tool: draw.io  |  File: [ProjectName]_[SC-xx]_[DiagramType].drawio
```



# Part 3 — Feature Description


```
Guidance — Part 3 convention
Feature Descriptions specify WHAT the system does — written after scenarios are approved.
Each FT-xx maps to at least one V&S feature (FE-xx) via the traceability bridge (Part 1.5).

Every FT-xx contains five sub-sections:
  1. Header table (source feature, scenario, UC, summary)
  2. System Behaviour (what the system does — use active system language + specific numbers)
  3. Applicable Business Rules (BR IDs only — full definitions in RTW.xlsx Sheet 6)
  4. Positive Acceptance Criteria (AC-xx) — happy path, verifiable conditions
  5. Negative Acceptance Criteria (NAC-xx) — failure, rejection, invalid inputs
  6. Boundary Value Notes (BV-xx) — valid/invalid ranges with test points

Business Rule convention (Approach B — master in RTW.xlsx):
  List BR IDs only in each FT-xx. Full rule text is in RTW.xlsx Sheet 6.
  This eliminates duplication and ensures a single point of update.

Writing rules:
  • 'The system automatically...' / 'The system displays...' / 'The system rejects...'
  • Specific numbers always: '15 minutes', 'within 90 seconds', 'maximum 10 units'
  • Never vague: 'quickly', 'soon', 'appropriate', 'standard'
  • Do NOT describe UI layout or technical implementation
```



## FT-01 — [Feature Name]


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>[FE-xx]
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>[SC-xx]
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>[UC-xx (RTW.xlsx Sheet 2)]
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>[One sentence: what the system does for whom, and what value it delivers.]
   </td>
  </tr>
</table>


**System Behaviour:**


```
Guidance — System Behaviour
Describe the system's behaviour in operational terms. Structure as:
  Trigger → Processing → Output
Include: polling/push mechanism, timing (every X seconds), data normalisation,
  display rules, sorting, and any automatic actions.
Use specific numbers. Reference BR IDs for any constraint that has a policy basis.
```


*[Describe system behaviour here. 2–4 paragraphs. Active voice. Specific numbers.]*

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**


```
Guidance — Positive AC
Write 2–5 conditions that must be TRUE for this feature to be considered done.
Each AC must be independently testable — a QA engineer should be able to write
a test case from each AC without asking questions.
Format: 'AC-xx: When [condition], the system [does X] within [Y time / Z count].'
```




* **AC-01: **[When X happens, the system does Y. Specific and measurable.]
* **AC-02: **[Another verifiable positive condition.]

    ```
Negative Acceptance Criteria (NAC) — FT-01
Write 3–5 failure / rejection scenarios that the system must handle correctly.
For each NAC, specify:
  • The invalid input, forbidden action, or failure condition
  • The exact system response (HTTP status code, error message text, or behaviour)
  • Any side effects that must NOT occur (no record created, no stock changed, etc.)
  • Any audit/logging requirement

Common NAC categories to cover:
  • Invalid input: malformed payload, missing required field, wrong data type
  • Boundary breach: value outside valid range (reference BV-xx)
  • Unauthorised access: role without permission attempts an action → 403
  • Race condition: two users attempting the same action simultaneously
  • Stale / duplicate: event received for already-closed or already-processed state
  • Timer expiry: action attempted after a time window has closed

Replace this guidance box with actual NAC-xx entries when writing the real SRS.
```



    ```
Boundary Value Notes (BV) — FT-01
For each numeric constraint in this feature, define:
  • Lower boundary (minimum valid value)
  • Upper boundary (maximum valid value)
  • Default value
  • Invalid values just outside boundaries
  • Explicit test points for QA (parameterised test inputs)

Format:
  BV-xx  [Constraint name]:
    Valid: [min] to [max]  |  Default: [value]
    Invalid: [below min], [above max]
    Test points: [value1 (label)], [value2 (label)], [boundary], [boundary+1 (breach)]

Replace this guidance box with actual BV-xx entries when writing the real SRS.
```



    ```
Diagram Placeholder — [FT-01 Diagram if needed]
INSERT HERE only if this feature requires a visual to clarify integration or flow.
Not every feature needs its own diagram — use sparingly.
Candidates: integration flow (for API-heavy features), state machine (if complex state).
```




## FT-02 to FT-0N — [Additional Features]

*(Repeat the FT structure above for each feature. Add as many FT-xx sections as needed, one per feature.)*


<table>
  <tr>
   <td><strong>ID</strong>
   </td>
   <td><strong>Feature Name</strong>
   </td>
   <td><strong>Source (V&S)</strong>
   </td>
   <td><strong>Scenario</strong>
   </td>
   <td><strong>Status</strong>
   </td>
  </tr>
  <tr>
   <td>FT-01
   </td>
   <td>[Name]
   </td>
   <td>FE-xx
   </td>
   <td>SC-xx
   </td>
   <td>Specified / Draft
   </td>
  </tr>
  <tr>
   <td>FT-02
   </td>
   <td>[Name]
   </td>
   <td>FE-xx
   </td>
   <td>SC-xx
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td>FT-0N
   </td>
   <td>[Add rows]
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
  </tr>
</table>



## FT-01 — Authentication


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-01
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-01, UC-02, UC-03, UC-04
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system allows users to register, log in, recover passwords, and securely access the platform based on their assigned roles
   </td>
  </tr>
</table>


**System Behaviour:**

The system receives login credentials (email and password) from the user. Upon clicking "Login", the system validates the credentials against the database. If valid, the system grants a session valid for 24 hours and redirects the user to the landing page corresponding to their role. 

If the user enters an incorrect password 5 consecutive times, the system automatically locks the account temporarily for 15 minutes. For registration and password resets, the system validates the password string against the length and complexity constraints before saving. 

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When the user enters a valid email and password, the system authenticates the user and redirects them to the correct role-based dashboard within a maximum of 3 seconds.
* **AC-02:** When the user selects "Forgot Password" and enters a registered email, the system sends a password reset link valid for 30 minutes to that email address.
* **AC-03:** When the user registers or resets a password using a string that strictly meets the BV-01 requirements (length and complexity), the system accepts the password and completes the action successfully.

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Invalid Credentials):** If the user enters an incorrect email or password during login, the system displays the error message "Invalid login credentials" and must not specify which field is incorrect.
* **NAC-02 (Account Lockout):** When the user breaches boundary BV-02 (exceeds 5 failed attempts), the system displays an HTTP 403 error and rejects all login requests from this account for the next 15 minutes.
* **NAC-03 (Invalid Password Format):** If the user attempts to register or reset a password with a string that breaches BV-01 (e.g., missing uppercase, lowercase, special character, or out of length bounds), the system displays specific validation error messages (e.g., "Password must contain at least one uppercase letter") and blocks the submission.

**Boundary Value Notes (BV):**



* **BV-01 [Password Length & Complexity]:**
    * **Valid:** 8 to 32 characters, AND must include at least one uppercase letter, one lowercase letter, and one special character (e.g., @, #, $, %, !, ^, &, *).
    * **Invalid:** &lt; 8 characters, > 32 characters, or 8-32 characters but missing any of the required character types.
    * **Test points:**
        * ValidPass1! (11 chars, has all required types) → Pass
        * Abc@1 (5 chars, has all required types but too short) → Fail (Length breach)
        * aB1!............................. (33 chars, has all required types but too long) → Fail (Length breach)
        * invalidpass1! (13 chars, no uppercase) → Fail (Complexity breach)
        * INVALIDPASS1! (13 chars, no lowercase) → Fail (Complexity breach)
        * ValidPass123 (12 chars, no special character) → Fail (Complexity breach)
* **BV-02 [Maximum Failed Login Attempts]:**
    * **Valid:** 0 to 4 times.
    * **Invalid:** 5 times (triggers NAC-02).
    * **Test points:** 4 (pass), 5 (lockout).


## FT-02 — Account Management


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-02
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-05, UC-06, UC-77, UC-83
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system enables Administrators to manage user accounts, assign roles, and configure permissions, while allowing individual users to view and update their personal profiles.
   </td>
  </tr>
</table>


**System Behaviour:**

The system allows logged-in users to view and update their profiles, synchronizing valid changes immediately. Administrators can manage all accounts, including creating users, modifying roles, and toggling account statuses. When an Admin disables an account, the system immediately revokes access tokens and forces a logout across all active devices within 60 seconds. 

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a user submits valid profile updates, the system saves and displays the changes immediately without a page reload. 
* **AC-02:** When an Admin manually creates an account, the system initializes it and triggers the Registration Success Notification. 
* **AC-03:** When an Admin assigns a new role, the system applies it and updates the user's permission payload upon their next action. 
* **AC-04:** When an Admin disables an account, the system updates its status to "Locked" and terminates all active sessions within 60 seconds. 

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Unauthorized Access):** If a non-Admin user attempts to access account management endpoints, the system blocks the request and returns an HTTP 403 Forbidden error. 
* **NAC-02 (Self-Deactivation):** If an Admin attempts to disable their own account or demote their role, the system keeps the button disabled and displays: "You cannot modify the status or role of your current admin session." 
* **NAC-03 (Invalid Profile Data):** If a user submits profile data breaching BV-01, the system rejects the submission, highlights invalid fields in red, and displays a validation error. 

**Boundary Value Notes (BV):**



* **BV-01 [Full Name Length]:**
    * **Valid:** 2 to 50 characters | Default: Empty (on manual admin creation).
    * **Invalid:** 1 character, 51 characters.
    * **Test points:** 2 (pass), 50 (pass), 1 (fail - triggers NAC-03), 51 (fail - triggers NAC-03).
* **BV-02 [Role Assignment Constraint]:**
    * **Valid:** 1 to 3 concurrent roles per user.
    * **Invalid:** 0 roles, 4 roles.
    * **Test points:** 1 role (pass), 3 roles (pass), 0 roles (fail - system requires at least one default role), 4 roles (fail - triggers UI error).


## FT-03 — Course Management


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-03
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-07, UC-08, UC-09, UC-35, UC-36, UC-37, UC-38, UC-62, UC-63, UC-64
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system supports creating, reviewing, publishing, and maintaining English exam preparation courses organized by skill level and exam topic.
   </td>
  </tr>
</table>


**System Behaviour:**

Trainers can create and recursively update English exam preparation courses in "Draft" status. When a Trainer submits a course, the system updates its status to "In Review" and notifies the assigned Training Lead within 5 seconds. Upon review, if the Training Lead approves, the system updates the status to "Published", making the course accessible to Learners. If rejected, the system enforces mandatory feedback, reverts the course to "Draft", and notifies the Trainer for revision. 

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a Trainer submits a course with all mandatory fields completed, the system updates the status to "In Review" and triggers a notification to the Training Lead within 5 seconds. 
* **AC-02:** When a Training Lead approves an "In Review" course, the system updates the status to "Published" and makes it visible in the Learners' course directory. 
* **AC-03:** When a Training Lead rejects a course, the system enforces mandatory feedback input, reverts the status to "Draft", and saves the comments for the Trainer. 

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Incomplete Content):** If a Trainer attempts to submit a course missing mandatory fields (e.g., title, target skill, difficulty), the system rejects the submission, highlights the missing fields in red, and displays an HTTP 400 Bad Request error. 
* **NAC-02 (Unauthorized Publishing):** If a Trainer attempts to publish a course directly, bypassing the review process, the system blocks the request and returns an HTTP 403 Forbidden error.** **

**Boundary Value Notes (BV):**



* **BV-01 [Course Title Length]:**
    * **Valid:** 5 to 100 characters | Default: Empty.
    * **Invalid:** &lt; 5 characters, > 100 characters.
    * **Test points:** 5 (pass), 100 (pass), 4 (fail - triggers validation error), 101 (fail - triggers validation error).
* **BV-02 [Course Description Length]:**
    * **Valid:** 20 to 2000 characters | Default: Empty.
    * **Invalid:** &lt; 20 characters, > 2000 characters.
    * **Test points:** 20 (pass), 2000 (pass), 19 (fail - triggers NAC-01), 2001 (fail - triggers NAC-01).


## FT-04 — Course Content Management


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-04
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-11, UC-39, UC-40, UC-41, UC-42, UC-43, UC-44
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system allows Course Creators to build structured learning content, including sections, learning lessons, and practice quizzes, and submit them for review.
   </td>
  </tr>
</table>


**System Behaviour:**

Trainers can structure courses by creating Sections and adding two types of lessons: Learning Lessons (theory, illustrations, flashcards) and Practice Lessons (quizzes). When a Trainer submits a lesson, the system updates its status to "Pending Approval" and automatically notifies the assigned Training Lead. Upon review, if the Training Lead approves, the system seamlessly integrates the lesson into the published course structure. If rejected, the system enforces a mandatory rejection reason, reverts the lesson status, and notifies the Trainer for corrections. 

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a Trainer creates a new Section and adds a Learning Lesson or Practice Lesson, the system saves the hierarchy and displays the updated curriculum tree within 3 seconds.
* **AC-02:** When a Trainer uploads valid content (text, video links, or flashcards) to a Learning Lesson and clicks save, the system successfully stores the data without any data loss.
* **AC-03:** When a Training Lead approves a lesson, the system updates the lesson status to "Approved" and integrates it directly into the published course structure.

**Negative Acceptance Criteria (NAC):**



* **AC-01:** When a Trainer adds a Learning or Practice Lesson to a Section, the system saves the hierarchy and displays the updated curriculum tree within 3 seconds. 
* **AC-02:** When a Trainer saves valid content to a Learning Lesson, the system successfully stores the data without any data loss. 
* **AC-03:** When a Training Lead approves a lesson, the system updates the status to "Approved" and integrates it directly into the published course.** **

**Boundary Value Notes (BV):**



* **BV-01 [Lesson Title Length]:**
    * **Valid:** 5 to 100 characters | Default: Empty.
    * **Invalid:** &lt; 5 characters, > 100 characters.
    * **Test points:** 5 (pass), 100 (pass), 4 (fail - triggers validation error), 101 (fail - triggers validation error).
* **BV-02 [Quiz Questions per Practice Lesson]:**
    * **Valid:** 1 to 50 questions.
    * **Invalid:** 0 questions, 51 questions.
    * **Test points:** 1 (pass), 50 (pass), 0 (fail - triggers NAC-01), 51 (fail - system restricts adding more questions).


## FT-05 — Question Bank Management


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-05
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-45, UC-46, UC-47, UC-48, UC-49, UC-50
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system allows Trainers to create, import, edit, and search a centralized repository of categorized exam questions. 
   </td>
  </tr>
</table>


**System Behaviour:**

Trainers can manually create single questions or import them in bulk via a formatted file. When a Trainer saves or imports questions, the system validates mandatory attributes (content, 4 options, correct answer, explanation, Difficulty, and SkillType/GroupType) and stores them in the Question Bank. The system allows Trainers to search, filter, update, or delete these questions. However, the system strictly prevents the deletion of any question that is currently utilized in a published exam. 

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a Trainer creates or updates a question with all valid attributes, the system saves the record and displays the updated Question Bank within 2 seconds. 
* **AC-02:** When a Trainer uploads a valid formatted file for bulk import, the system imports all questions, categorizes them appropriately, and displays a success summary without data loss. 
* **AC-03:** When a Trainer applies search or filter criteria (e.g., by SkillType or Difficulty), the system returns the matching list of questions within 2 seconds. 

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Invalid Question Data):** If a Trainer attempts to save a question missing mandatory attributes (e.g., lacking a correct answer or missing SkillType), the system prevents the save action, highlights the missing fields in red, and displays an HTTP 400 validation error. 
* **NAC-02 (Invalid File Import):** If a Trainer uploads an incompatible or malformed file, the system rejects the upload, aborts the import process, and displays an HTTP 400 error along with a template download link. 
* **NAC-03 (Delete In-Use Question):** If a Trainer attempts to delete a question that is currently integrated into a "Published" exam, the system blocks the action, keeps the question intact, and returns an HTTP 409 Conflict error.** **

**Boundary Value Notes (BV):**



* **BV-01 Question Options Count:**
    * **Valid:** 4 to 4 | **Default:** 4
    * **Invalid:** 3, 5
    * **Test points:** 3 (breach - missing option), 4 (valid boundary), 5 (breach - extra option)
* **BV-02 Bulk Import Limit:**
    * **Valid:** 1 to 500 | **Default:** N/A
    * **Invalid:** 0, 501
    * **Test points:** 0 (breach - empty file), 1 (min valid), 500 (max valid), 501 (breach - exceeds import limit)
* **BV-03 Question Content Length:**
    * **Valid:** 1 to 1000 characters | **Default:** N/A
    * **Invalid:** 0, 1001
    * **Test points:** 0 (breach - empty content), 1 (min valid), 1000 (max valid), 1001 (breach - content too long)


## FT-06 — Exam Management


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-05
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-24, UC-29, UC-51, UC-55, UC-65
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system enables Trainers to create and publish standardized exams, while allowing Learners to take exams, receive automated grading, and view a detailed weakness analysis based on skill categories.
   </td>
  </tr>
</table>


**System Behaviour:**

Trainers can construct exams by adding questions and groups with required SkillType and GroupType classifications. When submitted, the system updates the exam status to "In Review" and notifies the Training Lead. Upon review, if approved, the system updates the status to "Published". If rejected, the system enforces mandatory feedback, reverts the exam to "Draft", and notifies the Trainer for corrections. When a learner starts an exam, the system initiates a countdown timer and continuously autosaves progress. If the timer expires, the system automatically submits the attempt. Upon submission, the system calculates the score and generates a detailed Weakness Analysis report (broken down by SkillType and GroupType) within 5 seconds. 

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a Trainer submits an exam with all mandatory question attributes (options, answers, explanations, classifications), the system updates the status to "In Review" and notifies the Training Lead. 
* **AC-02:** When a learner manually submits an exam, the system evaluates the answers and displays the final score alongside Weakness Analysis charts within 5 seconds. 
* **AC-03:** When the exam timer reaches 00:00, the system automatically forces a submission and grades only the answered questions.** **

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Incomplete Exam):** If a Trainer attempts to submit an exam missing mandatory attributes, the system rejects the submission, highlights incomplete elements in red, and displays an HTTP 400 error. 
* **NAC-02 (Unauthorized Publishing):** If a Trainer attempts to publish an exam directly, bypassing the review process, the system blocks the request and returns an HTTP 403 Forbidden error. 
* **NAC-03 (Session Interruption):** If a Learner's connection drops or the browser closes during an active exam, the system retains the answered questions and remaining time, allowing seamless resumption upon reconnecting.** **

**Boundary Value Notes (BV):**



* **BV-01 [Exam Time Limit]:**
    * **Valid:** 15 to 180 minutes | Default: 60 minutes.
    * **Invalid:** &lt; 15 minutes, > 180 minutes.
    * **Test points:** 15 (pass), 180 (pass), 14 (fail - triggers validation error), 181 (fail - triggers validation error).
* **BV-02 [Questions per Exam]:**
    * **Valid:** 10 to 200 questions.
    * **Invalid:** 9 questions, 201 questions.
    * **Test points:** 10 (pass), 200 (pass), 9 (fail - blocks save/submission), 201 (fail system restricts adding new question blocks).


## FT-07 — Recommendation


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-06
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-30
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system utilizes a rule-based engine to automatically suggest personalized courses and learning paths based on the Learner's exam performance, identified weaknesses, and difficulty proficiencies. 
   </td>
  </tr>
</table>


**System Behaviour:**

Upon generating a Weakness Analysis, the system triggers a strictly rule-based Recommendation Engine to evaluate the Learner's performance percentages across SkillType, GroupType, and Difficulty. The system matches these metrics against predefined thresholds to identify appropriate courses. Within 3 seconds, the system compiles, deduplicates, and displays a curated list of recommended courses on the Learner's dashboard. If no specific rules match, the system automatically defaults to suggesting foundational courses corresponding to the Learner's lowest-scoring category. 

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a Learner's score falls below a defined threshold for a SkillType or GroupType, the system recommends the exact mapped courses within 3 seconds.
* **AC-02:** When evaluating skill scores alongside Difficulty metrics, the system filters and recommends courses aligning precisely with the Learner's current proficiency tier.** **

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Rule Fallback):** If exam results match no predefined rules, the system prevents an empty state by outputting at least one foundational course linked to the lowest-performing skill category.
* **NAC-02 (Deduplication):** If multiple overlapping rules trigger the same recommended course, the system deduplicates the results and displays the course only once.** **

**Boundary Value Notes (BV):**



* **BV-01 [Recommendation Display Limit]:**
    * **Valid:** 1 to 5 recommended courses | Default: 3 courses.
    * **Invalid:** 0 courses, 6 courses.
    * **Test points:** 1 (pass), 5 (pass), 0 (fail - triggers NAC-01 fallback), 6 (fail - system truncates the list and only displays the top 5 most relevant courses).
* **BV-02 [Performance Threshold Evaluation]:**
    * **Valid:** 0% to 100%.
    * **Invalid:** &lt; 0%, > 100%.
    * **Test points:** 0% (pass), 100% (pass), -1% (fail - system blocks evaluation and logs an error), 101% (fail - system blocks evaluation and logs an error).


## FT-08 — AI Learning Assistant


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-07
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-31
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system provides a context-aware AI learning assistant that understands course materials to explain concepts, answer questions, generate similar exercises, and offer personalized study guidance.
   </td>
  </tr>
</table>


**System Behaviour:**

When a learner interacts with the AI Learning Assistant, the system gathers a context payload (current lesson, course, profile, and learning history) to process the prompt. The AI executes specific educational actions: explaining concepts or quizzes, generating similar questions (matching the exact SkillType, GroupType, and Difficulty), or providing personalized guidance. The system strictly enforces an educational boundary; if a prompt falls outside the current lesson or course scope, the system blocks the query and forces a predefined redirection response within 5 seconds. 

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a Learner requests an explanation for a highlighted concept or quiz, the system extracts the context and returns a detailed explanation within 5 seconds. 
* **AC-02:** When a Learner clicks "Generate Similar Questions", the system creates new practice questions exactly matching the original SkillType, GroupType, and Difficulty. 
* **AC-03:** When a Learner asks for study advice, the system analyzes their learning history and weakness profile to return a personalized learning roadmap. 

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Out of Scope Prompt):** If a Learner submits a prompt unrelated to the current lesson or course, the system declines the request and redirects the Learner back to the relevant learning material. 
* **NAC-02 (Insufficient Context):** If the system cannot retrieve sufficient context data, the AI informs the Learner of its inability to answer and recommends reviewing course documents. 
* **NAC-03 (Service Timeout):** If the AI engine fails to respond within 15 seconds, the system stops the loading indicator and displays the error: "The assistant is taking too long to respond. Please try again."** **

**Boundary Value Notes (BV):**



* **BV-01 [User Prompt Length Constraint]:**
    * **Valid:** 1 to 500 characters | Default: Empty.
    * **Invalid:** 0 characters, 501 characters.
    * **Test points:** 1 (pass), 500 (pass), 0 (fail - send button remains disabled), 501 (fail - system truncates excess characters and notifies the Learner).


## FT-09 — Learning Progress


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-08
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td> 
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-10, UC-11, UC-12, UC-13, UC-14, UC-15
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system allows learners to enroll in courses, automatically tracks their learning progress, and enables them to seamlessly resume their studies from the last accessed lesson.
   </td>
  </tr>
</table>


**System Behaviour:**

Learners can enroll in published courses, initializing their progress at 0%. As a learner completes lessons (theory or quizzes), the system automatically recalculates the overall course completion percentage. The system continuously autosaves the Learner's last accessed position. When a learner clicks "Resume Learning", the system automatically redirects them to the exact incomplete lesson. Upon finishing all mandatory lessons, the system updates the course status to "Completed".

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a Learner enrolls in a published course, the system adds the course to their enrolled list and displays a 0% progress indicator within 3 seconds. 
* **AC-02:** When a Learner completes a lesson, the system recalculates the course progress and instantly updates the progress bar. 
* **AC-03:** When a Learner clicks "Resume Learning", the system fetches the last saved state and navigates them to the exact incomplete lesson. 
* **AC-04:** When a Learner finishes the final mandatory lesson, the system updates the course status to "Completed" and displays 100% progress.** **

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Duplicate Enrollment):** If a Learner attempts to enroll in an already active course, the system blocks the action and displays: "You are already enrolled in this course." 
* **NAC-02 (Unauthorized Access):** If a Learner attempts to access a lesson URL of an unenrolled course, the system denies access, redirects them to the course overview, and returns an HTTP 403 Forbidden error. 
* **NAC-03 (Unpublished Course):** If a Learner attempts to access or enroll in an unpublished or archived course, the system blocks the request, returns an HTTP 404 Not Found error, and redirects to the course directory.** **

**Boundary Value Notes (BV):**



* **BV-01 [Course Progress Percentage]:**
    * **Valid:** 0% to 100%.
    * **Invalid:** &lt; 0%, > 100%.
    * **Test points:** 0% (pass), 100% (pass), -1% (fail - system logs data integrity error), 101% (fail - system caps at 100% and logs error).
* **BV-02 [Enrolled Courses per Learner]:**
    * **Valid:** 1 to 50 concurrent courses | Default: 0.
    * **Invalid:** 51 courses.
    * **Test points:** 1 (pass), 50 (pass), 51 (fail - system restricts new enrollment and prompts Learner to complete existing courses first).


## FT-10 — Flashcard Management


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-08
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td> 
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-16, UC-17, UC-18, UC-19, UC-20, UC-21
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system allows learners to build a personal vocabulary collection by highlighting text within lessons or manually creating and practicing flashcards. 
   </td>
  </tr>
</table>


**System Behaviour:**

Learners can build a personal vocabulary collection by highlighting terms directly within a lesson or by manually creating flashcards. When a learner saves or updates a flashcard, the system validates mandatory attributes (term and definition) and stores it in their personal collection. The system allows Learners to view, edit, delete, or practice these flashcards. During a flashcard practice session, the system retrieves the collection, tracks the Learner's interactions, and records the session completion status. 

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a learner highlights a vocabulary word in a lesson and clicks save, the system extracts the term and saves it to the personal flashcard collection within 2 seconds. 
* **AC-02:** When a Learner manually creates or updates a flashcard with valid text, the system saves the record and displays the updated flashcard list immediately without a page reload. 
* **AC-03:** When a Learner clicks delete on a flashcard, the system permanently removes the record from the database and updates the UI instantly.

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Invalid Flashcard Data):** If a learner attempts to save a flashcard with an empty term or definition, the system prevents the save action, highlights the missing fields in red, and displays an HTTP 400 validation error. 
* **NAC-02 (Duplicate Vocabulary):** If a Learner attempts to save a term that already exists exactly in their personal collection, the system blocks the duplication, keeps the form open, and displays an HTTP 409 Conflict error ("Vocabulary already exists"). 
* **NAC-03 (Unauthorized Deletion):** If a user attempts to modify or delete a flashcard belonging to another Learner's collection via API, the system blocks the request and returns an HTTP 403 Forbidden error.** **

**Boundary Value Notes (BV):**



* **BV-01 Flashcard Term Length:**
    * **Valid:** 1 to 100 characters | **Default:** N/A
    * **Invalid:** 0, 101
    * **Test points:** 0 (breach - empty term), 1 (min valid), 100 (max valid), 101 (breach - term too long)
* **BV-02 Flashcard Definition Length:**
    * **Valid:** 1 to 500 characters | **Default:** N/A
    * **Invalid:** 0, 501
    * **Test points:** 0 (breach - empty definition), 1 (min valid), 500 (max valid), 501 (breach - definition too long)


## FT-11 — Comment Management


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-09
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td> 
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-22, UC-23, UC-71 
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system provides an interactive discussion area within each lesson, allowing Learners to ask questions, Trainers to reply, and Trainers and Training Lead to moderate content.
   </td>
  </tr>
</table>


**System Behaviour:**

Learners can submit top-level comments and reply to existing threads within lessons. Trainers and Training Leads can participate by replying to provide academic explanations. Administrators and authorized moderators can hide or delete violating comments. When a comment is hidden, the system immediately replaces the original text with a generic placeholder message across all active user sessions. 

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a user submits a valid comment, the system saves and displays it at the top of the thread within 3 seconds without a page reload. 
* **AC-02:** When a user submits a reply, the system nests it directly underneath the parent comment.
* **AC-03:** When an Administrator hides a comment, the system masks the content and instantly replaces it with a "Comment removed" placeholder.** **

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Empty Submission):** If a user attempts to submit an empty comment or reply (zero characters or whitespace only), the system keeps the submit button disabled, blocks the action, and displays an HTTP 400 validation error. 
* **NAC-02 (Unauthorized Moderation):** If a Learner attempts to hide or delete another user's comment, the system blocks the action and returns an HTTP 403 Forbidden error.** **

**Boundary Value Notes (BV):**



* **BV-01 [Comment Text Length]:**
    * **Valid:** 1 to 1000 characters | Default: Empty.
    * **Invalid:** 0 characters, 1001 characters.
    * **Test points:** 1 (pass), 1000 (pass), 0 (fail - triggers NAC-01), 1001 (fail - system restricts input and truncates excess characters).
* **BV-02 [Comment Reply Nesting Limit]:**
    * **Valid:** 1 level of nesting (a reply to a parent comment).
    * **Invalid:** 2 or more levels of nesting (replying to a reply creating a deep tree).
    * **Test points:** 1 level (pass), 2 levels (fail - the system forces the new reply to align with the existing first-level replies under the same parent comment).


## FT-12 — Task Management


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-10
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-56, UC-57, UC-58, UC-59, UC-60, UC-66, UC-67, UC-68, UC-69, UC-70
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system supports the content production lifecycle by allowing Training Leads to create, assign, and review content creation tasks, while enabling Trainers to submit their work for approval. 
   </td>
  </tr>
</table>


**System Behaviour:**

Training Leads can create, assign, and set due dates for content production tasks. Upon assignment, the system saves the task and triggers a notification to the assigned Trainer. When a Trainer submits the completed content, the system updates the task status to "In Review" and notifies the Training Lead. Upon review, if approved, the system updates the status to "Completed". If rejected, the system enforces mandatory revision feedback, reverts the status to "Requires Resubmission", and notifies the Trainer for corrections.

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a Training Lead assigns a task, the system saves the record and displays it on the Trainer's dashboard within 3 seconds. 
* **AC-02:** When a Trainer submits a task, the system updates the status to "In Review" and notifies the Training Lead. 
* **AC-03:** When a Training Lead approves a submission, the system updates the status to "Completed" and closes the task. 
* **AC-04:** When a Training Lead rejects a submission, the system reverts the status to "Requires Resubmission" and saves the mandatory feedback.** **

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Empty Submission):** If a Trainer attempts to submit a task without linked content, the system blocks the action, keeps the status unchanged, and displays an HTTP 400 validation error. 
* **NAC-02 (Missing Feedback):** If a Training Lead rejects a submission with an empty feedback field, the system prevents the action and highlights the field in red. 
* **NAC-03 (Unauthorized Access):** If a Learner attempts to access task management endpoints, the system blocks the request, redirects them to the homepage, and returns an HTTP 403 Forbidden error.** **

**Boundary Value Notes (BV):**



* **BV-01 [Task Deadline Setting]:**
    * **Valid:** Current time + 24 hours to + 365 days.
    * **Invalid:** Past dates/times, or &lt; 24 hours from the creation moment.
    * **Test points:** Past date (fail - system blocks creation), +24h (pass).
* **BV-02 [Rejection Feedback Length]:**
    * **Valid:** 10 to 1000 characters.
    * **Invalid:** &lt; 10 characters, > 1000 characters.
    * **Test points:** 10 (pass), 1000 (pass), 9 (fail - triggers NAC-02 validation), 1001 (fail - system truncates excess characters).


## FT-13 — Analytics Dashboard


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-11
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-72, UC-73, UC-74, UC-75, UC-84, UC-85, UC-86, UC-87, UC-88
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system provides comprehensive dashboards and analytical insights related to learner performance, weakness trends, exam results, course effectiveness, and AI assistant usage.
   </td>
  </tr>
</table>


**System Behaviour:**

The system continuously aggregates platform data. When a user navigates to the Analytics module, the system retrieves and visualizes metrics based strictly on role permissions. Trainers view course-level analytics (student demographics, score distributions, exam results) exclusively for their assigned courses. Administrators access a master dashboard displaying platform-wide metrics, including overall student performance, weakness analytics (by SkillType and GroupType), and AI usage frequency. When a user applies a custom date filter, the system automatically recalculates and refreshes the charts to reflect the selected timeframe. 

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When an Administrator accesses the master dashboard, the system retrieves data and renders platform-wide charts (including weakness and AI usage analytics) within 5 seconds. 
* **AC-02:** When a Trainer views analytics for a specific course, the system displays student performance and exam metrics filtered exclusively for that course. 
* **AC-03:** When a user applies a custom date range filter, the system recalculates and updates all connected graphs to reflect only the data within the selected period.** **

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (Unauthorized Access):** If a Learner attempts to access analytics endpoints, or a Trainer attempts to view unauthorized master metrics, the system blocks the request, logs the attempt, and returns an HTTP 403 Forbidden error. 
* **NAC-02 (Empty Data State):** If a user views analytics for a course with zero enrolled students or exam attempts, the system prevents broken charts by displaying a "No data available yet" placeholder. 
* **NAC-03 (Invalid Date Filter):** If a user applies an end date occurring before the start date, the system prevents the query and highlights the date picker with a validation error.** **

**Boundary Value Notes (BV):**



* **BV-01 [Analytics Date Range Filter]:**
    * **Valid:** 1 day to 365 days.
    * **Invalid:** End date before start date, or a range > 365 days.
    * **Test points:** 1 day (pass), 365 days (pass), 366 days (fail - system restricts query and prompts user to select a shorter timeframe to prevent database overload).
* **BV-02 [Displayable Data Points per Chart]:**
    * **Valid:** 1 to 100 data points (e.g., days on a time-series line chart).
    * **Invalid:** 0 points, 101 points.
    * **Test points:** 1 (pass), 100 (pass), 0 (fail - triggers NAC-02 empty state), 101 (fail - system automatically aggregates data into larger intervals, such as weeks or months, to fit the maximum visual limit of 100 points).


## FT-14 — Notification


<table>
  <tr>
   <td><strong>Source Feature (V&S)</strong>
   </td>
   <td>FE-12
   </td>
  </tr>
  <tr>
   <td><strong>Related Scenario</strong>
   </td>
   <td>
   </td>
  </tr>
  <tr>
   <td><strong>Related UC</strong>
   </td>
   <td>UC-39, UC-95, UC-97, UC-98, UC-99, UC-100 
   </td>
  </tr>
  <tr>
   <td><strong>Summary</strong>
   </td>
   <td>The system automatically delivers timely in-app notifications and emails regarding assigned tasks, content reviews, course updates, and learning reminders.
   </td>
  </tr>
</table>


**System Behaviour:**

The notification engine operates as a centralized background service that listens for specific triggering events across the platform. When an event occurs—such as a Training Lead assigning a task, a course changing status to "Approved" or "Rejected" after a review, or a new Learner registering successfully—the system generates a notification payload.

The system immediately pushes this payload as an in-app alert to the target user's notification center. For critical events (such as account registration or password resets), the system also dispatches an email notification. When a user clicks on an unread notification in the system dropdown menu, the system automatically changes its state to "Read" and directly navigates the user to the relevant destination page (e.g., the specific task detail, course overview, or review feedback page).

**Applicable Business Rules:**

*BR-xx, BR-yy  →  See [ProjectName]_RTW.xlsx Sheet 6 for full definitions.*

**Positive Acceptance Criteria (AC):**



* **AC-01:** When a Training Lead assigns a new task, the system successfully generates an in-app notification and displays it on the assigned Trainer's screen within 3 seconds.
* **AC-02:** When a user clicks an unread notification, the system successfully changes its visual state to "Read", decrements the unread badge counter by 1, and navigates the user to the correct target URL.
* **AC-03:** When a Trainer's course or exam is approved or rejected by a Training Lead, the system successfully sends a review result notification detailing the status change.

**Negative Acceptance Criteria (NAC):**



* **NAC-01 (External Service Failure):** If the external email service is temporarily down when the system attempts to send a registration success notification, the system must log the failure and gracefully queue the email for background retry without crashing or interrupting the user's current flow.
* **NAC-02 (Unauthorized Modification):** If a user attempts to intercept the API to mark a notification belonging to another user ID as read or deleted, the system explicitly blocks the action and returns an HTTP 403 Forbidden error.

**Boundary Value Notes (BV):**



* **BV-01 [Unread Notification Badge Count]:**
    * **Valid:** 0 to 99 unread notifications.
    * **Invalid (UI constraint):** 100+ notifications.
    * **Test points:** 0 (badge hidden), 5 (shows "5"), 99 (shows "99"), 100 (caps the display at "99+" to prevent UI layout breakage).
* **BV-02 [Notification Message Length]:**
    * **Valid:** 10 to 150 characters.
    * **Invalid:** > 150 characters.
    * **Test points:** 150 (pass), 151 (system truncates the text with an ellipsis ‘...’ before displaying it in the dropdown).

<table>
  <tr>
   <td>
<strong>ID</strong>
   </td>
   <td><strong>Feature Name</strong>
   </td>
   <td><strong>Source (V&S)</strong>
   </td>
   <td><strong>Scenario</strong>
   </td>
   <td><strong>Status</strong>
   </td>
  </tr>
  <tr>
   <td>FT-01
   </td>
   <td>Authentication
   </td>
   <td>FE-01
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-02
   </td>
   <td>Account Management
   </td>
   <td>FE-02
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-03
   </td>
   <td>Course Management
   </td>
   <td>FE-03
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-04
   </td>
   <td>Course Content Management
   </td>
   <td>FE-04
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-05
   </td>
   <td>Question Bank Management
   </td>
   <td>FE-05
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-06
   </td>
   <td>Exam Management
   </td>
   <td>FE-05
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-07
   </td>
   <td>Recommendation
   </td>
   <td>FE-06
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-08
   </td>
   <td>AI Learning Assistant
   </td>
   <td>FE-07
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-09
   </td>
   <td>Learning Progress
   </td>
   <td>FE-08
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-10
   </td>
   <td>Flashcard Management
   </td>
   <td>FE-08
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-11
   </td>
   <td>Comment Management
   </td>
   <td>FE-09
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-12
   </td>
   <td>Task Management
   </td>
   <td>FE-10
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-13
   </td>
   <td>Analytics Dashboard
   </td>
   <td>FE-11
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
  <tr>
   <td>FT-14
   </td>
   <td>Notification
   </td>
   <td>FE-12
   </td>
   <td>
   </td>
   <td>Draft
   </td>
  </tr>
</table>



# Part 4 — Data Requirements


```
Guidance — Part 4
Four sub-sections:
  4.1 Core Entities & Relationships — entity summary (not full ERD)
  4.2 Data Constraints & Integrity Rules — system-enforced rules (distinct from BRs)
  4.3 Data Retention & Ownership — how long, who owns, who can delete
  4.4 State Transition Table — for any entity with a multi-step lifecycle

What belongs in RTW.xlsx Sheet 5 (not here):
  Full attribute-level detail: data type, nullable, unique, default, validation rule

What belongs in the TDS (not here):
  Physical schema, indexes, migration scripts, ORM mappings
```



## 4.1  Core Entities & Relationships


```
Guidance — 4.1
List each entity, its purpose in one sentence, and its key relationships.
Use the notation: Entity A --< Entity B (one-to-many), A -- B (one-to-one).
Full attribute definitions are in RTW.xlsx Sheet 5.
Place the ERD diagram placeholder below — insert a conceptual ERD (not physical schema).
```



```
Diagram Placeholder — Entity Relationship Diagram (ERD)
INSERT HERE: Conceptual ERD showing core entities and their relationships.
Use crow's foot notation. Show cardinality and key foreign keys.
This is a conceptual ERD for requirement purposes — physical ERD belongs in TDS.
Tool: draw.io  |  File: [ProjectName]_ERD.drawio
```



<table>
  <tr>
   <td><strong>Entity</strong>
   </td>
   <td><strong>Purpose (one sentence)</strong>
   </td>
   <td><strong>Key Relationships</strong>
   </td>
   <td><strong>Full Attributes</strong>
   </td>
  </tr>
  <tr>
   <td><strong>User</strong>
   </td>
   <td>Represents all individuals (Learner, Trainer, Training Lead, Admin) interacting with the platform.
   </td>
   <td>User --&lt; Course
<p>
User --&lt; Task
   </td>
   <td>RTW.xlsx Sheet 5
   </td>
  </tr>
  <tr>
   <td><strong>Course</strong>
   </td>
   <td>Specialized training programs focusing on specific English skills or exam topics.
   </td>
   <td>Course --&lt; Section
<p>
Course --&lt; Enrollment
   </td>
   <td>RTW.xlsx Sheet 5
   </td>
  </tr>
  <tr>
   <td><strong>Section</strong>
   </td>
   <td>Chapters that organize the learning pathway within a specific course.
   </td>
   <td>Section --&lt; Lesson
   </td>
   <td>RTW.xlsx Sheet 5
   </td>
  </tr>
  <tr>
   <td><strong>Lesson</strong>
   </td>
   <td>The smallest unit of knowledge transmission, containing theory or practice exercises.
   </td>
   <td>Lesson --&lt; Learning Progress
<p>
Lesson --&lt; Comment
   </td>
   <td>RTW.xlsx Sheet 5
   </td>
  </tr>
  <tr>
   <td><strong>Exam</strong>
   </td>
   <td>Standardized mock tests constructed according to the official exam structure.
   </td>
   <td>Exam --&lt; Question
<p>
Exam --&lt; Exam Attempt
   </td>
   <td>RTW.xlsx Sheet 5
   </td>
  </tr>
  <tr>
   <td><strong>Question</strong>
   </td>
   <td>Assessment units testing specific knowledge, either standing alone or linked to a reading group.
   </td>
   <td>Question --&lt; Option
<p>
Group --&lt; Question
   </td>
   <td>RTW.xlsx Sheet 5
   </td>
  </tr>
  <tr>
   <td><strong>Task</strong>
   </td>
   <td>Requests for academic content creation assigned by Training Leads to Trainers.
   </td>
   <td>Task --&lt; Creator Task
   </td>
   <td>RTW.xlsx Sheet 5
   </td>
  </tr>
  <tr>
   <td><strong>Flashcard</strong>
   </td>
   <td>Personal vocabulary collections saved by learners for spaced repetition review.
   </td>
   <td>User --&lt; Flashcard
<p>
Flashcard --&lt; Review
   </td>
   <td>RTW.xlsx Sheet 5
   </td>
  </tr>
  <tr>
   <td><strong>Comment</strong>
   </td>
   <td>Interactive discussion threads tied to specific learning lessons.
   </td>
   <td>User --&lt; Comment
<p>
Comment --&lt; Reply
   </td>
   <td>RTW.xlsx Sheet 5
   </td>
  </tr>
  <tr>
   <td><strong>AI Conversation</strong>
   </td>
   <td>Context-aware chat sessions between a learner and the AI Assistant.
   </td>
   <td>User --&lt; AI Conversation
<p>
AI Conversation --&lt; Message
   </td>
   <td>RTW.xlsx Sheet 5
   </td>
  </tr>
</table>



## 4.2  Data Constraints & Integrity Rules


```
Guidance — 4.2
List constraints that affect system behaviour at the requirement level.
These are data integrity rules, NOT business policy rules (those are in RTW.xlsx Sheet 6).
Integrity rules include: immutability, uniqueness, referential integrity, atomic operations,
  valid value ranges enforced at the data layer.
Each DC-xx should reference the feature (FT-xx) or state transition (Part 4.4) it supports.
```



<table>
  <tr>
   <td><strong>ID</strong>
   </td>
   <td><strong>Constraint</strong>
   </td>
   <td><strong>Entities Affected</strong>
   </td>
   <td><strong>Violation Behaviour</strong>
   </td>
  </tr>
  <tr>
   <td><strong>DC-01</strong>
   </td>
   <td><strong>Uniqueness of User Identity</strong>: User email addresses must be strictly unique across the entire system.
   </td>
   <td>User
   </td>
   <td>The system rejects the save operation, aborts the transaction, and returns an "Email already exists" error (HTTP 409).
   </td>
  </tr>
  <tr>
   <td><strong>DC-02</strong>
   </td>
   <td><strong>Referential Integrity of Questions</strong>: A Question cannot be deleted if it is currently referenced by any Published Exam.
   </td>
   <td>Question, Exam
   </td>
   <td>The system blocks the deletion request, preserves the historical data, and returns a conflict error (HTTP 409).
   </td>
  </tr>
  <tr>
   <td><strong>DC-03</strong>
   </td>
   <td><strong>Cascading Deletion of Course Structure</strong>: When a Course is deleted, all dependent Sections and Lessons within it must be automatically deleted (Cascade Delete).
   </td>
   <td>Course, Section, Lesson
   </td>
   <td>N/A (The system automatically executes the atomic cleanup operation at the database layer).
   </td>
  </tr>
  <tr>
   <td><strong>DC-04</strong>
   </td>
   <td><strong>Orphan Prevention for Submissions</strong>: A Task Submission must always be linked to a valid, existing Task ID.
   </td>
   <td>Task, Creator Task
   </td>
   <td>The system rejects the submission, prevents data corruption, and returns an HTTP 400 Bad Request error.
   </td>
  </tr>
</table>



## 4.3  Data Retention & Ownership Policy


```
Guidance — 4.3
For each data type, specify: how long it must be kept, who owns it, who can delete it,
and the regulatory or policy basis for these decisions.
This drives: automated purge jobs, data deletion request handling (GDPR/local law),
  and audit log immutability requirements.
```



<table>
  <tr>
   <td><strong>Data Type</strong>
   </td>
   <td><strong>Retention Period</strong>
   </td>
   <td><strong>Owner</strong>
   </td>
   <td><strong>Deletion Authority</strong>
   </td>
   <td><strong>Basis</strong>
   </td>
  </tr>
  <tr>
   <td><strong>User Accounts & Profiles</strong>
   </td>
   <td>Permanent until account deletion request
   </td>
   <td>User (Learner / Trainer / Lead)
   </td>
   <td>Administrator / System (upon request)
   </td>
   <td>Privacy Policy & User Consent
   </td>
  </tr>
  <tr>
   <td><strong>Educational Content (Courses, Lessons, Exams, Questions)</strong>
   </td>
   <td>Permanent (Soft deleted via deleted_at timestamp)
   </td>
   <td>Trainer / Training Lead
   </td>
   <td>Training Lead / Administrator
   </td>
   <td>Academic Quality Control & Content Audit Trail
   </td>
  </tr>
  <tr>
   <td><strong>Assessment Records (Exam Attempts, Scores, Weakness Analysis)</strong>
   </td>
   <td>Permanent
   </td>
   <td>System / Learner
   </td>
   <td>Administrator
   </td>
   <td>Required for continuous Learning History tracking
   </td>
  </tr>
  <tr>
   <td><strong>AI Conversations & Messages</strong>
   </td>
   <td>1 Year from creation date
   </td>
   <td>System
   </td>
   <td>System (Automated Purge Job)
   </td>
   <td>Storage Optimization & Privacy limitations
   </td>
  </tr>
  <tr>
   <td><strong>Audit Logs & Notifications</strong>
   </td>
   <td>90 Days
   </td>
   <td>System
   </td>
   <td>System (Automated Purge Job)
   </td>
   <td>Security Policy & Operational Storage Management
   </td>
  </tr>
  <tr>
   <td><strong>Flashcards & Personal Vocabulary</strong>
   </td>
   <td>Until explicitly deleted by the user
   </td>
   <td>Learner
   </td>
   <td>Learner
   </td>
   <td>Personal Learning Workspace policy
   </td>
  </tr>
  <tr>
   <td><strong>User Accounts & Profiles</strong>
   </td>
   <td>Permanent until account deletion request
   </td>
   <td>User (Learner / Trainer / Lead)
   </td>
   <td>Administrator / System (upon request)
   </td>
   <td>Privacy Policy & User Consent
   </td>
  </tr>
</table>



## 4.4.1  Course/Exam State Transition Table


```
Guidance — 4.4 State Transition Table
Create one State Transition Table for each entity with a significant lifecycle
(e.g. Order, Ticket, Request, Task).

The table has two parts:
  (a) Valid Transitions — every legal state change with trigger, guard, and system action
  (b) Invalid Transitions — explicit list of forbidden transitions that must be rejected

Each row in (a) should correspond to 1–2 positive test cases.
Each row in (b) should correspond to 1 negative test case (NAC).

Columns for Valid Transitions:
  From State | Trigger Event | Guard Condition | To State | System Action

Columns for Invalid Transitions:
  From State | Attempted Transition | Why Invalid | System Response

Close this section with a QA guidance note listing the key edge cases to test.
Add a Sequence/State Machine diagram placeholder.
```


**Valid State Transitions:**


<table>
  <tr>
   <td><strong>From State</strong>
   </td>
   <td><strong>Trigger Event</strong>
   </td>
   <td><strong>Guard Condition</strong>
   </td>
   <td><strong>To State</strong>
   </td>
   <td><strong>System Action</strong>
   </td>
  </tr>
  <tr>
   <td><strong>Draft</strong>
   </td>
   <td>Trainer clicks "Submit for Review"
   </td>
   <td>All mandatory fields and content sections must be fully completed.
   </td>
   <td>In Review
   </td>
   <td>System locks the content from further editing by the Trainer and notifies the Training Lead.
   </td>
  </tr>
  <tr>
   <td><strong>In Review</strong>
   </td>
   <td>Training Lead clicks "Approve"
   </td>
   <td>Content meets academic quality standards.
   </td>
   <td>Published
   </td>
   <td>System makes the Course/Exam accessible to Learners on the platform.
   </td>
  </tr>
  <tr>
   <td><strong>In Review</strong>
   </td>
   <td>Training Lead clicks "Reject"
   </td>
   <td>Training Lead must provide valid textual feedback.
   </td>
   <td>Draft
   </td>
   <td>System unlocks the content for editing and notifies the Trainer with the revision feedback.
   </td>
  </tr>
  <tr>
   <td><strong>Published</strong>
   </td>
   <td>Training Lead clicks "Archive"
   </td>
   <td>The content is no longer relevant or needs to be retired.
   </td>
   <td>Archived
   </td>
   <td>System hides the Course/Exam from the Learner directory but preserves historical attempt data.
   </td>
  </tr>
  <tr>
   <td><strong>Archived</strong>
   </td>
   <td>Training Lead clicks "Restore"
   </td>
   <td>The content is deemed relevant again.
   </td>
   <td>Draft
   </td>
   <td>System restores the content for Trainer to update before resubmitting.
   </td>
  </tr>
</table>


**Invalid Transitions (must be rejected — DC-01):**


<table>
  <tr>
   <td><strong>From State</strong>
   </td>
   <td><strong>Attempted Transition</strong>
   </td>
   <td><strong>Why Invalid</strong>
   </td>
   <td><strong>System Response</strong>
   </td>
  </tr>
  <tr>
   <td><strong>Draft</strong>
   </td>
   <td>Attempt to transition directly to Published
   </td>
   <td>Bypasses the mandatory Quality Assurance review process by the Training Lead.
   </td>
   <td>The system disables the Publish button, blocks the API request, and returns an HTTP 403 Forbidden error.
   </td>
  </tr>
  <tr>
   <td><strong>In Review</strong>
   </td>
   <td>Attempt to edit Course/Exam content
   </td>
   <td>Content must remain immutable while the Training Lead is evaluating it to prevent data race conditions.
   </td>
   <td>The system hides edit tools and returns an HTTP 403 Forbidden error if API is called.
   </td>
  </tr>
  <tr>
   <td><strong>Archived</strong>
   </td>
   <td>Attempt to transition directly to Published
   </td>
   <td>Archived content might be outdated and requires review before being exposed to Learners again.
   </td>
   <td>The system rejects the action, requiring it to be restored to Draft first
   </td>
  </tr>
</table>



```
Diagram Placeholder — [Entity] State Machine Diagram
INSERT HERE: State Machine / State Diagram for this entity's lifecycle.
Label each transition arrow with the trigger event.
Show terminal states (no outgoing transitions) clearly.
Tool: draw.io  |  File: [ProjectName]_[Entity]StateMachine.drawio
```



# 

<p id="gdcalert1" ><span style="color: red; font-weight: bold">>>>>>  gd2md-html alert: inline image link here (to images/image1.png). Store image on your image server and adjust path/filename/extension if necessary. </span><br>(<a href="#">Back to top</a>)(<a href="#gdcalert2">Next alert</a>)<br><span style="color: red; font-weight: bold">>>>>> </span></p>


![alt_text](images/image1.png "image_tooltip")
  

**Course/Exam State Machine Diagram**

**File: [HanGo_Course/ExamStateMachine.drawio](https://drive.google.com/file/d/1bvubsE4N61VLgxI3Et-UW0MPku3lz2Eh/view?usp=sharing)**


## 4.4.2  Task State Transition Table

**Valid State Transitions:**


<table>
  <tr>
   <td><strong>From State</strong>
   </td>
   <td><strong>Trigger Event</strong>
   </td>
   <td><strong>Guard Condition</strong>
   </td>
   <td><strong>To State</strong>
   </td>
   <td><strong>System Action</strong>
   </td>
  </tr>
  <tr>
   <td><strong>Assigned</strong>
   </td>
   <td>Trainer begins working on the assigned task
   </td>
   <td>Trainer must be the assigned executor for this specific task.
   </td>
   <td><strong>In Progress</strong>
   </td>
   <td>System updates task status to track current workload and progress.
   </td>
  </tr>
  <tr>
   <td><strong>In Progress</strong>
   </td>
   <td>Trainer clicks "Submit Task"
   </td>
   <td>Task submission must be linked to valid, existing content (DC-04).
   </td>
   <td><strong>Submitted</strong>
   </td>
   <td>System updates status, locks the content from further editing by the Trainer, and notifies the Training Lead/Reviewer.
   </td>
  </tr>
  <tr>
   <td><strong>Submitted</strong>
   </td>
   <td>Training Lead / Reviewer clicks "Approve"
   </td>
   <td>Reviewer must NOT be the same individual as the task executor (BR-17). Content meets quality.
   </td>
   <td><strong>Approved</strong>
   </td>
   <td>System updates status to Approved, completes the task, and notifies the Trainer.
   </td>
  </tr>
  <tr>
   <td><strong>Submitted</strong>
   </td>
   <td>Training Lead / Reviewer clicks "Reject"
   </td>
   <td>Reviewer must NOT be the same individual as the task executor (BR-17). Mandatory textual feedback must be provided.
   </td>
   <td><strong>Rejected</strong>
   </td>
   <td>System updates status to Rejected/Requires Resubmission, saves feedback, unlocks content for editing, and notifies the Trainer.
   </td>
  </tr>
  <tr>
   <td><strong>Rejected</strong>
   </td>
   <td>Trainer clicks "Resubmit" after applying edits
   </td>
   <td>Content modifications must be made.
   </td>
   <td><strong>Submitted</strong>
   </td>
   <td>System updates status back to Submitted and re-notifies the Reviewer.
   </td>
  </tr>
</table>


**Invalid Transitions (must be rejected):**


<table>
  <tr>
   <td><strong>From State</strong>
   </td>
   <td><strong>Attempted Transition</strong>
   </td>
   <td><strong>Why Invalid</strong>
   </td>
   <td><strong>System Response</strong>
   </td>
  </tr>
  <tr>
   <td><strong>Assigned / In Progress</strong>
   </td>
   <td>Attempt to transition directly to Approved
   </td>
   <td>Bypasses the mandatory submission and QA review workflow required by BR-18.
   </td>
   <td>The system disables the Approve button, blocks the API request, and returns an HTTP 403 Forbidden error.
   </td>
  </tr>
  <tr>
   <td><strong>Submitted</strong>
   </td>
   <td>Attempt to edit task content
   </td>
   <td>Content must remain immutable while under review to prevent data race conditions between Trainer and Reviewer.
   </td>
   <td>The system hides edit tools and returns an HTTP 403 Forbidden error if the API is called directly.
   </td>
  </tr>
  <tr>
   <td><strong>Submitted</strong>
   </td>
   <td>Attempt to self-approve a task
   </td>
   <td>The system prohibits self-review. The task executor and reviewer cannot be the same person (BR-17).
   </td>
   <td>The system blocks the approval action, returns HTTP 403, and displays a permission error.
   </td>
  </tr>
</table>



# Part 5 — Business Rules


```
Guidance — Part 5
All Business Rules are maintained exclusively in RTW.xlsx Sheet 6 (master).
This Part contains only an Excel reference box and a quick-reference ID list.
Each FT-xx in Part 3 lists only the applicable BR IDs — never the full text.
This eliminates duplication and ensures a single update point.
```



<table>
  <tr>
   <td><strong>BR ID </strong>
   </td>
   <td><strong>One-line Description </strong>
   </td>
  </tr>
  <tr>
   <td>BR-01 
   </td>
   <td>Each learner account must use a unique identifier and cannot be registered more than once. 
   </td>
  </tr>
  <tr>
   <td>BR-02 
   </td>
   <td>Only activated accounts may access the system. 
   </td>
  </tr>
  <tr>
   <td>BR-03
   </td>
   <td>Learners may enroll only in courses with Published status. 
   </td>
  </tr>
  <tr>
   <td>BR-04 
   </td>
   <td>Learning progress is updated automatically when a lesson or quiz is completed. 
   </td>
  </tr>
  <tr>
   <td>BR-05 
   </td>
   <td>Submitted exams are final and cannot be edited or resubmitted. 
   </td>
  </tr>
  <tr>
   <td>BR-06 
   </td>
   <td>Weakness analysis is generated immediately after exam submission; failure is logged and retried automatically. 
   </td>
  </tr>
  <tr>
   <td>BR-07 
   </td>
   <td>Course recommendations are generated using predefined rule-based logic, not generative AI. 
   </td>
  </tr>
  <tr>
   <td>BR-08 
   </td>
   <td>The AI Learning Assistant responds only to questions within the learner's current learning context. 
   </td>
  </tr>
  <tr>
   <td>BR-09 
   </td>
   <td>Flashcard collections belong exclusively to the learner who created or saved them. 
   </td>
  </tr>
  <tr>
   <td>BR-10 
   </td>
   <td>Only Administrators may hide or remove comments. 
   </td>
  </tr>
  <tr>
   <td>BR-11 
   </td>
   <td>Trainers may edit only courses, exams, and question bank items that are in an editable state. 
   </td>
  </tr>
  <tr>
   <td>BR-12 
   </td>
   <td>Courses must be approved before they can be published. 
   </td>
  </tr>
  <tr>
   <td>BR-13 
   </td>
   <td>Approved courses remain invisible to learners until explicitly published by a Training Lead. 
   </td>
  </tr>
  <tr>
   <td>BR-14 
   </td>
   <td>Examinations must be approved before they can be published. 
   </td>
  </tr>
  <tr>
   <td>BR-15 
   </td>
   <td>Approved examinations remain unavailable to learners until explicitly published by a Training Lead. 
   </td>
  </tr>
  <tr>
   <td>BR-16 
   </td>
   <td>Training Leads must assign both a task executor and a task reviewer when creating a task. 
   </td>
  </tr>
  <tr>
   <td>BR-17 
   </td>
   <td>The task reviewer must not be the same trainer assigned as task executor. 
   </td>
  </tr>
  <tr>
   <td>BR-18 
   </td>
   <td>Task status must follow the defined sequence: Assigned → In Progress → Submitted → Approved / Rejected. 
   </td>
  </tr>
  <tr>
   <td>BR-19 
   </td>
   <td>Only Training Leads may publish or unpublish courses and examinations. 
   </td>
  </tr>
  <tr>
   <td>BR-20 
   </td>
   <td>Only Administrators may manage system-level permissions. 
   </td>
  </tr>
  <tr>
   <td>BR-21 
   </td>
   <td>AI usage analytics are accessible only to Administrators. 
   </td>
  </tr>
  <tr>
   <td>BR-22 
   </td>
   <td>Questions in the Question Bank may be reused across multiple quizzes and examinations. 
   </td>
  </tr>
  <tr>
   <td>BR-23 
   </td>
   <td>Each Question Group must belong to exactly one GroupType. 
   </td>
  </tr>
  <tr>
   <td>BR-24 
   </td>
   <td>Each Question must be associated with exactly one SkillType and one Difficulty Level. 
   </td>
  </tr>
</table>



# Part 6 — Non-Functional Requirements (NFR)


```
Guidance — Part 6
NFR definitions belong here. Test method, tool, measured result, and status
are tracked in RTW.xlsx Sheet 7: NFR Tracker.

Rules for writing good NFRs:
  • Measurable: '< 2 seconds' not 'must be fast'
  • Conditional: state the load / context explicitly
  • Achievable: based on real tech stack and budget
  • Categorised: group by dimension (Performance, Security, etc.)

Standard NFR categories (add/remove as needed for your project):
  6.1 Performance   6.2 Scalability   6.3 Availability & Reliability
  6.4 Security      6.5 Usability     6.6 Maintainability   6.7 Compliance
```



## 6.1  Performance


<table>
  <tr>
   <td><strong>ID</strong>
   </td>
   <td><strong>Requirement</strong>
   </td>
   <td><strong>Condition</strong>
   </td>
   <td><strong>Priority</strong>
   </td>
  </tr>
  <tr>
   <td>NFR-P01
   </td>
   <td>User-facing pages shall load within <strong>3 seconds</strong>. 
   </td>
   <td>Under normal load (≤ 100 concurrent users, broadband connection). 
   </td>
   <td>High 
   </td>
  </tr>
  <tr>
   <td>NFR-P02 
   </td>
   <td>Login requests shall be processed within <strong>2 seconds</strong>. 
   </td>
   <td>≤ 100 concurrent users. 
   </td>
   <td>High 
   </td>
  </tr>
  <tr>
   <td>NFR-P03 
   </td>
   <td>Course search results shall be returned within <strong>2 seconds</strong>. 
   </td>
   <td>The database contains up to 10,000 courses. 
   </td>
   <td>High 
   </td>
  </tr>
  <tr>
   <td>NFR-P04 
   </td>
   <td>Exam submission and score calculation shall be completed within <strong>5 seconds</strong>. 
   </td>
   <td>The exam contains up to 50 questions. 
   </td>
   <td>High 
   </td>
  </tr>
  <tr>
   <td>NFR-P05 
   </td>
   <td>Weakness analysis reports shall be generated within <strong>5 seconds</strong> after exam submission. 
   </td>
   <td>Standard exam workload. 
   </td>
   <td>High 
   </td>
  </tr>
  <tr>
   <td>NFR-P06 
   </td>
   <td>AI Learning Assistant responses shall be returned within <strong>10 seconds</strong>. 
   </td>
   <td>Normal API availability and prompts within supported context. 
   </td>
   <td>Medium 
   </td>
  </tr>
  <tr>
   <td>NFR-P07 
   </td>
   <td>Notifications shall be displayed within <strong>2 seconds</strong> after retrieval request. 
   </td>
   <td>≤ 100 notifications per user. 
   </td>
   <td>Medium 
   </td>
  </tr>
</table>



## 6.2  Scalability


<table>
  <tr>
   <td><strong>ID</strong>
   </td>
   <td><strong>Requirement</strong>
   </td>
   <td><strong>Notes</strong>
   </td>
  </tr>
  <tr>
   <td>NFR-S01
   </td>
   <td>The system shall support at least <strong>100 concurrent users</strong> without noticeable degradation. 
   </td>
   <td>Verified through load testing. 
   </td>
  </tr>
  <tr>
   <td>NFR-S02 
   </td>
   <td>The database shall support storage of at least <strong>10,000 learner accounts</strong>. 
   </td>
   <td>Based on project scope assumptions. 
   </td>
  </tr>
  <tr>
   <td>NFR-S03 
   </td>
   <td>The system shall support at least <strong>50,000 questions</strong> in the Question Bank. 
   </td>
   <td>Without requiring architectural redesign. 
   </td>
  </tr>
</table>



## 6.3  Availability & Reliability


<table>
  <tr>
   <td><strong>ID</strong>
   </td>
   <td><strong>Requirement</strong>
   </td>
   <td><strong>Notes</strong>
   </td>
  </tr>
  <tr>
   <td>NFR-A01
   </td>
   <td>Monthly system uptime shall be at least <strong>99.0%</strong>. 
   </td>
   <td>Excludes scheduled maintenance. 
   </td>
  </tr>
  <tr>
   <td>NFR-A02 
   </td>
   <td>Unexpected failures shall be logged automatically. 
   </td>
   <td>Logs retained for troubleshooting. 
   </td>
  </tr>
  <tr>
   <td>NFR-A03 
   </td>
   <td>The system shall preserve submitted exam data without loss during unexpected interruptions. 
   </td>
   <td>Transaction integrity required. 
   </td>
  </tr>
  <tr>
   <td>NFR-A04 
   </td>
   <td>Failed weakness analysis generation shall be retried automatically. 
   </td>
   <td>Consistent with BR-06. 
   </td>
  </tr>
</table>



## 6.4  Security


<table>
  <tr>
   <td><strong>ID</strong>
   </td>
   <td><strong>Requirement</strong>
   </td>
   <td><strong>Notes</strong>
   </td>
  </tr>
  <tr>
   <td>NFR-SEC01
   </td>
   <td>All communication shall use <strong>HTTPS with TLS 1.2 or above</strong>. 
   </td>
   <td>HTTP requests redirect to HTTPS. 
   </td>
  </tr>
  <tr>
   <td>NFR-SEC02 
   </td>
   <td>Passwords shall be stored using secure one-way hashing algorithms (e.g., BCrypt). 
   </td>
   <td>Plain-text passwords are prohibited. 
   </td>
  </tr>
  <tr>
   <td>NFR-SEC03 
   </td>
   <td>Role-based access control (RBAC) shall be enforced for all protected operations. 
   </td>
   <td>Based on the Permission Matrix. 
   </td>
  </tr>
  <tr>
   <td>NFR-SEC04 
   </td>
   <td>User sessions shall expire automatically after <strong>30 minutes of inactivity</strong>. 
   </td>
   <td>Re-authentication required. 
   </td>
  </tr>
  <tr>
   <td>NFR-SEC05 
   </td>
   <td>Failed login attempts shall be logged for audit purposes. 
   </td>
   <td>Supports security monitoring. 
   </td>
  </tr>
</table>



## 6.5  Usability


<table>
  <tr>
   <td><strong>ID</strong>
   </td>
   <td><strong>Requirement</strong>
   </td>
   <td><strong>Notes</strong>
   </td>
  </tr>
  <tr>
   <td>NFR-U01
   </td>
   <td>The system shall provide a responsive user interface for desktop and mobile devices. 
   </td>
   <td>Chrome, Edge, mobile browsers. 
   </td>
  </tr>
  <tr>
   <td>NFR-U02 
   </td>
   <td>Learners shall be able to complete core learning activities without external guidance. 
   </td>
   <td>Verified through user acceptance testing. 
   </td>
  </tr>
  <tr>
   <td>NFR-U03 
   </td>
   <td>Error messages shall clearly describe the issue and recommended corrective action. 
   </td>
   <td>Avoid technical jargon. 
   </td>
  </tr>
  <tr>
   <td>NFR-U04 
   </td>
   <td>The user interface shall maintain consistent navigation and terminology across modules. 
   </td>
   <td>Based on approved UI guidelines. 
   </td>
  </tr>
</table>



## 6.6  Maintainability


<table>
  <tr>
   <td><strong>ID</strong>
   </td>
   <td><strong>Requirement</strong>
   </td>
   <td><strong>Notes</strong>
   </td>
  </tr>
  <tr>
   <td>NFR-M01
   </td>
   <td>Source code shall follow agreed coding standards and naming conventions. 
   </td>
   <td>Enforced through code review. 
   </td>
  </tr>
  <tr>
   <td>NFR-M02 
   </td>
   <td>All source code changes shall be tracked using Git version control. 
   </td>
   <td>GitHub repository. 
   </td>
  </tr>
  <tr>
   <td>NFR-M03 
   </td>
   <td>New features shall be developed through feature branches and Pull Requests. 
   </td>
   <td>Simplified Git workflow. 
   </td>
  </tr>
  <tr>
   <td>NFR-M04 
   </td>
   <td>System components shall follow a modular architecture to facilitate future enhancement. 
   </td>
   <td>Spring Boot layered design. 
   </td>
  </tr>
</table>



## 6.7  Compliance


```
Guidance — Compliance NFRs
List legal and regulatory requirements relevant to your project context.
Common examples: data retention law, personal data protection, financial reporting.
Always state the specific regulation or policy — not just 'comply with the law'.
```



<table>
  <tr>
   <td><strong>ID</strong>
   </td>
   <td><strong>Requirement</strong>
   </td>
   <td><strong>Regulatory Basis</strong>
   </td>
  </tr>
  <tr>
   <td>NFR-C01
   </td>
   <td>Personal data collected by the system shall be used only for educational and operational purposes defined by HanGo. 
   </td>
   <td>Vietnam's Personal Data Protection Decree No. 13/2023/ND-CP 
   </td>
  </tr>
  <tr>
   <td>NFR-C02 
   </td>
   <td>Users shall access only information and functions permitted by their assigned roles. 
   </td>
   <td>Internal Information Security Policy 
   </td>
  </tr>
  <tr>
   <td>NFR-C03 
   </td>
   <td>User activity logs shall be retained to support troubleshooting and audit activities throughout the project lifecycle. 
   </td>
   <td>Internal Operational Policy 
   </td>
  </tr>
</table>





# Appendices


## Appendix A — RTW.xlsx Reference


```
All tracking artefacts → [ProjectName]_RTW.xlsx
Sheet 1: Overview Dashboard     Sheet 2: Use Case List
Sheet 3: Feature Traceability   Sheet 4: Permission Matrix
Sheet 5: Data Dictionary        Sheet 6: Business Rules Register
Sheet 7: NFR Tracker            Sheet 8: Open Issues Log
Sheet 9: Change Log
```



## Appendix B — Diagram Index


```
Guidance — Diagram Index
List every diagram referenced in this SRS.
For each: diagram type, where it is referenced, and the source draw.io filename.
When the diagram is created, export as PNG and embed at the placeholder location.
```



<table>
  <tr>
   <td><strong>Diagram</strong>
   </td>
   <td><strong>Type</strong>
   </td>
   <td><strong>Referenced in</strong>
   </td>
   <td><strong>File Name</strong>
   </td>
  </tr>
  <tr>
   <td>[Diagram name]
   </td>
   <td>[Type: Context / UC / ERD / State Machine / Activity / Sequence]
   </td>
   <td>[Part X.Y]
   </td>
   <td>[ProjectName]_[Name].drawio
   </td>
  </tr>
  <tr>
   <td>[Add rows]
   </td>
   <td>
   </td>
   <td>
   </td>
   <td>
   </td>
  </tr>
</table>


*— End of Template —*
