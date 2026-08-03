# HanGo — Authentication Module Security Fix & Redesign

> **Scope:** `hango-backend` Authentication module (Register, Email Verification, Login, Google Login, Forgot/Reset Password, Logout, JWT/Refresh Token) plus the minimal `hango-frontend` wiring needed to keep those flows working. Companion to [`AUDIT_REPORT.md`](AUDIT_REPORT.md) — this pass fixes GAP-AUTH-01 and MED-11 from that report and 3 additional critical vulnerabilities found during this task that were not previously documented.
> **As of:** 2026-08-01, branch `dev`.
> **Method:** direct source read, not inferred from docs. All findings below were verified against the actual code before being fixed; `AuthServiceTest` (83 tests) exercises every behavior described here.

---

## 1. Bugs / security issues found

### 🔴 Critical (new — not in `AUDIT_REPORT.md`)

1. **Unauthenticated password reset → full account takeover.** `POST /api/auth/reset-password` took only `{email, newPassword}` and never checked any OTP or token. Anyone who knew a victim's email address could set their password to anything, with no proof of ownership of the account, the email inbox, or a prior OTP request.
2. **Unauthenticated email verification.** `GET /api/auth/verify` took a bare `email` query parameter with no token. Anyone could mark any email address as "verified" by calling this URL directly — defeating the entire purpose of proving email ownership, and allowing an attacker to register with someone else's email and self-verify without ever touching that inbox.
3. **Google Login signature-bypass fallback.** When `GoogleIdTokenVerifier.verify()` returned `null`, `AuthService.googleLogin` fell back to `GoogleIdToken.parse()`, which decodes a JWT's payload **without checking its signature**. Any caller could hand-craft an unsigned token whose issuer string contained `"accounts.google.com"` and log in as any email address, including accounts that never used Google Sign-In.

### 🟠 High (previously known, now fixed)

4. **GAP-AUTH-01.** `authenticateUser` never checked `isVerified` at all, and only blocked the literal string `"INACTIVE"` for `status` — a `LOCKED`, `DISABLED`, or any other non-`"ACTIVE"` status logged in successfully. This is the bug explicitly called out in the task brief ("user can login immediately after Register without verifying email").
5. **No brute-force protection.** Unlimited login attempts against any account, no lockout.
6. **MED-11.** No refresh token, no logout endpoint, no way to revoke a session. A single 24h JWT was the only credential and could not be invalidated.

### 🟡 Medium (previously known, now fixed)

7. OTP was not single-use, had no attempt limit, and no resend cooldown — `verifyOtp` could be called indefinitely.
8. No password complexity rule beyond length (min 8 / max 32); no server-side confirm-password check.
9. Email uniqueness/lookup was case-sensitive at the application layer (`Test@a.com` vs `test@a.com` could both register).
10. `forgotPassword` revealed whether an email was registered via a distinct error message (user enumeration).

---

## 2. Business-logic issues found

