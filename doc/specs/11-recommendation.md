# Feature Specification: FE-11 — Recommendation

> Ref: [HanGo_Documentation.md](../HanGo_Documentation.md) §7.11 (REC)

## 1. Business Context
To personalize learning paths, the Recommendation System runs a **Weakness Analysis by SkillType** after each Exam attempt, then matches weak SkillTypes to Courses tagged with that SkillType (every Course carries **up to 3 SkillTypes** — BR-REC-01). On top of the rule-based match, an AI Recommendation and an AI Learning Pathway (generated roadmap) personalize the suggestion further. There is no "flashcard" concept and no Course "Basic/Advanced level" tiering in HanGo — matching is purely SkillType-based, not a numeric score threshold mapped to a difficulty tier.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] The Dashboard screen or Exam Result screen features a "Suggested for you" section.
- [ ] Display a list of recommended Courses as a Card Carousel.
- [ ] Call the API to get recommendations and handle the Empty State (If the system lacks sufficient data to make suggestions, e.g. no Exam attempt yet).

**Backend (Spring Boot):**
- [ ] API `GET /api/v1/recommendations` returns a list of Courses matched by weak SkillType.
- [ ] Rule-based Engine Logic:
  - Analyze the latest `exam_attempts` result to compute per-SkillType error rate (Weakness Analysis, FR-REC-01).
  - For each weak SkillType, suggest Courses that carry that SkillType among their (≤3) tagged SkillTypes (FR-REC-02 / BR-REC-01) — no score-threshold "Basic/Advanced" tiering.
- [ ] AI Recommendation + AI Learning Pathway endpoints build on top of the same Weakness Analysis (FR-REC-03/04).
- [ ] Map the response via a standard DTO.

## 3. Technical Constraints
- **Agentic Upgrade (Function Calling):** The AI Mentor must use Gemini Function Calling to execute backend tools dynamically, specifically:
  - `triggerReroute(pathwayId, reason)` to restructure nodes if lessons are "too hard" or "too easy".
  - `getPathwayById(id)` to query current structures.
  - `getUserProgressSnapshot(userId)` to evaluate learner performance.
- **Long-term Memory & Cache:**
  - Store chat histories in `ai_chat_histories` table with context truncation (keeping last 5-10 messages and system instructions).
  - Cache learner profiles (strengths and weaknesses) in the database to optimize AI prompt injections.
- **Database:** Optimize queries on `exam_attempts` and `enrollments` tables.

## 4. Edge Cases
- **Off-topic Prompts:** The AI Mentor prompt must include strict directives to detect non-educational requests (`wasOutOfScope`) and respond with a friendly educational-only guardrail template.
- **Review Loop Flagging:** If a pathway is rerouted $\ge 3$ times, flag it for manual Course Manager review and prompt a "Report bad roadmap" feedback link.

## 5. Non-functional Requirements
- **Performance:** Pathway generation and AI responses must render with friendly loading placeholders. Chat API response time target `< 1500ms` for streaming or non-streaming responses.

