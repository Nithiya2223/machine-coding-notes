# 01 — Pagination Strategies

🏢 **Asked at:** Every company with a list endpoint — emphasized at Google, Meta, Razorpay, Postman

> Returning a big list is a trap. This challenge is about the *right* way to page through data: offset/limit (simple), keyset/cursor (scalable), and knowing exactly when each breaks.

---

## 🎬 The Story

Your `/orders` endpoint worked great with 50 orders in the test database. In production it has 4 million, and the first request now tries to return all of them — the query takes 8 seconds, the JSON is 600MB, and the browser tab freezes. The interviewer adds: "Now show me page 200,000." With naive `OFFSET`, even that single page is slow because the database has to count past 4 million rows to find your slice. Pagination — done correctly — is the fix, and which *style* you choose matters.

---

## 🔢 The Two Strategies

### Offset / Limit (page numbers)
```http
GET /orders?page=3&limit=20   ->  ... LIMIT 20 OFFSET 40
```
- ✅ Simple; supports "jump to page N" and showing "Page 3 of 50."
- ❌ Slow at deep pages: `OFFSET 1000000` still scans and discards a million rows.
- ❌ **Page drift:** if rows are inserted/deleted while paging, items shift between pages → duplicates or skips.

### Keyset / Cursor (seek)
```http
GET /orders?limit=20&after=<opaque-cursor>
->  ... WHERE (created_at, id) < ($cursorTime, $cursorId) ORDER BY created_at DESC, id DESC LIMIT 20
```
- ✅ Constant-time regardless of depth (it *seeks* via the index, no rows discarded).
- ✅ Stable under inserts/deletes (you page relative to a row, not a numeric offset).
- ❌ No "jump to page N"; only next/previous. Cursor must encode a *unique, ordered* key.

| | Offset/Limit | Keyset/Cursor |
|---|---|---|
| Jump to arbitrary page | ✅ | ❌ |
| Deep-page performance | ❌ degrades | ✅ constant |
| Stable with live inserts | ❌ drifts | ✅ |
| Implementation effort | Low | Moderate |
| Best for | Admin tables, small/static data | Feeds, infinite scroll, large data |

> **Rule of thumb:** offset for bounded admin-style tables where users pick page numbers; keyset for feeds, infinite scroll, and anything large or rapidly changing.

---

## 💻 Complete Working Code

### Offset / limit
```javascript
// File: server/pagination/offset.js
const { query } = require("../db");

async function listOffset({ page = 1, limit = 20 }) {
  page = Math.max(parseInt(page) || 1, 1);
  limit = Math.min(Math.max(parseInt(limit) || 20, 1), 100); // clamp to avoid abuse
  const offset = (page - 1) * limit;

  // Page of rows + a COUNT for total pages.
  const [rows, count] = await Promise.all([
    query("SELECT id, title, created_at FROM items ORDER BY created_at DESC LIMIT $1 OFFSET $2", [limit, offset]),
    query("SELECT COUNT(*)::int AS total FROM items"),
  ]);
  const total = count.rows[0].total;
  return {
    data: rows.rows,
    pagination: { page, limit, total, totalPages: Math.ceil(total / limit) },
  };
}
module.exports = { listOffset };
```

### Keyset / cursor
```javascript
// File: server/pagination/keyset.js
const { query } = require("../db");

// Encode/decode an opaque cursor (base64 of the ordering key).
const encodeCursor = (row) => Buffer.from(`${row.created_at}|${row.id}`).toString("base64url");
const decodeCursor = (c) => {
  const [created_at, id] = Buffer.from(c, "base64url").toString().split("|");
  return { created_at, id: parseInt(id) };
};

async function listKeyset({ after, limit = 20 }) {
  limit = Math.min(Math.max(parseInt(limit) || 20, 1), 100);
  let rows;
  if (after) {
    const c = decodeCursor(after);
    // Tie-broken seek: order by (created_at, id) so equal timestamps don't drop/duplicate.
    rows = await query(
      `SELECT id, title, created_at FROM items
       WHERE (created_at, id) < ($1, $2)
       ORDER BY created_at DESC, id DESC LIMIT $3`,
      [c.created_at, c.id, limit + 1]                       // fetch one extra to detect "has more"
    );
  } else {
    rows = await query(
      "SELECT id, title, created_at FROM items ORDER BY created_at DESC, id DESC LIMIT $1",
      [limit + 1]
    );
  }
  const items = rows.rows;
  const hasMore = items.length > limit;
  if (hasMore) items.pop();                                 // drop the probe row
  const nextCursor = hasMore ? encodeCursor(items[items.length - 1]) : null;
  return { data: items, nextCursor };
}
module.exports = { listKeyset };
```

