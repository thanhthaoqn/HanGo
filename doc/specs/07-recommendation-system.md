# Feature Specification: FT-07 - Recommendation System

## 1. Business Context
To personalize learning paths, the Recommendation System analyzes exam results or a Learner's learning history to suggest the next lessons, flashcards, or courses. This is an advanced (Rule-based) feature that intelligently helps Learners patch knowledge gaps, increasing user retention rates.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] The Dashboard screen or Exam Result screen features a "Suggested for you" section.
- [ ] Display a list of courses or lessons as a Card Carousel.
- [ ] Call the API to get recommendations and handle the Empty State (If the system lacks sufficient data to make suggestions).

**Backend (Spring Boot):**
- [ ] API `GET /api/v1/recommendations` returns a list of Courses/Lessons.
- [ ] Rule-based Engine Logic: 
  - Analyze the `exam_attempts` and `exam_results` tables.
  - If the exam score in a specific subject (Skill/Category) is < 50%, suggest a Basic level course in that Category.
  - If the score is >= 80%, suggest an Advanced level course or a new trending course.
- [ ] Map the response via a standard DTO.

## 3. Technical Constraints
- **Backend:** The Rule-based algorithm should be isolated into a dedicated `@Service` component (e.g., `RecommendationEngineService`) to easily upgrade to Machine Learning in the future without affecting the Controller's business logic.
- **Database:** Analytical queries on historical data must be optimized (Using JOINs and INDEXes on the `learner_id` and `category_id` columns) to prevent database bottlenecking.

## 4. Edge Cases
- **Brand New User (Cold Start Problem):** No exam history available.
  - *Solution:* Suggest the highest-rated courses (Top Rated) or "For Beginners" courses.
- **System Suggests Completed Courses:** 
  - *Solution:* The Backend must exclude (`NOT IN`) the list of courses where `status = COMPLETED` in the `learner_courses` table.

## 5. Non-functional Requirements
- **Performance:** Recommendation calculations (Based on SQL rules) can be heavy, requiring a Caching mechanism (e.g., Spring Cache or Memcached/Redis if available) to store suggestion results for 1-2 hours. API response time should be `< 500ms`.
- **User Experience:** Thumbnail images for suggested courses must be loaded asynchronously (Cached Network Image in Flutter).
