# Module 03 — Company-Specific Questions

> These are the deepest problems in the course — the ones that distinguish a specific company's interview. Each centers on a concept that company *lives and dies by*: idempotency at Razorpay/Stripe, settlement algorithms at fintechs, state machines at Swiggy, ordering at Atlassian, secrets at Postman, flexible schemas at Freshworks, retries at Twilio, rollouts at LaunchDarkly.

If you know which company you're interviewing with, study the matching problem here in extreme depth. The core concept is usually the entire point of the round.

---

## 📚 Problems in this module

| # | Problem | Companies | The one concept that defines it |
|---|---------|-----------|----------------------------------|
| 01 | [Payment Checkout Flow](./01-payment-checkout-flow.md) | Razorpay, Stripe, PhonePe, Juspay, CRED | **Idempotency** (no double-charge on retry) |
| 02 | [Splitwise Expense Manager](./02-splitwise-expense-manager.md) | Swiggy, CRED, Zepto, Groww, Upstox | **Balance calc + settlement optimizer** |
| 03 | [Food Ordering System](./03-food-ordering-system.md) | Swiggy, Zomato, Zepto, DoorDash | **Order state machine + atomic cart→order** |
| 04 | [Kanban Board](./04-kanban-board.md) | Atlassian, Notion, Linear, Trello, Asana | **Fractional indexing** for card order |
| 05 | [API Key Management](./05-api-key-management-system.md) | Postman, Stripe, Razorpay, BrowserStack, Twilio | **CSPRNG generation + hash storage** |
| 06 | [CRM Contact Manager](./06-crm-contact-manager.md) | Freshworks, Zoho, Chargebee, HubSpot, Salesforce | **Flexible (JSONB) schema** for custom fields |
| 07 | [Webhook Delivery System](./07-webhook-delivery-system.md) | Razorpay, Stripe, Postman, Twilio, GitHub | **Exponential backoff + HMAC signing** |
| 08 | [Feature Flag System](./08-feature-flag-system.md) | Atlassian, Meta, Google, Freshworks, LaunchDarkly | **Deterministic percentage rollout** |

---

## 🧠 Cross-cutting themes

- **Correctness under retries/concurrency** (idempotency, transactions, `FOR UPDATE`) — the fintech obsession.
- **State machines** over boolean soup — explicit, validated transitions.
- **Cryptography done right** — CSPRNG for secrets, hash-don't-store, HMAC for authenticity.
- **Async + resilience** — queues, backoff, dead-letters, reconciliation.
- **Deterministic algorithms** — fractional indexing, percentage bucketing — where "stable" matters as much as "correct."

---

## 🔗 Navigation
🏠 [Course Home](../README.md)
⬅️ Previous module: [02 — Product Feature Questions](../02-product-feature-questions/README.md)
➡️ Next module: [04 — Advanced Full Stack Questions](../04-advanced-fullstack-questions/README.md)