- A newly registered account could log in before verifying its email — now blocked (fix #4).
- Password reset didn't force re-login elsewhere, and didn't invalidate the old refresh tokens — now `resetPassword` and `changePassword` both call `refreshTokenRepository.deleteByUser(user)`.
- Reset/change password allowed setting the *same* password again — now rejected (`encoder.matches(newPassword, currentHash)`).
- Google JIT-provisioned accounts and self-registered accounts used two different code paths to reach `LoginResponse` — both now issue a refresh token consistently.

---

## 3. APIs modified

| Endpoint | Change |
|---|---|
| `POST /api/auth/login` | Now returns `refreshToken` in the response; rejects unverified/locked/non-active accounts with 403/423 instead of silently succeeding; bad credentials → 401 (was blanket 400). |
| `POST /api/auth/register` | Requires new `confirmPassword` field; `password` must meet the complexity policy (upper/lower/digit/special, 8–64 chars, matches what `reset_password_page.dart` already enforced client-side); duplicate email → 409 (was 400). |
| `GET /api/auth/verify` | Query param changed from `email` to `token` (opaque, single-use, 24h expiry). |
| `POST /api/auth/reset-password` | Requires new `otpCode` field, validated server-side against the stored OTP before any password change is allowed. |
| `POST /api/auth/forgot-password` | Always returns a generic success message regardless of whether the email is registered (no more enumeration); silently no-ops within a 60s cooldown per email. |
| `POST /api/auth/refresh-token` | **New.** Exchanges a valid refresh token for a new access token + rotated refresh token. |
| `POST /api/auth/logout` | **New.** Revokes the presented refresh token. |
| `POST /api/auth/verify-otp`, `POST /api/auth/resend-verification` | Behavior only (attempt/resend limits); request/response shape unchanged. |

`hango-frontend/lib/data/services/auth_service.dart` was updated to match: stores/sends the refresh token, `logout()` calls the new `/logout` endpoint, `resetPassword()` takes `otpCode`, `register()` takes `confirmPassword`. `register_page.dart`, `verify_otp_page.dart`, `reset_password_page.dart` updated to pass the new fields through.

---

## 4. Database changes (Hibernate auto-ddl, no migration tool per current project convention)

- `users`: + `verification_token`, `verification_token_expiry`, `failed_login_attempts`, `locked_until`.
- `password_reset_otps`: + `attempt_count`, `consumed`, `last_sent_at`.
- New table `refresh_tokens`: `id`, `user_id`, `token_hash` (SHA-256 of an opaque random token — never stores the raw token), `expires_at`, `revoked`, `created_at`.

---

## 5. Unit tests added

`AuthServiceTest.java` grew from ~65 to **83 tests**, all passing (`mvnw test -Dtest=AuthServiceTest`). New coverage: lockout after 5 failed attempts / 15-minute lock, verified-status gate, Google fallback-removal regression test, OTP attempt-limit/single-use/cooldown, reset-password OTP requirement, refresh-token rotation/revocation, logout idempotency, "new password == old password" rejection on both reset and change-password. Full backend suite (`mvnw test`) run to confirm no regressions: the only failing classes (`CourseManagerDashboardServiceTest`, `TrainerOnboardingServiceTest`) were verified to fail identically on the pre-change code — unrelated pre-existing issues, not touched by this task.

---

## 6. Explicitly out of scope (flagged for separate sign-off)

- `TestDBController` unauthenticated account takeover, comment/lesson endpoints trusting a client-supplied `userId`, trainer content endpoints missing `@PreAuthorize` — real, but different modules (`AUDIT_REPORT.md` CRIT-01/02/04).
- Frontend has no centralized HTTP client (`AUDIT_REPORT.md` HIGH-06); the new refresh token is issued, stored, and revocable, but nothing auto-refreshes on a 401 across the app's 59 other call sites yet — access-token lifetime was deliberately **left at 24h** (not shortened) to avoid forcing frequent re-logins until that interceptor exists.
- `ProfileUpdateRequest` has no `@Valid` annotations (GAP-PROF-03) — profile update, not authentication.

---

## 7. Manual QA checklist

- [ ] Register with a weak password (e.g. `password`) → rejected with a complexity message.
- [ ] Register, then attempt login immediately → rejected (403, "verify your email").
- [ ] Click the verification link from the (console-logged in dev) email → account becomes verified → login succeeds.
- [ ] Re-click the same verification link → rejected ("already verified").
- [ ] Fail login 5 times in a row → 6th attempt rejected with a lockout message even with the correct password; wait/simulate 15 minutes → login succeeds again.
- [ ] Forgot-password with an unregistered email → generic success response, no email actually sent.
- [ ] Forgot-password with a registered email → OTP received; enter wrong OTP 5 times → OTP invalidated, must request a new one.
- [ ] Complete forgot → verify-otp → reset-password with the correct OTP → old password no longer works, new one does; try reusing the same OTP again → rejected.
- [ ] Log in on two devices/browsers, reset the password from a third → the other two are logged out on their next API call (refresh token revoked).
- [ ] Log out → the used refresh token can no longer be exchanged via `/refresh-token`.
- [ ] Google Sign-In with a real Google account → works; a hand-crafted/forged token → rejected (was previously exploitable).
