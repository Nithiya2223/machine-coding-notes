# 01 — What Is a Full Stack Machine Coding Round?

## 🎬 The Story

It's a Tuesday afternoon. Priya, a backend engineer with four years at a mid-size startup, joins a video call with Razorpay. She expects the usual: maybe some DSA, maybe "design a URL shortener" on a whiteboard. Instead, the interviewer says:

> *"Here's a shared folder. Build me an API where a merchant can create a payment order, and a customer can pay it. If the customer's network drops and they retry, they must not be charged twice. You've got 60 minutes. At the end, I'll hit your endpoints with Postman myself."*

Priya freezes for a second. There's no class diagram to draw. No "tell me about a time." She has to **open an empty folder and produce running software** that survives the interviewer poking at it live.

That is the full stack machine coding round. It is not a quiz about engineering — **it is engineering, compressed into 60–90 minutes, watched in real time.**

---

## 🆚 How It Differs From Other Rounds

It is easy to walk in with the wrong mental model. Here is exactly how this round is *not* like the rounds you may have practiced for.

### vs. A Pure Frontend Round
A frontend round says *"build a star-rating component"* or *"build a paginated table with this mock JSON."* The data is given to you. You live entirely in the browser. Nobody asks where the data is stored or whether your endpoint returns the right HTTP status.

> **The full stack round gives you no mock JSON.** *You* design the data, *you* build the endpoint that serves it, *then* you build the UI on top. If your API is broken, your beautiful UI has nothing to render.

### vs. A Backend / LLD (Low-Level Design) Round
An LLD round says *"design the classes for a parking lot"* or *"model a deck of cards in Java."* You produce class diagrams and maybe some in-memory logic. There is usually **no real database, no HTTP, and no UI** — and crucially, nobody runs your code end-to-end.

> **The full stack round demands a running API backed by a real database**, plus a UI that calls it. Clean classes alone score nothing if clicking the button does not work.

### vs. A System Design Round
A system design round says *"design Instagram for 500 million users."* You draw boxes — load balancers, caches, queues, sharded databases — and talk about trade-offs. **You write zero lines of running code.** It is a conversation about scale.

> **The full stack round is the opposite of hand-waving.** You may *mention* that you'd add Redis at scale, but right now you must produce code that actually inserts a row and renders it. Concrete beats theoretical.

### The One-Line Definition

> **A full stack machine coding round = you build ALL layers simultaneously — database, API, and UI — and the interviewer runs your app.**

There is nowhere to hide. A weak schema sinks the API. A weak API sinks the UI. You are graded on the whole chain working together.

---

## 🏢 What Actually Happens in Each Company's Format

Formats vary in time, emphasis, and how heavily the interviewer leans on each layer. Use this to calibrate where to spend your minutes. (Times reflect commonly reported formats; always confirm with your recruiter.)

| Company | Time | What the round emphasizes |
|---------|------|---------------------------|
| **Razorpay** | 60 min | API-heavy. Clean REST design, correct status codes, and correctness around money. Expect them to test edge cases with Postman. |
| **Swiggy** | 75 min | A product feature simulation (ordering, tracking). Both layers matter; they want to *use* the feature. |
| **CRED** | 60 min | UI quality genuinely counts. State management, polish, and smooth interactions are scored, not just "does it work." |
| **Zepto** | 60 min | Speed + correctness. A Node backend and a React UI delivered fast. They value finishing a working slice. |
| **Freshworks** | 90 min | A full feature *with* a DB schema. Clean code and sensible data modeling are emphasized. |
| **Zoho** | 90 min | Both layers, with a strong emphasis on **data modeling** — get the tables and relationships right. |
| **Atlassian** | 90 min | Product thinking + clean API + a working UI. They care that you built the *right* thing, well. |
| **Postman** | 60 min | API-first thinking. RESTful design quality is the whole ballgame — they are an API company. |
| **Notion** | 90 min | Collaborative features and state management. Expect shared/real-time-ish requirements. |
| **Stripe** | 90 min | Payment flows, **idempotency** [making a repeated request safe so you never double-charge], correctness over speed. |
| **Google** | 60 min | Algorithmic thinking applied in *both* layers — an efficient backend algorithm plus a clean UI. |
| **Meta** | 75 min | Product intuition + strong React proficiency. They want a polished, sensible feature. |

---

## 🧠 The Mental Shift You Must Make

Most candidates fail this round not because they lack skill, but because they bring the wrong **strategy**:

- They build a gorgeous UI first, then discover at minute 50 they have no working API behind it. **Demo: a pretty page that does nothing.**
- They over-engineer the schema with six tables when two would do, and never finish the feature.
- They forget error handling, so when the interviewer sends a bad request, the Express server *crashes* mid-demo.

The winning shift: **think like someone shipping a tiny but complete product.** A small feature that works end-to-end — register, log in, create a thing, see it on screen, handle the error case — beats a sprawling half-built masterpiece every single time.

> 💡 **Remember:** the interviewer is going to *run your app*. Optimize for "it works when clicked," not "it looks impressive in the editor."

---

## ✅ Key Takeaways

1. This round tests the **whole chain**: schema → API → UI, all running together.
2. It is fundamentally different from frontend-only, LLD, and system design rounds — different skills, different strategy.
3. Each company tilts the emphasis (API vs UI vs data modeling); calibrate your time accordingly.
4. The goal is a **small, complete, runnable feature**, not a large broken one.

---

## 🔗 Navigation
⬅️ Previous: [Module 00 Home](./README.md)
➡️ Next: [02 — How Full Stack Rounds Are Evaluated](./02-how-fullstack-rounds-are-evaluated.md)
🏠 [Module Home](./README.md)