```javascript
// File: server/routes/items.js
const express = require("express");
const router = express.Router();
const { listOffset } = require("../pagination/offset");
const { listKeyset } = require("../pagination/keyset");
const { asyncHandler } = require("../middleware/asyncHandler");

// Offset style: /items?page=2&limit=20
router.get("/", asyncHandler(async (req, res) => {
  const result = await listOffset(req.query);
  res.status(200).json({ success: true, ...result });
}));
// Keyset style: /items/feed?after=<cursor>&limit=20
router.get("/feed", asyncHandler(async (req, res) => {
  const result = await listKeyset(req.query);
  res.status(200).json({ success: true, ...result });
}));
module.exports = router;
```

### Frontend — both styles
```jsx
// File: client/src/components/Paginated.jsx  (offset: page numbers)
import { useEffect, useState } from "react";
export function Paginated() {
  const [page, setPage] = useState(1);
  const [data, setData] = useState({ data: [], pagination: { totalPages: 1 } });
  useEffect(() => {
    fetch(`/api/v1/items?page=${page}&limit=20`).then((r) => r.json()).then(setData);
  }, [page]);
  const { totalPages } = data.pagination;
  return (
    <div>
      <ul>{data.data.map((i) => <li key={i.id}>{i.title}</li>)}</ul>
      <button disabled={page <= 1} onClick={() => setPage((p) => p - 1)}>Prev</button>
      <span> Page {page} of {totalPages} </span>
      <button disabled={page >= totalPages} onClick={() => setPage((p) => p + 1)}>Next</button>
    </div>
  );
}
```

```jsx
// File: client/src/components/InfiniteFeed.jsx  (keyset: infinite scroll)
import { useEffect, useState, useRef, useCallback } from "react";
export function InfiniteFeed() {
  const [items, setItems] = useState([]);
  const [cursor, setCursor] = useState(null);
  const [hasMore, setHasMore] = useState(true);
  const loadingRef = useRef(false);

  const loadMore = useCallback(async () => {
    if (loadingRef.current || !hasMore) return;
    loadingRef.current = true;
    const qs = new URLSearchParams({ limit: 20 });
    if (cursor) qs.set("after", cursor);
    const json = await (await fetch(`/api/v1/items/feed?${qs}`)).json();
    setItems((prev) => [...prev, ...json.data]);
    setCursor(json.nextCursor);
    setHasMore(!!json.nextCursor);
    loadingRef.current = false;
  }, [cursor, hasMore]);

  useEffect(() => { loadMore(); }, []);                     // initial load
  return (
    <div>
      <ul>{items.map((i) => <li key={i.id}>{i.title}</li>)}</ul>
      {hasMore && <button onClick={loadMore}>Load more</button>}
    </div>
  );
}
```

### What You Will See
The offset view shows numbered pages ("Page 3 of 50") and lets you jump around — perfect for an admin table. The keyset feed loads 20, then 20 more on "Load more," using an opaque cursor; insert new rows at the top mid-scroll and the keyset feed *doesn't* duplicate or skip items, whereas the offset view would shift. Request a 10,000-item limit and the server clamps it to 100.

---

## ⚠️ Non-Obvious Traps

🔴 **Trap 1:** No upper bound on `limit` → a client requests 1,000,000 rows.
✅ Clamp `limit` (e.g. max 100).

🔴 **Trap 2:** Offset pagination on a live feed → page drift (dupes/skips).
✅ Use keyset for anything frequently inserted.

🔴 **Trap 3:** Cursor on a non-unique column (e.g. `created_at` alone) → rows at the same timestamp dropped or duplicated.
✅ Tie-break with a unique column: order by `(created_at, id)`.

🔴 **Trap 4:** `COUNT(*)` on every page for huge tables (expensive).
✅ Skip exact totals at scale (use "load more"/approximate counts).

🔴 **Trap 5:** Leaking internal ids in the cursor.
✅ Encode the cursor opaquely (base64) so clients treat it as a black box.

---

## 🧪 Test Cases (8 Cases)

