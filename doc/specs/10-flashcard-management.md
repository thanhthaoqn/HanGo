# Feature Specification: FT-10 - Flashcard Management

## 1. Business Context
In addition to traditional lessons, Flashcards are an excellent learning support tool (especially for languages and concepts) thanks to the Spaced Repetition method. Learners can create their own Flashcard Collections or study shared Flashcard sets provided by Trainers to memorize knowledge deeper.

## 2. Acceptance Criteria

**Frontend (Flutter):**
- [ ] Flashcard Collection Management screen (Create, Update, Delete Collection).
- [ ] UI to create individual Flashcards containing a Front (Term) and a Back (Definition).
- [ ] "Study Mode" interface simulating card flipping (Flip Animation) and swiping (Swipe Left/Right to mark as Remembered/Not Remembered).

**Backend (Spring Boot):**
- [ ] CRUD APIs for Collections: `POST /api/v1/flashcard-collections`, `GET`, `PUT`, `DELETE`.
- [ ] CRUD APIs for child Cards: `POST /api/v1/collections/{id}/flashcards`.
- [ ] (Optional) API `POST /api/v1/flashcards/{id}/review` to record study results (increasing difficulty, scheduling next repetition).

## 3. Technical Constraints
- **Frontend:** Handling card flipping and swiping requires Animation skills (using `AnimatedContainer` or `Transform` in Flutter). It must run smoothly at 60fps.
- **Backend:** Flashcards owned by a User can only be viewed/edited by that User (Unless the collection is configured as Public). Use `@PostAuthorize` or filter data at the Service layer (checking `user_id`).

## 4. Edge Cases
- **Creating an empty collection:** The "Study Mode" interface must display an Empty State and disable the Start button.
- **Overly large collection (> 500 cards):** Loading the entire list of child cards at once might lag the app. Backend needs Pagination for the card fetching API. Frontend automatically uses "Load More" or pre-loads the first 50 cards to study.
- **Deleting a collection:** When deleting a Collection, all Flashcards inside must also be deleted (Cascading).

## 5. Non-functional Requirements
- **Performance:** Card flipping must respond instantly on the UI (< 16ms since it renders locally). API calls reporting card status should run silently in the background (Fire and Forget) to avoid interrupting the user's study flow.
- **Test:** Frontend requires Widget tests for the Flashcard Flip component.
