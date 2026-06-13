# 03 — Error Handling & Response Contracts

🏢 **Asked at:** Stripe, Razorpay, Postman, Atlassian

> A great API is as much about its *errors* as its successes. This challenge: a consistent response envelope, correct status codes, machine-readable error codes, field-level validation errors, and an Express error pipeline that never crashes the server.

---

## 🎬 The Story

A frontend dev integrates your API. Sometimes errors come back as `{ error: "bad" }`, sometimes `{ message: "..." }`, sometimes a raw HTML stack trace with a `200` status. They can't write reliable error handling because there's no *contract*. Worse, one malformed request crashes your Node process. A disciplined error contract — predictable shape, correct status codes, stable error codes — turns your API from frustrating to a joy to build against. Stripe and Postman, whose customers *are* developers, treat this as a first-class feature.

---

## 📦 The Response Contract

**Every** response uses one of two shapes. Consistency is the whole point.

**Success:**
```json
{ "success": true, "data": { "id": 42, "title": "Buy milk" } }
```

**Error:**
```json
{
  "success": false,
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Title is required",
    "details": [
      { "field": "title", "issue": "required" }
    ]
  }
}
```

> **Why a stable `code`?** Clients should branch on `error.code === "INSUFFICIENT_FUNDS"`, never on the *message text* (which gets reworded, translated, or A/B-tested). The code is the contract; the message is for humans.

---

## 🔢 Status Code Discipline

| Code | When | `error.code` example |
|------|------|----------------------|
| `400` | Malformed/invalid input | `VALIDATION_ERROR` |
| `401` | Not authenticated | `UNAUTHENTICATED` |
| `403` | Authenticated, not allowed | `FORBIDDEN` |
| `404` | Resource missing | `NOT_FOUND` |
| `409` | Conflict with current state | `ALREADY_EXISTS` |
| `422` | Semantically invalid | `UNPROCESSABLE` |
| `429` | Rate limited | `RATE_LIMITED` |
| `500` | Unexpected server error | `INTERNAL_ERROR` |

> The HTTP status is for the *transport layer and tooling* (proxies, retries, monitoring); the `error.code` is for *application logic*. Use both, correctly and together.

---

## 💻 The Error Pipeline (Express)

```javascript
// File: server/errors/AppError.js
// A typed error carrying an HTTP status + stable code + safe message.
class AppError extends Error {
  constructor(statusCode, code, message, details) {
    super(message);
    this.statusCode = statusCode;
    this.code = code;
    this.details = details;
  }
}
// Convenience factories for common cases.
const errors = {
  validation: (message, details) => new AppError(400, "VALIDATION_ERROR", message, details),
  unauthenticated: () => new AppError(401, "UNAUTHENTICATED", "Authentication required"),
  forbidden: () => new AppError(403, "FORBIDDEN", "You don't have access to this resource"),
  notFound: (what = "Resource") => new AppError(404, "NOT_FOUND", `${what} not found`),
  conflict: (message) => new AppError(409, "ALREADY_EXISTS", message),
};
module.exports = { AppError, errors };
```

```javascript
// File: server/middleware/asyncHandler.js
// Forward any rejected promise to the error handler instead of crashing Node.
const asyncHandler = (fn) => (req, res, next) => Promise.resolve(fn(req, res, next)).catch(next);
module.exports = { asyncHandler };
```

```javascript
// File: server/middleware/errorHandler.js
const { AppError } = require("../errors/AppError");

// The ONE place errors become responses. Registered LAST.
function errorHandler(err, req, res, next) {
  // Known, intentional errors map cleanly to the contract.
  if (err instanceof AppError) {
    return res.status(err.statusCode).json({
      success: false,
      error: { code: err.code, message: err.message, details: err.details },
    });
  }

  // Map common library errors (example: Postgres unique violation -> 409).
  if (err.code === "23505") {
    return res.status(409).json({
      success: false,
      error: { code: "ALREADY_EXISTS", message: "Resource already exists" },
    });
  }

  // Anything else is an unexpected bug: log it fully, expose nothing internal.
  console.error("[UNHANDLED]", err);
  res.status(500).json({
    success: false,
    error: {
      code: "INTERNAL_ERROR",
      message: "Something went wrong",
      // Only in development, never leak stack traces to clients in prod.
      ...(process.env.NODE_ENV === "development" ? { debug: err.message } : {}),
    },
  });
}
module.exports = { errorHandler };
```

