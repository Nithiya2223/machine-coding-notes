# 03 — REST API Design Fundamentals

## 🎬 The Story

At Postman — a company whose entire product is about APIs — a candidate was asked to build a simple bookmark manager. Thirty minutes in, the interviewer stopped them and pointed at one route: `GET /api/deleteBookmark?id=42`.

"Walk me through what happens," the interviewer said, "if a search-engine crawler hits that URL. Or if the browser pre-fetches it. Or if someone embeds it as an `<img src>` on a forum."

The candidate went pale. Every one of those would **silently delete bookmarks**, because they'd used `GET` — a method browsers and bots treat as safe to call freely — for a destructive action.

REST conventions are not pedantry. They are the shared grammar that makes your API predictable to every browser, proxy, and engineer on earth. Here is that grammar.

---

## 🌐 What REST Actually Means (plainly)

REST [Representational State Transfer] is a set of conventions for building HTTP APIs around **resources** — the "nouns" of your system (users, todos, orders) — which you act on using standard HTTP **methods** (the "verbs").

The mental model: **your URL names a thing; your HTTP method says what to do to that thing.**

---

## 🔤 Resource Naming

Resources are **plural nouns**, not verbs. The verb is already carried by the HTTP method.

```text
✅ GOOD                          ❌ BAD
GET    /todos                    GET  /getAllTodos
GET    /todos/42                 GET  /getTodoById?id=42
POST   /todos                    POST /createTodo
PUT    /todos/42                 POST /updateTodo
DELETE /todos/42                 GET  /deleteTodo?id=42
```

**Nesting** expresses relationships ("the comments belonging to post 42"):

```text
GET    /posts/42/comments        # all comments on post 42
POST   /posts/42/comments        # add a comment to post 42
DELETE /posts/42/comments/7      # delete comment 7 on post 42
```

Rules of thumb:
- Plural nouns: `/users`, `/orders`, not `/user`, `/getOrder`.
- No verbs in the path — the method is the verb.
- Lowercase, hyphenated if needed: `/api-keys`, not `/apiKeys` or `/Api_Keys`.
- Keep nesting shallow (one level is usually enough): `/posts/42/comments` is fine; `/users/1/posts/42/comments/7/likes/3` is a smell.

---

## 🔧 HTTP Methods (the verbs)

| Method | Meaning | Idempotent? [safe to repeat] | Example |
|--------|---------|------------------------------|---------|
| `GET` | **Read** a resource. Must have **no side effects**. | Yes | `GET /orders/42` |
| `POST` | **Create** a new resource (server assigns the id). | No | `POST /orders` |
| `PUT` | **Full update** — replace the entire resource. | Yes | `PUT /orders/42` |
| `PATCH` | **Partial update** — change some fields only. | Yes (usually) | `PATCH /orders/42` |
| `DELETE` | **Remove** a resource. | Yes | `DELETE /orders/42` |

> **The cardinal rule:** `GET` must never change state. Browsers prefetch it, crawlers crawl it, proxies cache it. Razorpay and Postman both probe for this — a state-changing `GET` is an instant red flag.

**PUT vs PATCH** in practice: if the client sends the *whole* object to replace it, use `PUT`. If they send `{ "status": "done" }` to flip one field, use `PATCH`.

---

## 🔢 HTTP Status Codes (and what they mean *in context*)

Returning the right status code is half of API design. The status code is how the *machine* (the React app, Postman, a mobile client) knows what happened without parsing your message.

### 2xx — Success
| Code | Meaning | When to use it |
|------|---------|----------------|
| `200 OK` | Generic success | A successful `GET`, `PUT`, or `PATCH`. |
| `201 Created` | A new resource was created | After a successful `POST`. Bonus: include a `Location` header. |
| `204 No Content` | Success, nothing to return | After a `DELETE`, when you have no body to send back. |

### 4xx — Client's fault
| Code | Meaning | When to use it |
|------|---------|----------------|
| `400 Bad Request` | Malformed/invalid input | Missing required field, wrong type, failed validation. |
| `401 Unauthorized` | Not authenticated | No token, or an invalid/expired token. ("Who are you?") |
| `403 Forbidden` | Authenticated but not allowed | Logged in, but trying to edit someone else's resource. ("I know you, but no.") |
| `404 Not Found` | Resource doesn't exist | `GET /orders/99999` where 99999 isn't real. |
| `409 Conflict` | Conflicts with current state | Registering an email that already exists; double-submitting an order. |
| `422 Unprocessable Entity` | Syntactically fine, semantically wrong | Common alternative to 400 for validation errors. |
| `429 Too Many Requests` | Rate limit hit | The caller exceeded their allowed request rate. |