| # | Action | Input | Expected |
|---|--------|-------|----------|
| 1 | First page (offset) | `?page=1` | 20 rows + totalPages |
| 2 | Deep page (offset) | `?page=500` | correct slice |
| 3 | Over-limit | `?limit=99999` | clamped to 100 |
| 4 | Keyset first | `/feed` | 20 rows + nextCursor |
| 5 | Keyset next | `?after=cursor` | next 20, no overlap |
| 6 | End of data | last page | `nextCursor:null` |
| 7 | Tie timestamps | same created_at | no dropped rows |
| 8 | Live insert mid-scroll | keyset | no dupes/skips |

---

## 🎤 Famous Interview Questions

**Q1 (Conceptual): Offset vs keyset pagination — explain the difference.**
🏢 *Asked at: Google*
✅ Answer: Offset pagination uses `LIMIT/OFFSET` to return the Nth slice, which supports jumping to arbitrary pages but degrades at depth because the database scans and discards all skipped rows, and it suffers page drift when rows are inserted or deleted while paging. Keyset (cursor) pagination instead pages relative to the last item seen — "give me rows after this key" — which seeks directly via the index in constant time regardless of depth and is stable under concurrent inserts, at the cost of only supporting next/previous, not arbitrary page jumps.
💡 Bonus insight: The deep-page cost difference is dramatic — `OFFSET 1000000` is O(offset) work the DB throws away, whereas a keyset seek is O(log n) index traversal plus the page, so keyset stays fast no matter how far you scroll.

**Q2 (Design Decision): Why tie-break the cursor with a unique column?**
🏢 *Asked at: Meta*
✅ Answer: If you page purely by a non-unique column like `created_at`, rows that share the exact same timestamp straddle the page boundary ambiguously — the database can't tell which of the equal-timestamp rows you already saw, so it may drop or duplicate some. Including a unique tie-breaker like the primary key, and ordering by `(created_at, id)`, makes the cursor a strict total order, so "after (time, id)" is unambiguous and every row appears exactly once.
💡 Bonus insight: This is why production cursors encode a composite key, not a single column — timestamp collisions are common at scale (bulk inserts in the same millisecond), and without the tie-breaker they cause silent data loss in the feed.

**Q3 (Trade-off): When is the expensive COUNT(*) for total pages not worth it?**
🏢 *Asked at: Razorpay*
✅ Answer: For very large tables, `COUNT(*)` with the same filters scans a lot of rows and can dominate the request cost, yet users rarely need an exact "of 200,000 pages" number. So at scale I drop exact totals in favor of "load more"/infinite scroll (keyset, no count), or show an approximate count from table statistics. Exact counts make sense for smaller, bounded result sets where the page-picker UX genuinely needs them.
💡 Bonus insight: Many large products deliberately show "1–20 of many" or just a next button precisely because computing exact totals on huge filtered sets is more expensive than fetching the page itself.

**Q4 (Extension): How would you paginate an infinitely scrolling social feed?**
🏢 *Asked at: Meta*
✅ Answer: Keyset pagination, ordered by `(created_at, id)` descending, with an opaque base64 cursor encoding the last item's key. The client fetches a page, stores the returned `nextCursor`, and requests the next page with it on scroll. I fetch `limit + 1` rows to cheaply detect whether more exist, guard against overlapping loads on the client, and never use offsets — so new posts arriving at the top don't shift or duplicate items the user already scrolled past.
💡 Bonus insight: Fetching one extra "probe" row is a neat trick to compute `hasMore` without a separate count query — if you got more than `limit`, there's another page, and you discard the probe before returning.

**Q5 (Security/Edge case): What abuse and edge cases does pagination need to handle?**
🏢 *Asked at: Postman*
✅ Answer: Always clamp `limit` to a maximum so a client can't request a million rows in one call (a DoS and memory risk), and validate/normalize `page` and cursor inputs. Make cursors opaque so clients don't depend on or manipulate internal ids, and validate them server-side so a tampered cursor can't break the query. Handle the empty/last-page case cleanly (`nextCursor: null`), and ensure ordering is deterministic with a tie-breaker so results are stable.
💡 Bonus insight: An unbounded `limit` is the easy-to-miss vulnerability — it turns a normal list endpoint into an amplification vector where one tiny request forces a huge, expensive response.

---

## 🔗 Navigation
⬅️ Previous: [Module 05 Home](./README.md)
➡️ Next: [02 — API Versioning](./02-api-versioning.md)
🏠 [Module Home](./README.md)
