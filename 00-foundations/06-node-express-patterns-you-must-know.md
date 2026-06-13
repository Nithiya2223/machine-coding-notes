# 06 — Node/Express Patterns You Must Know

## 🎬 The Story

A candidate at Zepto built their entire backend in one 400-line `index.js`. Every route had inline SQL, no `try/catch`, and no validation. Halfway through the demo the interviewer sent a request with a missing field. An exception was thrown inside an `async` handler, nobody caught it, and the **entire Node process crashed**. The terminal showed `UnhandledPromiseRejection`, the React app started throwing network errors, and the remaining 20 minutes were spent restarting the server.

The fix isn't more code — it's *structure*. This file gives you the production-quality Express skeleton you should be able to type from muscle memory, so your server never dies mid-demo.

---

## 🗂️ Route Organization (a folder you can reproduce blindfolded)

Don't put everything in one file. Use a thin, predictable layout:

```text
server/
├── index.js                 # app setup, middleware, mount routers, start server
├── db.js                    # the PostgreSQL connection pool (shared)
├── routes/
│   └── todos.js             # route definitions for /api/todos
├── controllers/
│   └── todoController.js     # request/response handling for todos
├── models/
│   └── todoModel.js          # the actual SQL queries
├── middleware/
│   ├── auth.js               # JWT verification
│   ├── validate.js           # input validation
│   └── errorHandler.js       # the central safety net
└── .env                      # secrets & config (never committed)
```

The flow of a request: **router → middleware (auth/validate) → controller → model → database**, and back. Each layer has one job.

---

## 🔌 The Connection Pool (do this once, share everywhere)

**Problem it solves:** opening a new database connection per request is slow and exhausts the database. A **pool** [a reusable set of open connections] hands out and recycles connections.

```javascript
// File: server/db.js
const { Pool } = require("pg");                     // node-postgres driver

// One pool for the whole app. It manages a set of reusable connections.
const pool = new Pool({
  host: process.env.DB_HOST,                        // all config from env, never hardcoded
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  max: 10,                                          // at most 10 concurrent connections
  idleTimeoutMillis: 30000,                         // close idle connections after 30s
});

// A thin helper so callers don't touch the pool directly.
// IMPORTANT: parameters are passed separately ($1, $2) — this prevents SQL injection.
function query(text, params) {
  return pool.query(text, params);
}

module.exports = { query, pool };
```

---

## 🧱 The App Setup (`index.js`)

```javascript
// File: server/index.js
require("dotenv").config();                         // load .env into process.env first
const express = require("express");
const cors = require("cors");
const todosRouter = require("./routes/todos");
const { errorHandler } = require("./middleware/errorHandler");

const app = express();

// --- Global middleware (runs for every request, in order) ---
app.use(cors());                                    // allow the React dev server to call us
app.use(express.json());                            // parse JSON request bodies into req.body

// --- Health check (handy to prove the server is up) ---
app.get("/health", (req, res) => res.json({ success: true, message: "ok" }));

// --- Feature routers, mounted under a versioned prefix ---
app.use("/api/v1/todos", todosRouter);

// --- 404 for anything unmatched ---
app.use((req, res) => {
  res.status(404).json({ success: false, error: "Not found" });
});

// --- The error handler MUST be last (it catches everything above) ---
app.use(errorHandler);

const PORT = process.env.PORT || 4000;
app.listen(PORT, () => console.log(`API listening on http://localhost:${PORT}`));
```

---

## ⛓️ The Middleware Chain

**Middleware** is a function that runs *between* the request arriving and your handler responding. It receives `(req, res, next)` and either responds or calls `next()` to pass control along. Think of it as a series of checkpoints.

```text
request ──▶ cors ──▶ json parser ──▶ auth ──▶ validate ──▶ controller ──▶ response
                                       │           │
                                  (401 if bad) (400 if bad)
```

Each checkpoint can short-circuit the chain (e.g., auth rejects with `401` and never calls the controller).

---

## 🛡️ Error-Handling Middleware (the safety net that keeps the server alive)

This is the single most important pattern in this file. Express recognizes a middleware with **four** arguments `(err, req, res, next)` as the error handler. Anything you pass to `next(err)` — or any error thrown in an async handler you forward — lands here, so one bad request returns a clean `500` instead of crashing the process.

```javascript
// File: server/middleware/errorHandler.js

// Central error handler. Registered LAST in index.js.
function errorHandler(err, req, res, next) {
  // Log the full error server-side for debugging...
  console.error("[ERROR]", err);

  // ...but never leak internals to the client.
  const status = err.statusCode || 500;             // custom errors can set their own status
  res.status(status).json({
    success: false,
    error: err.publicMessage || "Internal server error",
    // Only include details in development, never in production.
    details: process.env.NODE_ENV === "development" ? err.message : undefined,
  });
}

module.exports = { errorHandler };
```

To make async errors actually *reach* this handler, wrap handlers so a rejected promise is forwarded with `next(err)`:

```javascript
// File: server/middleware/asyncHandler.js
// Wraps an async route handler so any thrown/rejected error goes to errorHandler
// instead of becoming an UnhandledPromiseRejection that crashes Node.
const asyncHandler = (fn) => (req, res, next) =>
  Promise.resolve(fn(req, res, next)).catch(next);  // .catch(next) forwards to errorHandler

