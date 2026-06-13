# 02 — API Versioning

🏢 **Asked at:** Postman, Stripe, Razorpay, Atlassian

> APIs change, but the clients calling them don't update in lockstep. Versioning lets you evolve an API without breaking everyone who depends on the old shape. This challenge: the versioning strategies, how to choose, and how to run two versions side by side.

---

## 🎬 The Story

Your `/users` endpoint returns `{ name: "Asha Rao" }`. A product change splits it into `firstName` and `lastName`. You ship it — and instantly break every mobile app, partner integration, and script still expecting `name`. You can't force millions of clients to upgrade at once. Versioning is how you ship the new shape under `v2` while `v1` keeps serving the old shape until clients migrate. Postman and Stripe (whose entire business is a stable public API) ask this to see if you understand backward compatibility.

---

## 🔀 What Counts as a Breaking Change?

| Non-breaking (safe to add anytime) | Breaking (needs a new version) |
|------------------------------------|--------------------------------|
| Adding a new optional field to a response | Removing or renaming a field |
| Adding a new endpoint | Changing a field's type or meaning |
| Adding an optional request parameter | Making an optional param required |
| Adding a new enum value (usually) | Changing status codes / error shapes |

> **Golden rule:** clients should tolerate *additions*. So additive changes don't need a version bump; only changes that break existing expectations do.

---

## 🧭 Versioning Strategies

### 1. URL path versioning (most common, most explicit)
```
/api/v1/users
/api/v2/users
```
- ✅ Obvious, easy to route, easy to cache, trivially visible in logs.
- ❌ "Version the whole API" granularity; URLs for the same resource differ.

### 2. Header versioning
```
GET /api/users
Accept: application/vnd.myapp.v2+json
```
- ✅ Clean URLs; content negotiation is "correct" REST.
- ❌ Less visible/discoverable; harder to test in a browser; easy to forget.

### 3. Query-param versioning
```
GET /api/users?version=2
```
- ✅ Simple.
- ❌ Mixes versioning with filtering params; easy to omit.

| Strategy | Visibility | Caching | Common at |
|----------|-----------|---------|-----------|
| URL path | High | Easy | Most companies, Razorpay |
| Header | Low | Needs `Vary` | GitHub, some "RESTful" APIs |
| Query param | Medium | Awkward | Rare |

> **Recommendation for interviews:** URL path versioning (`/api/v1`). It's explicit, the interviewer sees it immediately, and it's what most companies actually use. Mention header versioning as the "purer REST" alternative.

---

## 💻 Running Two Versions Side by Side

```javascript
// File: server/index.js (mount both versions)
const v1 = require("./routes/v1");
const v2 = require("./routes/v2");
app.use("/api/v1", v1);
app.use("/api/v2", v2);
```

```javascript
// File: server/routes/v1/users.js
const express = require("express");
const router = express.Router();
const { getUserRow } = require("../../services/userService");
const { asyncHandler } = require("../../middleware/asyncHandler");

// v1 returns the legacy shape: a single `name`.
router.get("/:id", asyncHandler(async (req, res) => {
  const u = await getUserRow(req.params.id);
  if (!u) return res.status(404).json({ success: false, error: "Not found" });
  res.json({ success: true, data: { id: u.id, name: `${u.first_name} ${u.last_name}` } });
}));
module.exports = router;
```

```javascript
// File: server/routes/v2/users.js
const express = require("express");
const router = express.Router();
const { getUserRow } = require("../../services/userService");
const { asyncHandler } = require("../../middleware/asyncHandler");

// v2 returns the new shape: split first/last names.
router.get("/:id", asyncHandler(async (req, res) => {
  const u = await getUserRow(req.params.id);
  if (!u) return res.status(404).json({ success: false, error: "Not found" });
  res.json({ success: true, data: { id: u.id, firstName: u.first_name, lastName: u.last_name } });
}));
module.exports = router;
```

> **Key idea:** the *data layer* (`getUserRow`) is shared and unversioned; only the **presentation/transformation** differs per version. Don't fork your whole codebase per version — fork only the response shaping.

### Avoiding duplication with a transformer

```javascript
// File: server/transformers/userTransformer.js
// One source row, multiple version-specific views.
const userViews = {
  v1: (u) => ({ id: u.id, name: `${u.first_name} ${u.last_name}` }),
  v2: (u) => ({ id: u.id, firstName: u.first_name, lastName: u.last_name }),
};
module.exports = { userViews };

// Usage in a version-agnostic handler:
// res.json({ success: true, data: userViews[req.apiVersion](u) });
```

```javascript
// File: server/middleware/version.js
// Resolve the version from the path (or default to the latest stable).
function resolveVersion(req, res, next) {
  const m = req.baseUrl.match(/\/v(\d+)/);
  req.apiVersion = m ? `v${m[1]}` : "v1";
  res.set("X-API-Version", req.apiVersion);                // echo back which version served
  next();
}
module.exports = { resolveVersion };
```

### What You Will See
`GET /api/v1/users/5` returns `{ name: "Asha Rao" }`; `GET /api/v2/users/5` returns `{ firstName: "Asha", lastName: "Rao" }` — same underlying row, two shapes, served simultaneously. Old clients keep working on v1 indefinitely; new clients adopt v2. The `X-API-Version` response header confirms which version handled the request. Deleting v1 later is a deliberate, announced deprecation, not an accidental break.

---

## 🗓️ Deprecation Lifecycle