```javascript
// File: server/middleware/validate.js  (field-level validation errors)
// Returns 400 with a details array pinpointing each bad field.
function validateBody(schema) {
  return (req, res, next) => {
    const details = [];
    for (const [field, rule] of Object.entries(schema)) {
      const value = req.body[field];
      if (rule.required && (value === undefined || value === null || value === "")) {
        details.push({ field, issue: "required" });
      } else if (value !== undefined && rule.type && typeof value !== rule.type) {
        details.push({ field, issue: `expected ${rule.type}` });
      }
    }
    if (details.length) {
      const { errors } = require("../errors/AppError");
      return next(errors.validation("Validation failed", details)); // -> 400 with details
    }
    next();
  };
}
module.exports = { validateBody };
```

```javascript
// File: server/routes/example.js  (using the contract)
const express = require("express");
const router = express.Router();
const { errors } = require("../errors/AppError");
const { validateBody } = require("../middleware/validate");
const { asyncHandler } = require("../middleware/asyncHandler");
const { query } = require("../db");

router.post("/items",
  validateBody({ title: { required: true, type: "string" } }),
  asyncHandler(async (req, res) => {
    const { rows } = await query("INSERT INTO items (title) VALUES ($1) RETURNING id, title", [req.body.title]);
    res.status(201).json({ success: true, data: rows[0] });   // success contract
  })
);

router.get("/items/:id", asyncHandler(async (req, res) => {
  const { rows } = await query("SELECT id, title FROM items WHERE id=$1", [req.params.id]);
  if (!rows[0]) throw errors.notFound("Item");                 // -> 404 NOT_FOUND, handled centrally
  res.json({ success: true, data: rows[0] });
}));

module.exports = router;
```

### Frontend — one place to handle every error
```javascript
// File: client/src/api/client.js
export async function apiFetch(path, options = {}) {
  const res = await fetch(`/api/v1${path}`, {
    ...options,
    headers: { "Content-Type": "application/json", ...(options.headers || {}) },
  });
  if (res.status === 204) return null;
  const json = await res.json();
  if (!json.success) {
    // Throw a structured error the UI can branch on by CODE, not message text.
    const err = new Error(json.error.message);
    err.code = json.error.code;
    err.details = json.error.details;
    throw err;
  }
  return json.data;
}

// Usage: catch (e) { if (e.code === "VALIDATION_ERROR") highlightFields(e.details); }
```

### What You Will See
Every response — success or failure — has a predictable shape. A missing title returns `400` with `{ code:"VALIDATION_ERROR", details:[{field:"title", issue:"required"}] }`, and the form highlights exactly the `title` field. A missing item returns `404 NOT_FOUND`. A duplicate returns `409 ALREADY_EXISTS`. An unexpected bug returns `500 INTERNAL_ERROR` with **no stack trace leaked** — and the server stays up (the error handler caught it). The frontend's single `apiFetch` turns every error into a thrown object the UI branches on by `code`.

---

## ⚠️ Non-Obvious Traps

🔴 **Trap 1:** Inconsistent error shapes across endpoints.
✅ One envelope everywhere, enforced by a central handler.

🔴 **Trap 2:** Returning `200` for errors (or `500` for bad input).
✅ Correct status codes; `4xx` for client faults, `5xx` for server faults.

🔴 **Trap 3:** Clients branching on message *text*.
✅ Provide a stable machine-readable `error.code`.

🔴 **Trap 4:** Leaking stack traces / internal details to clients.
✅ Log fully server-side; return a generic message (debug only in dev).

🔴 **Trap 5:** Unhandled async errors crashing the process.
✅ `asyncHandler` + a last-registered error middleware.

---

## 🧪 Test Cases (8 Cases)

