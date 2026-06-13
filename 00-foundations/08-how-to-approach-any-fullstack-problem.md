# 08 — How to Approach Any Full Stack Problem

## 🎬 The Story

Two engineers attempt the same Atlassian problem: a mini issue tracker. 

**Dev A** opens the editor and starts with the prettiest part — the React board. Forty minutes in, they have lovely cards with drag animations… but no backend, so nothing saves. At minute 70 they bolt on an Express server, realize the schema doesn't match their UI assumptions, and start rewriting both. Time runs out with nothing working end-to-end. Demo: a pretty page that loses everything on refresh.

**Dev B** spends the first 10 minutes writing **tables on paper**. Then 5 minutes listing **every endpoint**. Then builds the backend, tests each route with `curl`, and only *then* wires up a plain-but-working React UI. At minute 75 they demo a full create-read-update flow that survives a refresh. 

Same skill level. Different *order*. Dev B gets the offer. This file is Dev B's order, generalized into a framework you can apply to *any* full stack prompt.

---

## 🧠 The Schema-First Mindset

> **Your database schema is the foundation of your house. Build it wrong and everything above it is unstable. Get the schema right in the first 10 minutes and the rest flows naturally.**

Why start at the bottom of the stack? Because data shape *dictates* everything above it. Your API returns rows. Your React state holds those rows. If you design the UI first and the schema second, you'll discover your tables can't answer the questions your UI asks — and you'll rewrite both under time pressure. Start at the data and build upward, and each layer simply consumes the one below.

---

## 🪜 The Universal 5-Step Framework

```text
1. SCHEMA FIRST   → design tables + relationships (on paper)        ~10 min
2. API CONTRACT   → list every endpoint: method, path, req, res     ~5 min
3. BACKEND SKELETON → all route files with empty handlers           ~5 min
4. FILL BACKEND   → implement handlers one by one, test with curl   bulk of time
5. BUILD FRONTEND → wire React to the now-working API               remaining time
```

Let's walk each step using a running example: **a simple "notes" app where users save and view their own notes.**

---

### Step 1 — SCHEMA FIRST (≈10 min)

Before any code, sketch the tables and their relationships. Ask: *what are the nouns?* (users, notes) and *how do they relate?* (a user has many notes).

```sql
-- File: database/schema.sql
CREATE TABLE users (
  id            SERIAL PRIMARY KEY,
  email         VARCHAR(255) NOT NULL,
  password_hash VARCHAR(255) NOT NULL
);
CREATE UNIQUE INDEX idx_users_email ON users(email);

CREATE TABLE notes (
  id         SERIAL PRIMARY KEY,
  title      VARCHAR(255) NOT NULL,
  body       TEXT,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,  -- the relationship
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_notes_user_id ON notes(user_id);  -- we always filter notes by user
```

Quick checklist before moving on:
- [ ] Every table has a primary key.
- [ ] Every relationship is a foreign key with a constraint.
- [ ] Columns you'll filter/join on are indexed.
- [ ] No lists-in-a-cell; each fact stored once.

> 💡 Say your reasoning out loud to the interviewer here. "A note belongs to one user, so `user_id` is a foreign key; I'll index it because every query filters by user." That single sentence scores on the schema dimension.

---

### Step 2 — API CONTRACT (≈5 min)

List **every** endpoint before writing code. Method, path, what goes in, what comes out. This is your build checklist *and* your test checklist.

```text
POST   /api/v1/auth/register   body {email, password}        → 201 {user, token}
POST   /api/v1/auth/login      body {email, password}        → 200 {user, token}
GET    /api/v1/notes           (auth)                         → 200 {data: [notes]}
POST   /api/v1/notes           (auth) body {title, body}      → 201 {data: note}
GET    /api/v1/notes/:id       (auth)                         → 200 {data: note} | 404
PATCH  /api/v1/notes/:id       (auth) body {title?, body?}    → 200 {data: note} | 404
DELETE /api/v1/notes/:id       (auth)                          → 204 | 404
```

Now you know *exactly* what to build. No mid-round "wait, do I need a PATCH?" decisions.

---

### Step 3 — BACKEND SKELETON (≈5 min)

Create every route with an empty handler that returns a placeholder. This verifies your wiring (server boots, routes mount, auth attaches) *before* you write logic.

```javascript
// File: server/routes/notes.js
const express = require("express");
const router = express.Router();
const { requireAuth } = require("../middleware/auth");
const { asyncHandler } = require("../middleware/asyncHandler");

// Skeletons: each route exists and returns a stub. Fill them in Step 4.
router.get("/",        requireAuth, asyncHandler(async (req, res) => res.status(501).json({ success: false, error: "not implemented" })));
router.post("/",       requireAuth, asyncHandler(async (req, res) => res.status(501).json({ success: false, error: "not implemented" })));
router.get("/:id",     requireAuth, asyncHandler(async (req, res) => res.status(501).json({ success: false, error: "not implemented" })));
router.patch("/:id",   requireAuth, asyncHandler(async (req, res) => res.status(501).json({ success: false, error: "not implemented" })));
router.delete("/:id",  requireAuth, asyncHandler(async (req, res) => res.status(501).json({ success: false, error: "not implemented" })));

module.exports = router;
```