Versioning is only half the job; you also need a *retirement* plan:
1. **Announce** the new version and a deprecation date for the old one.
2. **Signal** deprecation in responses — e.g. a `Deprecation: true` / `Sunset: <date>` header on v1.
3. **Monitor** v1 traffic; reach out to laggard clients.
4. **Sunset** v1 after the window, returning `410 Gone` or a clear error.

> Stripe famously pins each account to the API version in effect when they integrated, upgrading them only deliberately — a model worth citing.

---

## ⚠️ Non-Obvious Traps

🔴 **Trap 1:** Version-bumping for *additive* changes (new optional field).
✅ Only break for breaking changes; additions are backward-compatible.

🔴 **Trap 2:** Forking the entire codebase per version.
✅ Share the data/service layer; version only the response transformation.

🔴 **Trap 3:** No deprecation path, so old versions live forever.
✅ Announce, signal (`Sunset` header), monitor, retire.

🔴 **Trap 4:** Header versioning without `Vary` → caches serve the wrong version.
✅ Set `Vary: Accept` (or use URL versioning for easy caching).

🔴 **Trap 5:** No default version, so unversioned calls 404 confusingly.
✅ Default to a known stable version or return a clear error.

---

## 🧪 Test Cases (8 Cases)

| # | Action | Input | Expected |
|---|--------|-------|----------|
| 1 | v1 shape | `GET /api/v1/users/5` | `{name}` |
| 2 | v2 shape | `GET /api/v2/users/5` | `{firstName,lastName}` |
| 3 | Same data | both | same underlying row |
| 4 | Version header | any | `X-API-Version` set |
| 5 | Additive field | v2 + new optional field | v1 unaffected |
| 6 | Unknown version | `/api/v9/...` | `404`/clear error |
| 7 | Deprecated v1 | after sunset | `Sunset` header / `410` |
| 8 | Default version | no version | stable default |

---

## 🎤 Famous Interview Questions

**Q1 (Conceptual): What is a breaking change and how does versioning relate?**
🏢 *Asked at: Postman*
✅ Answer: A breaking change is any change that violates an expectation existing clients rely on — removing or renaming a field, changing a type or meaning, making an optional parameter required, or altering status codes. Additive changes (new optional fields, new endpoints) are backward-compatible and don't require a version bump. Versioning exists to introduce breaking changes safely: the new shape lives under a new version while the old version keeps serving existing clients until they migrate, so you never force a synchronized upgrade across all consumers.
💡 Bonus insight: The discipline of "clients must tolerate additions" (Postel's law) is what lets you ship most improvements *without* a version bump — versions are reserved for genuine breaks, keeping the version count low.

**Q2 (Design Decision): URL path vs header versioning — which and why?**
🏢 *Asked at: Stripe*
✅ Answer: URL path versioning (`/api/v1`) is explicit, trivially routable and cacheable, and visible in logs and browsers, which makes it the pragmatic default most companies use. Header versioning (a custom `Accept` media type) keeps URLs clean and is "purer" REST content negotiation, but it's less discoverable, harder to test ad hoc, and needs `Vary` headers for correct caching. I'd choose URL path versioning for clarity and operability unless I had a strong REST-purity requirement.
💡 Bonus insight: The operational tiebreaker is caching and debugging — a versioned URL is a distinct cache key and shows up plainly in access logs, whereas header-based versions can be silently mis-cached if `Vary` is forgotten.

**Q3 (Trade-off): How do you avoid maintaining two entire codebases per version?**
🏢 *Asked at: Atlassian*
✅ Answer: Keep the business logic and data access shared and unversioned, and version only the thin transformation layer that shapes the response (and parses version-specific input). A per-version transformer maps the same source row to each version's view, so adding v2 is writing one new mapping function, not duplicating controllers, services, and queries. This keeps the divergence small and localized to presentation.
💡 Bonus insight: When input shapes differ too, you add a per-version request adapter that normalizes to the internal model — so the core stays version-agnostic and only the edges know about versions.

**Q4 (Extension): How do you retire an old version without breaking clients?**
🏢 *Asked at: Stripe*
✅ Answer: With a deprecation lifecycle: announce the new version and a sunset date, signal deprecation in responses (a `Deprecation`/`Sunset` header) so client developers notice, monitor traffic on the old version to find who's still calling it and reach out, then sunset it after the window with a clear error or `410 Gone`. Giving a generous, communicated timeline and machine-readable signals is what makes retirement non-breaking in practice.
💡 Bonus insight: Pinning each integration to the version it was built against (Stripe's model) lets you ship breaking changes without touching existing clients at all — they only move when they explicitly opt in, which dramatically reduces forced-migration pain.

**Q5 (Security/Edge case): What edge cases matter in versioning?**
🏢 *Asked at: Postman*
✅ Answer: Define behavior for unknown/unsupported versions (clear error, not a confusing 404) and for unversioned requests (default to a stable version or reject explicitly). With header versioning, set `Vary` so caches don't serve one version's response for another. Echo the served version back (e.g. `X-API-Version`) for debuggability. And ensure error/response *contracts* are themselves versioned consistently, so a v2 change to error shape doesn't leak into v1.
💡 Bonus insight: The cache-poisoning risk with header versioning is the subtle one — without `Vary: Accept`, a shared cache can hand a v2 payload to a v1 client, an invisible break that URL versioning avoids entirely.

---

## 🔗 Navigation
⬅️ Previous: [01 — Pagination Strategies](./01-pagination-strategies.md)
➡️ Next: [03 — Error Handling & Response Contracts](./03-error-handling-contracts.md)
🏠 [Module Home](./README.md)