### 5xx — Server's fault
| Code | Meaning | When to use it |
|------|---------|----------------|
| `500 Internal Server Error` | Something blew up | An unexpected exception. **Never** leak the stack trace to the client. |
| `503 Service Unavailable` | Temporarily down | DB is unreachable, server overloaded. |

> 💡 **The 401 vs 403 distinction trips up most candidates.** `401` = "I don't know who you are" (fix: log in). `403` = "I know exactly who you are, and you can't do this" (fix: nothing — you lack permission).

---

## 📦 Request & Response Structure

Pick **one** response shape and use it everywhere. Consistency lets your React app handle every response with the same code path.

**Success envelope:**
```json
{
  "success": true,
  "data": { "id": 42, "title": "Buy milk", "status": "todo" },
  "message": "Todo created"
}
```

**Error envelope:**
```json
{
  "success": false,
  "error": "Validation failed",
  "details": "Field 'title' is required"
}
```

For a **list**, put pagination metadata alongside the data:
```json
{
  "success": true,
  "data": [ { "id": 1 }, { "id": 2 } ],
  "pagination": { "page": 1, "limit": 20, "total": 137, "totalPages": 7 }
}
```

---

## 🔐 Authentication Headers

Authenticated requests carry a token in the `Authorization` header using the `Bearer` scheme:

```http
GET /api/todos HTTP/1.1
Host: api.example.com
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

- Never put tokens in the URL query string (`?token=...`) — URLs get logged, cached, and shared.
- The server reads this header in middleware, verifies the token, and attaches the user to the request. (Full implementation in [07 — Auth, JWT & Sessions](./07-auth-jwt-sessions-simplified.md).)

---

## 📄 Pagination

Never return 10,000 rows in one response. Two common styles:

**Offset / limit (simplest, great for interviews):**
```http
GET /todos?page=2&limit=20
```
The server runs `... LIMIT 20 OFFSET 20`. Easy to implement and to add "page 1, 2, 3" UI.

**Cursor-based (scales better, used by big feeds):**
```http
GET /feed?limit=20&after=eyJpZCI6MTAwfQ==
```
You pass the last item you saw; the server returns items after it. No "page drift" when new rows are inserted. (Covered in the Activity Feed problem in Module 02.)

> For most machine coding rounds, **offset/limit is the right call** — it's faster to build and the interviewer can see the page numbers.

---

## 🏷️ Versioning

APIs change. Versioning lets you evolve without breaking existing clients. The most common approach is a **URL prefix**:

```text
/api/v1/orders
/api/v2/orders
```

Postman and Stripe both version their public APIs. In a 60-minute round you usually won't ship `v2`, but **mentioning** that you'd prefix with `/api/v1` from the start signals maturity — it costs nothing now and saves pain later.

---

## 🧩 A Complete, Realistic Example (Razorpay-style orders)

Putting it all together for an "orders" resource, the way you'd defend it at Razorpay:

```text
POST   /api/v1/orders            → 201 Created   {success, data:{order}}
GET    /api/v1/orders            → 200 OK        {success, data:[...], pagination}
GET    /api/v1/orders/:id        → 200 OK | 404  {success, data:{order}}
PATCH  /api/v1/orders/:id        → 200 OK | 404  {success, data:{order}}  (e.g. cancel)
DELETE /api/v1/orders/:id        → 204 No Content | 404
```

Notice: plural noun, versioned, correct verbs, correct status codes, one consistent envelope. That single block of design — written *on paper before any code* — is what separates passing candidates from the rest.

---

## ✅ Key Takeaways

1. **URL = noun, method = verb.** Plural resource names, no verbs in paths.
2. **`GET` never changes state** — this is the most-probed rule.
3. **Status codes are how machines understand your API** — learn 200/201/204, 400/401/403/404/409/429, 500.
4. **One consistent response envelope** everywhere makes your frontend trivial.
5. Tokens go in `Authorization: Bearer`, never in the URL.
6. Paginate lists; version with `/api/v1`.

---

## 🔗 Navigation
⬅️ Previous: [02 — How Full Stack Rounds Are Evaluated](./02-how-fullstack-rounds-are-evaluated.md)
➡️ Next: [04 — Database Schema Design Basics](./04-database-schema-design-basics.md)
🏠 [Module Home](./README.md)
