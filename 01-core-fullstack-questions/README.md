# Module 01 — Core Full Stack Questions

> These five problems are the bedrock of the machine coding round. Almost every harder question in later modules is a remix of patterns you'll learn here: users own resources, you CRUD them behind auth, you relate them, aggregate them, and paginate them.

If you can build all five from a blank folder without looking anything up, you are ready for the majority of full stack rounds at product companies.

---

## 📚 Problems in this module

| # | Problem | Companies | Core teaching |
|---|---------|-----------|---------------|
| 01 | [Todo App with API](./01-todo-app-with-api.md) | Freshworks, Zoho, BrowserStack, Chargebee | The foundational CRUD + auth pattern; per-user data isolation |
| 02 | [User Auth System](./02-user-auth-system.md) | Every company | Register/login/logout, bcrypt, JWT middleware, Context + PrivateRoute |
| 03 | [Blog Platform](./03-blog-platform.md) | Freshworks, Zoho, Atlassian, Chargebee | Relational modeling, many-to-many (tags), JOINs, pagination, search |
| 04 | [Expense Tracker](./04-expense-tracker.md) | CRED, Zepto, Razorpay, PhonePe | Aggregation (SUM/GROUP BY), filter building, money as NUMERIC |
| 05 | [URL Shortener](./05-url-shortener.md) | Google, Amazon, Postman, Freshworks | Base62 algorithm, 301 vs 302 redirects, denormalized counters |

---

## 🧩 Patterns established here (reused everywhere after)

- **Shared backend skeleton:** `db.js` pool, `asyncHandler`, central `errorHandler`, `requireFields`, `token.js`, `requireAuth`.
- **Shared frontend skeleton:** `apiFetch` client, `AuthProvider` + `useAuth`, `PrivateRoute`, the loading/error/empty state trio.
- **Consistent API envelope:** `{ success, data, message }` and `{ success, error, details }`.
- **Ownership rule:** every query scoped by `req.user.id`; `404` if missing, `403` if not yours.

Later modules assume these are in place and focus on what's new.

---

## 🔗 Navigation
🏠 [Course Home](../README.md)
⬅️ Previous module: [00 — Foundations](../00-foundations/README.md)
➡️ Next module: [02 — Product Feature Questions](../02-product-feature-questions/README.md)
