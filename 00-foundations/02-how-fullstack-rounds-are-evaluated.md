# 02 — How Full Stack Rounds Are Evaluated

## 🎬 The Story

Two candidates, Arjun and Meera, both interview at Freshworks on the same day for the same role. Both build a blog platform. Both "finish."

Arjun's app looks stunning — animated cards, a dark-mode toggle, a slick font. But when the interviewer creates a post with an empty title, the server throws a 500 and the page goes blank. There's no login; anyone can edit anyone's post. Passwords are stored as plain text in the database.

Meera's app looks plain — default fonts, no animations. But every endpoint returns the right status code. Empty title? A clean `400` with a helpful message and a red hint under the input. Posts are scoped to the logged-in user. Passwords are hashed. Her schema has proper foreign keys and an index on the column she filters by.

**Meera gets the offer.** Arjun doesn't. The lesson: interviewers grade against a **rubric**, and "pretty" is only one small box on it.

Here is that rubric, demystified.

---

## 📊 The 7-Dimension Scoring Rubric

Product companies converge on roughly the same seven dimensions. For each, here is **what excellent looks like, what average looks like, and what gets you rejected.**

---

### Dimension 1 — Working End-to-End Demo
*"Can I actually click through it?"*

This is the gate. If the interviewer cannot perform the core flow, almost nothing else can save you.

- 🟢 **Excellent:** The full happy path works live — register, log in, create, read, update, delete — without the interviewer needing hints or restarts.
- 🟡 **Average:** Core flow works but with a manual step ("you have to refresh after creating") or one broken sub-feature.
- 🔴 **Rejection:** The app doesn't run, the server crashes on a normal action, or "it works on my machine" but not when they try it.

---

### Dimension 2 — API Design Quality
*"Are the routes RESTful? Are status codes correct?"*

- 🟢 **Excellent:** Resource-based URLs (`POST /todos`, `GET /todos/:id`), correct verbs, correct status codes (`201` on create, `404` on missing, `400` on bad input), a consistent response envelope.
- 🟡 **Average:** Mostly sensible routes but inconsistent (some `/getTodos`, some `/todos`), or returns `200` for everything.
- 🔴 **Rejection:** State-changing operations on `GET` (e.g. `GET /deleteTodo?id=5`), no status codes, chaotic naming.

---

### Dimension 3 — Database Schema Design
*"Is the data modeled correctly?"*

- 🟢 **Excellent:** Sensible tables, primary keys, **foreign keys with constraints**, appropriate normalization, an index on columns you filter/join on, correct data types.
- 🟡 **Average:** Workable schema but missing foreign key constraints, or one denormalized blob where a relation belonged.
- 🔴 **Rejection:** Everything in one table, no keys, storing comma-separated lists in a text column instead of a relation.

---

### Dimension 4 — React Code Quality
*"Is the frontend well-structured?"*

- 🟢 **Excellent:** Clear component breakdown, state lives at the right level, API calls isolated (in a hook or api module), no needless re-renders, controlled forms.
- 🟡 **Average:** One giant component doing everything, but it works.
- 🔴 **Rejection:** Direct DOM manipulation, state duplicated everywhere and out of sync, fetch calls copy-pasted inline in five places.

---

### Dimension 5 — Backend Code Quality
*"Is the server code maintainable?"*

- 🟢 **Excellent:** Separation of concerns — routes thin, logic in services/models, a central error-handling middleware, `async/await` wrapped in `try/catch`, a DB connection pool.
- 🟡 **Average:** All logic crammed in route handlers, but readable and functional.
- 🔴 **Rejection:** Raw SQL string-concatenated inline, no error handling, the server process dies on the first thrown error.

---

### Dimension 6 — Security Basics
*"Did you do the non-negotiables?"*

- 🟢 **Excellent:** Passwords hashed with bcrypt, JWT on protected routes, **parameterized queries** [SQL where user input is sent separately from the query text, preventing injection], input validation on every write endpoint.
- 🟡 **Average:** Hashing and auth present, but validation is thin or inconsistent.
- 🔴 **Rejection:** Plain-text passwords, no auth on routes that clearly need it, string-concatenated SQL (SQL-injectable).

---

### Dimension 7 — Edge Case Handling
*"What happens when things go wrong?"*

- 🟢 **Excellent:** Empty states ("No todos yet"), loading spinners, error messages on failed requests, validation feedback, handles the "not found" and "not authorized" cases.
- 🟡 **Average:** Handles the happy path and one or two edge cases.
- 🔴 **Rejection:** Blank screen on error, infinite spinner, app crashes on empty input.

---

## 🧮 How the Dimensions Are Weighted (rough mental model)

No two interviewers use identical weights, but a useful approximation:

| Dimension | Rough weight | Why |
|-----------|-------------|-----|
| 1. Working demo | ~25% | The gate. Nothing matters if it doesn't run. |
| 2. API design | ~15% | The contract everything depends on. |
| 3. Schema design | ~15% | The foundation; hard to fix later. |
| 4. React quality | ~15% | Where many candidates show or lose maturity. |
| 5. Backend quality | ~10% | Maintainability signal. |
| 6. Security basics | ~10% | Non-negotiables; missing them flags risk. |
| 7. Edge cases | ~10% | Separates "junior" from "senior." |

> 💡 Notice: **40% of your score (Dimensions 1–3) is locked in by your schema + API + a working core flow.** This is *why* the whole course teaches schema-first.

---

## 🎯 The "Senior vs Junior" Tell

Interviewers say the single fastest way they separate levels is **edge case handling and error states**. A junior builds the happy path and stops. A senior, *unprompted*, adds:

- An empty state ("You have no transactions yet").
- A loading state (so the screen isn't frozen-looking).
- An error state (so a failed request shows a message, not a blank page).
- Server-side validation that returns a clean `400`, not a `500` crash.

Doing these *without being asked* signals you've shipped real software.

---

## ✅ Key Takeaways

1. You are graded on **7 dimensions**, not on looks.
2. ~40% of the score is your schema, API, and a working core flow — secured in the first half of the round.
3. Security non-negotiables (hashing, parameterized queries, auth) can single-handedly cause rejection if missing.
4. **Unprompted edge-case handling** is the clearest senior signal you can send.

---

## 🔗 Navigation
⬅️ Previous: [01 — What Is a Full Stack Machine Coding Round](./01-what-is-fullstack-machine-coding-round.md)
➡️ Next: [03 — REST API Design Fundamentals](./03-rest-api-design-fundamentals.md)
🏠 [Module Home](./README.md)