| # | Action | Input | Expected |
|---|--------|-------|----------|
| 1 | Success | valid create | `201 {success:true,data}` |
| 2 | Validation | missing title | `400 VALIDATION_ERROR + details` |
| 3 | Not found | bad id | `404 NOT_FOUND` |
| 4 | Conflict | duplicate | `409 ALREADY_EXISTS` |
| 5 | Unauthenticated | no token | `401 UNAUTHENTICATED` |
| 6 | Forbidden | not owner | `403 FORBIDDEN` |
| 7 | Server bug | thrown error | `500 INTERNAL_ERROR`, no stack leak, server alive |
| 8 | Field details | multiple bad fields | details array lists each |

---

## 🎤 Famous Interview Questions

**Q1 (Conceptual): What makes a good API error contract?**
🏢 *Asked at: Postman*
✅ Answer: Consistency and machine-readability. Every response — success or error — follows one predictable envelope, errors carry a correct HTTP status plus a stable application-level `code` and a human-readable message, and validation errors pinpoint the offending fields. The status code serves transport-layer tooling (caches, retries, monitoring) while the `code` drives client logic. This lets integrators write reliable handling once instead of special-casing each endpoint's quirks.
💡 Bonus insight: Separating "status for tooling" from "code for app logic" is the key insight — a `429` tells a proxy to back off, while `RATE_LIMITED` tells the app to show a countdown, and both being present serves both audiences.

**Q2 (Design Decision): Why a stable error code instead of just a message?**
🏢 *Asked at: Stripe*
✅ Answer: Messages change — they get reworded, localized, or A/B tested — so any client branching on message text breaks silently when you tweak copy. A stable, documented `code` like `INSUFFICIENT_FUNDS` is a contract the client can switch on safely and indefinitely. The message stays free to be human-friendly and to evolve, while the code remains the reliable programmatic signal.
💡 Bonus insight: Codes also enable proper internationalization — the server sends a stable code and the client renders a localized message, which is impossible if the server's English string is the integration point.

**Q3 (Trade-off): How much error detail should you expose to clients?**
🏢 *Asked at: Razorpay*
✅ Answer: Enough to act on, never enough to leak internals. For client faults (4xx) I give precise, actionable detail — which field failed and why — because the client can fix it. For server faults (5xx) I return a generic message and an error id for support, while logging the full stack trace server-side. Exposing stack traces, SQL, or internal identifiers to clients is both unhelpful and a security risk, so debug detail is gated to development only.
💡 Bonus insight: Including a correlation/error id in 500 responses bridges the gap — the client gets something to quote to support, and you can find the full server-side log without ever leaking internals.

**Q4 (Extension): How do you keep the contract consistent as the API grows?**
🏢 *Asked at: Atlassian*
✅ Answer: Centralize it. A single error-handling middleware is the only place errors become responses, typed `AppError`s carry status+code+message, and a shared `apiFetch`/response helper enforces the shape on the way out. Common library errors (like a unique-constraint violation) are mapped to contract errors in that one place. Because every route throws typed errors and never formats responses ad hoc, consistency is structural rather than a convention people must remember.
💡 Bonus insight: Mapping infrastructure errors (DB codes, validation library output) to your contract in the central handler means individual route code stays clean and the contract can't drift endpoint by endpoint.

**Q5 (Security/Edge case): What error-handling mistakes create security or reliability risks?**
🏢 *Asked at: Stripe*
✅ Answer: Leaking stack traces or SQL reveals internals attackers can exploit, so 5xx responses must be generic with full detail logged server-side only. Unhandled async errors can crash the Node process — a denial-of-service from one bad request — so every async handler must funnel errors to the central handler. Inconsistent or overly detailed auth errors can leak information (e.g. distinguishing "user not found" from "wrong password"). And returning `200` for failures breaks client retry/monitoring logic.
💡 Bonus insight: The crash-on-unhandled-rejection case is the reliability landmine — without `asyncHandler` wrapping, a single thrown error in a promise takes down the whole server, turning a minor bug into an outage.

---

## 🔗 Navigation
⬅️ Previous: [02 — API Versioning](./02-api-versioning.md)
➡️ Next: [04 — Idempotency in APIs](./04-idempotency-in-apis.md)
🏠 [Module Home](./README.md)
