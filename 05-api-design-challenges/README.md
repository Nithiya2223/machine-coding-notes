# Module 05 — API Design Challenges

> These aren't full-feature builds — they're the *cross-cutting API qualities* that separate a hobby API from a production one. They show up as follow-up questions in almost every round ("now paginate it," "what status code?", "make the retry safe") and as the entire focus at API-first companies like Postman and Stripe.

---

## 📚 Challenges in this module

| # | Challenge | Companies | Core idea |
|---|-----------|-----------|-----------|
| 01 | [Pagination Strategies](./01-pagination-strategies.md) | Google, Meta, Razorpay, Postman | Offset vs keyset/cursor; deep-page + drift problems |
| 02 | [API Versioning](./02-api-versioning.md) | Postman, Stripe, Razorpay, Atlassian | Breaking changes, URL vs header versioning, deprecation |
| 03 | [Error Handling & Response Contracts](./03-error-handling-contracts.md) | Stripe, Razorpay, Postman, Atlassian | Consistent envelope, status codes, stable error codes |
| 04 | [Idempotency in APIs](./04-idempotency-in-apis.md) | Stripe, Razorpay, PhonePe, Juspay | **Idempotency keys** — safe retries, no double charge |

---

## 🧠 The throughline

A production API is **predictable under stress**: it pages large data without falling over, evolves without breaking clients, fails with a consistent contract, and survives retries without duplicating effects. Master these four and you can defend any endpoint design an interviewer probes.

> Module 03's Payment Checkout problem applies idempotency end-to-end; this module's `04-idempotency-in-apis.md` is the standalone deep-dive on the concept itself.

---

## 🔗 Navigation
🏠 [Course Home](../README.md)
⬅️ Previous module: [04 — Advanced Full Stack Questions](../04-advanced-fullstack-questions/README.md)
➡️ Next module: [06 — Database Design Challenges](../06-database-design-challenges/README.md)