module.exports = { asyncHandler };
```

> 🔴 This is the exact bug from the story. With `asyncHandler` + a central `errorHandler`, a thrown error becomes a tidy JSON `500` and the server stays up.

---

## 🧾 Validation Middleware

Validate input *before* it reaches your logic. Here's a tiny dependency-free validator (in real life you'd use `express-validator` or `joi`, shown later in the course):

```javascript
// File: server/middleware/validate.js
// Returns a middleware that checks req.body has the required non-empty fields.
function requireFields(fields) {
  return (req, res, next) => {
    const missing = fields.filter((f) => {
      const v = req.body[f];
      return v === undefined || v === null || v === "";
    });
    if (missing.length > 0) {
      // Stop the chain with a clean 400 — never let bad data reach the DB.
      return res.status(400).json({
        success: false,
        error: "Validation failed",
        details: `Missing required field(s): ${missing.join(", ")}`,
      });
    }
    next();                                          // all good → continue the chain
  };
}

module.exports = { requireFields };
```

---

## 🧩 Putting a Feature Together (router → controller → model)

The clean separation in action. Notice each file does exactly one job.

```javascript
// File: server/models/todoModel.js
const { query } = require("../db");

// Pure data access. Parameterized queries ($1, $2) — never string concatenation.
const TodoModel = {
  async listByUser(userId) {
    const { rows } = await query(
      "SELECT id, title, status FROM todos WHERE user_id = $1 ORDER BY id DESC",
      [userId]
    );
    return rows;
  },

  async create(userId, title) {
    const { rows } = await query(
      "INSERT INTO todos (user_id, title) VALUES ($1, $2) RETURNING id, title, status",
      [userId, title]
    );
    return rows[0];
  },
};

module.exports = { TodoModel };
```

```javascript
// File: server/controllers/todoController.js
const { TodoModel } = require("../models/todoModel");

// Controllers translate HTTP <-> model. They DON'T contain SQL.
const TodoController = {
  async list(req, res) {
    const todos = await TodoModel.listByUser(req.user.id); // req.user set by auth middleware
    res.status(200).json({ success: true, data: todos });
  },

  async create(req, res) {
    const todo = await TodoModel.create(req.user.id, req.body.title);
    res.status(201).json({ success: true, data: todo, message: "Todo created" });
  },
};

module.exports = { TodoController };
```

```javascript
// File: server/routes/todos.js
const express = require("express");
const router = express.Router();
const { TodoController } = require("../controllers/todoController");
const { requireAuth } = require("../middleware/auth");      // (built in file 07)
const { requireFields } = require("../middleware/validate");
const { asyncHandler } = require("../middleware/asyncHandler");

// Every route: auth → (validate) → controller, each wrapped so errors are caught.
router.get("/", requireAuth, asyncHandler(TodoController.list));
router.post("/", requireAuth, requireFields(["title"]), asyncHandler(TodoController.create));

module.exports = router;
```

> Read that `routes/todos.js` aloud: *"To list todos, you must be authenticated, then run the list controller — and if anything throws, it's caught."* That readability is the whole point of the structure.

---

## 🔄 async/await with try/catch (when you don't use the wrapper)

If you don't use `asyncHandler`, you must catch errors yourself in every handler:

```javascript
router.get("/", requireAuth, async (req, res, next) => {
  try {
    const todos = await TodoModel.listByUser(req.user.id);
    res.status(200).json({ success: true, data: todos });
  } catch (err) {
    next(err);                                       // forward to the central error handler
  }
});
```

> Pick one approach and be consistent. `asyncHandler` is less typing and harder to forget — prefer it.

---

## 📦 `package.json` for the server

```json
{
  "name": "fullstack-server",
  "version": "1.0.0",
  "main": "index.js",
  "scripts": {
    "start": "node index.js",
    "dev": "nodemon index.js"
  },
  "dependencies": {
    "bcrypt": "^5.1.1",
    "cors": "^2.8.5",
    "dotenv": "^16.4.5",
    "express": "^4.19.2",
    "jsonwebtoken": "^9.0.2",
    "pg": "^8.12.0"
  },
  "devDependencies": {
    "nodemon": "^3.1.4"
  }
}
```

```text
# File: server/.env.example
PORT=4000
NODE_ENV=development
DB_HOST=localhost
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=fullstack_course
JWT_SECRET=replace_with_a_long_random_string
```

---

## ✅ Key Takeaways

1. **Structure beats one big file:** router → controller → model → db, plus middleware.
2. **One connection pool**, shared, with parameterized queries everywhere.
3. **A central error handler + `asyncHandler`** keeps the server alive when a request goes wrong — the #1 cause of mid-demo crashes.
4. **Validate before the DB**; return clean `400`s, not `500`s.
5. **All config via `process.env`**, with a committed `.env.example` and an ignored `.env`.

---

## 🔗 Navigation
⬅️ Previous: [05 — React Patterns You Must Know](./05-react-patterns-you-must-know.md)
➡️ Next: [07 — Auth, JWT & Sessions Simplified](./07-auth-jwt-sessions-simplified.md)
🏠 [Module Home](./README.md)
