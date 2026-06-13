# Module 02 — Product Feature Questions

> Module 01 taught you CRUD-with-auth. This module is where interviews get *interesting*: real product features that introduce real-time delivery, debouncing, caching, rate limiting, file handling, and the fan-out problem. These are the features you actually see in Swiggy, LinkedIn, Slack, and Notion.

Each problem deliberately introduces one or two new "hard" concepts on top of the Module 01 foundation, so you're always building on familiar ground.

---

## 📚 Problems in this module

| # | Problem | Companies | New concepts introduced |
|---|---------|-----------|--------------------------|
| 01 | [Notification System](./01-notification-system.md) | Swiggy, Flipkart, LinkedIn, Amazon, CRED | Polling, unread-count badge, partial index, JSONB, SSE/WS twist |
| 02 | [Search Autocomplete](./02-search-autocomplete.md) | Swiggy, Zepto, Google, Flipkart, Razorpay | Debounce from scratch, LRU cache, prefix indexing, keyboard nav |
| 03 | [Rate Limiter](./03-rate-limiter.md) | Razorpay, Stripe, Postman, Google, Amazon | Token bucket, sliding window, Express middleware, 429 + Retry-After |
| 04 | [File Upload Manager](./04-file-upload-manager.md) | Atlassian, Notion, BrowserStack, Freshworks | Multipart/Multer, upload progress (XHR), validation, streaming |
| 05 | [Real-Time Chat](./05-real-time-chat.md) | Atlassian, Meta, Notion, Slack, Freshworks | WebSockets (Socket.io), REST+WS hybrid, rooms, typing indicator |
| 06 | [Activity Feed](./06-activity-feed.md) | Meta, LinkedIn, Twitter/X, Swiggy, CRED | Fan-out on read vs write, keyset pagination, infinite scroll, follow graph |

---

## 🧠 The big ideas to walk away with

- **Real-time has a spectrum:** polling (simple, laggy) → SSE (one-way push) → WebSockets (full-duplex). Pick by latency need.
- **Don't hit the backend more than necessary:** debounce input, cache hot reads (LRU/Redis), poll only cheap queries.
- **Abuse is a first-class concern:** rate limiting and upload validation are security, not just performance.
- **Pagination style matters:** offset is fine for static lists, keyset/cursor is required for live streams (feeds, chat, notifications).
- **The hybrid pattern recurs:** REST for the durable past, push for the live present.

---

## 🔗 Navigation
🏠 [Course Home](../README.md)
⬅️ Previous module: [01 — Core Full Stack Questions](../01-core-fullstack-questions/README.md)
➡️ Next module: [03 — Company-Specific Questions](../03-company-specific-questions/README.md)