> `501 Not Implemented` is the honest status for a stub. Boot the server and hit `/health` — if it's green, your foundation is solid and you can fill handlers with confidence.

---

### Step 4 — FILL BACKEND (the bulk of your time)

Implement handlers **one at a time**, and **test each with `curl`** the moment it's done. Don't write all five then test — write one, prove it, move on.

```javascript
// File: server/controllers/noteController.js
const { query } = require("../db");

const NoteController = {
  async list(req, res) {
    const { rows } = await query(
      "SELECT id, title, body FROM notes WHERE user_id = $1 ORDER BY id DESC",
      [req.user.id]                                  // only this user's notes
    );
    res.status(200).json({ success: true, data: rows });
  },

  async create(req, res) {
    const { title, body } = req.body;
    const { rows } = await query(
      "INSERT INTO notes (user_id, title, body) VALUES ($1, $2, $3) RETURNING id, title, body",
      [req.user.id, title, body]
    );
    res.status(201).json({ success: true, data: rows[0] });
  },

  async getOne(req, res) {
    const { rows } = await query(
      "SELECT id, title, body FROM notes WHERE id = $1 AND user_id = $2",
      [req.params.id, req.user.id]                   // ownership baked into the query
    );
    if (rows.length === 0) {
      return res.status(404).json({ success: false, error: "Note not found" });
    }
    res.status(200).json({ success: true, data: rows[0] });
  },
};

module.exports = { NoteController };
```

Test each route immediately:
```bash
# Register, capture the token, then create a note and list notes.
TOKEN=$(curl -s -X POST localhost:4000/api/v1/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"a@b.com","password":"secret123"}' | jq -r .data.token)

curl -s -X POST localhost:4000/api/v1/notes \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"title":"First","body":"hello"}'

curl -s localhost:4000/api/v1/notes -H "Authorization: Bearer $TOKEN"
```

> This is the safety of **API-first**: even if you run out of time before the UI is perfect, you have a *demonstrably working API* to show. That alone clears the "working demo" gate for many companies.

---

### Step 5 — BUILD FRONTEND (remaining time)

Now React just *consumes* the API you proved works. Keep it plain but complete — loading, error, and empty states included.

```jsx
// File: client/src/pages/NotesPage.jsx
import { useEffect, useState } from "react";
import { getNotes, createNote } from "../api/notes";

export function NotesPage() {
  const [notes, setNotes] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [title, setTitle] = useState("");

  useEffect(() => {
    getNotes()
      .then(setNotes)
      .catch((e) => setError(e.message))
      .finally(() => setLoading(false));
  }, []);

  async function add(e) {
    e.preventDefault();
    if (!title.trim()) return;                       // simple client validation
    const note = await createNote(title);            // POST, then prepend to the list
    setNotes((prev) => [note, ...prev]);
    setTitle("");
  }

  if (loading) return <p>Loading…</p>;               // loading state
  if (error) return <p role="alert">Error: {error}</p>; // error state

  return (
    <div>
      <form onSubmit={add}>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="New note" />
        <button>Add</button>
      </form>
      {notes.length === 0 ? (
        <p>No notes yet.</p>                          // empty state
      ) : (
        <ul>{notes.map((n) => <li key={n.id}>{n.title}</li>)}</ul>
      )}
    </div>
  );
}
```

---

## 🧭 Why This Order Wins

| If you run out of time at… | API-first leaves you with… | UI-first leaves you with… |
|----------------------------|----------------------------|---------------------------|
| 50% done | A working API, partial UI — demoable via curl/Postman | A pretty UI that saves nothing |
| 75% done | Working app, minus polish | UI + scramble to glue a backend |
| 90% done | Polished, complete | Often *still* not end-to-end |

The framework front-loads the parts that are hardest to fix late (schema, API) and back-loads the part that's safe to keep simple (UI). (More on the strategic choice in [Module 08 — API-first vs UI-first](../08-tips-and-strategy/README.md).)

---

## ✅ Key Takeaways

1. **Schema first** — 10 minutes on paper saves an hour of rewrites.
2. **Write the full API contract** before coding; it's your build *and* test checklist.
3. **Skeleton, then fill** — prove the wiring with stubs, then implement + `curl`-test one route at a time.
4. **Frontend last**, consuming a proven API; keep it plain but include loading/error/empty states.
5. This order means **running out of time still leaves you with something that works.**

---

## 🔗 Navigation
⬅️ Previous: [07 — Auth, JWT & Sessions Simplified](./07-auth-jwt-sessions-simplified.md)
➡️ Next module: [01 — Core Full Stack Questions](../01-core-fullstack-questions/README.md)
🏠 [Module Home](./README.md)
