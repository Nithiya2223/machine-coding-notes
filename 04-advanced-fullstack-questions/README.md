# Module 04 — Advanced Full Stack Questions

> These problems go beyond a single feature into *systems* thinking: concurrency, background processing, isolation, time-series analytics, and caching. They appear at companies that operate at scale — Google, Meta, Amazon, Uber — and at SaaS companies where these patterns are daily bread.

The honest framing for several of these (collaborative editing, caching at scale) is that the *full* production system is enormous. The interview skill is to build a correct, scoped version and *articulate* the production path — that's what these files teach.

---

## 📚 Problems in this module

| # | Problem | Companies | Headline concept |
|---|---------|-----------|------------------|
| 01 | [Real-Time Collaborative Editor](./01-realtime-collaborative-editor.md) | Google, Notion, Atlassian, Figma | **Operational Transformation** (+ CRDT trade-off) |
| 02 | [Job Queue System](./02-job-queue-system.md) | Uber, Swiggy, Amazon, Atlassian | Async processing, `SKIP LOCKED`, retries/backoff |
| 03 | [Multi-Tenant SaaS App](./03-multi-tenant-saas-app.md) | Freshworks, Zoho, Chargebee, Atlassian | **Tenant isolation** (row-level, RLS) |
| 04 | [Analytics Dashboard](./04-analytics-dashboard.md) | Meta, Google, BrowserStack, Razorpay | Time-series events, `COUNT(DISTINCT)`, funnels |
| 05 | [Cache Layer with Redis](./05-cache-layer-with-redis.md) | Amazon, Google, Razorpay, Swiggy | **Cache-aside + invalidation** |

---

## 🧠 Cross-cutting themes

- **Concurrency is the enemy of naive code** — OT transforms, `SKIP LOCKED` claims, single-flight cache locks.
- **Decouple slow/unreliable work** from the request path (queues, async workers).
- **Isolation must be structural**, not remembered per-query (tenant scoping, RLS).
- **Push aggregation into the database** (analytics) and **memory in front of it** (caching) — both about not doing expensive work in the wrong place.
- **Know when to scope down honestly** — say "simplified now, here's the production path" for research-grade problems.

---

## 🔗 Navigation
🏠 [Course Home](../README.md)
⬅️ Previous module: [03 — Company-Specific Questions](../03-company-specific-questions/README.md)
➡️ Next module: [05 — API Design Challenges](../05-api-design-challenges/README.md)
