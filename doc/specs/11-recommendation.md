# Feature Specification: FT-07 - Recommendation System

## 1. Business Context
To personalize learning paths, the Recommendation System analyzes exam results or a Learner's learning history to generate recommendations. This includes standard rule-based course recommendations and a dynamic, personalized **Adaptive Learning Pathway** (visual node tree roadmap) monitored by an **AI Mentor** agent.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] "Suggested for you" Carousel on the Learner Dashboard.
- [ ] Adaptative Learning Pathway Page showing an Interactive Node Tree (Duolingo-style node statuses: locked/gray, in-progress/glowing, completed/green).
- [ ] AI Mentor Side Panel featuring a chat interface (markdown response rendering, typing indicator, free text input).

**Backend (Spring Boot):**
- [ ] API endpoints `/api/v1/pathways/generate` and `/api/v1/pathways/me` to retrieve/construct node structures.
- [ ] API `/api/v1/pathways/{id}/chat` to exchange messages with the AI Mentor.
- [ ] Rule-based Engine Logic: evaluates `exam_attempts` and maps low scoring SkillTypes (< 50%) to beginner courses (max 3 SkillTypes per course mapping).
- [ ] AI Pathway Generation Service: constructs a structured roadmap JSON outlining learning steps.

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

