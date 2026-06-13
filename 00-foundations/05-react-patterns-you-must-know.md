# 05 — React Patterns You Must Know

## 🎬 The Story

At CRED — where UI quality genuinely affects the score — a candidate built a transaction list. It worked, but the interviewer noticed: every keystroke in the search box fired a network request (so typing "coffee" hit the server six times), the loading state was a frozen blank screen, and the same `fetch` logic was copy-pasted into four components. None of it was *broken*. All of it was *junior*.

The patterns below are the exact ones that flip that perception. They're not the whole React universe — just the handful that show up, over and over, in machine coding rounds.

---

## 1. Container / Presentational Pattern

**Problem it solves:** mixing "how data is fetched/managed" with "how it looks" produces giant components that are hard to read, reason about, and reuse.

**The split:**
- **Container** = owns state, fetches data, handles events. Knows *what*.
- **Presentational** = receives props, renders UI. Knows *how it looks*. No data fetching.

```jsx
// File: client/src/components/TodoListContainer.jsx
import { useEffect, useState } from "react";
import { TodoList } from "./TodoList";              // the dumb, presentational piece
import { getTodos } from "../api/todos";            // isolated API call

// CONTAINER: owns all the state + data logic.
export function TodoListContainer() {
  const [todos, setTodos] = useState([]);           // the data
  const [loading, setLoading] = useState(true);     // loading state (never skip this)
  const [error, setError] = useState(null);         // error state (never skip this)

  useEffect(() => {
    // Fetch once on mount.
    getTodos()
      .then((data) => setTodos(data))               // success → store data
      .catch((err) => setError(err.message))        // failure → store error
      .finally(() => setLoading(false));            // either way → stop loading
  }, []);

  // The container decides WHICH UI state to show; the child just renders.
  if (loading) return <p>Loading todos…</p>;        // loading state
  if (error) return <p role="alert">Error: {error}</p>; // error state
  if (todos.length === 0) return <p>No todos yet.</p>;  // empty state

  return <TodoList todos={todos} />;                // hand clean data to the dumb component
}
```

```jsx
// File: client/src/components/TodoList.jsx
// PRESENTATIONAL: pure UI. Given todos, render them. No fetching, no business logic.
export function TodoList({ todos }) {
  return (
    <ul>
      {todos.map((t) => (
        <li key={t.id}>{t.title} — {t.status}</li>  // key is required for list reconciliation
      ))}
    </ul>
  );
}
```

> 💡 Even when you don't fully split, *thinking* in container/presentational keeps you adding the three states (loading/error/empty) that interviewers grade on.

---

## 2. Custom Hooks for API Calls (`useFetch`, `useDebounce`)

**Problem it solves:** the same `loading / error / data` ceremony copy-pasted into every component. Extract it once.

### `useFetch` — reusable data fetching
```jsx
// File: client/src/hooks/useFetch.js
import { useEffect, useState } from "react";

// Generic GET hook: pass a URL, get back {data, loading, error}.
export function useFetch(url) {
  const [data, setData] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    let cancelled = false;                          // guard against setting state after unmount
    setLoading(true);

    fetch(url, {
      headers: { Authorization: `Bearer ${localStorage.getItem("token")}` },
    })
      .then((res) => {
        if (!res.ok) throw new Error(`Request failed: ${res.status}`); // turn 4xx/5xx into errors
        return res.json();
      })
      .then((json) => { if (!cancelled) setData(json.data); })  // unwrap our envelope's .data
      .catch((err) => { if (!cancelled) setError(err.message); })
      .finally(() => { if (!cancelled) setLoading(false); });

    return () => { cancelled = true; };             // cleanup: ignore late responses
  }, [url]);                                         // re-run whenever the URL changes

  return { data, loading, error };
}

// Usage:
// const { data: todos, loading, error } = useFetch("/api/todos");
```

### `useDebounce` — wait until the user stops typing
**Problem it solves:** firing a request on every keystroke (the CRED story). Debouncing [waiting for a pause before acting] coalesces rapid changes into one.

```jsx
// File: client/src/hooks/useDebounce.js
import { useEffect, useState } from "react";

// Returns `value`, but only after it has stopped changing for `delay` ms.
export function useDebounce(value, delay = 300) {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    // Start a timer; if `value` changes again before it fires, the cleanup clears it.
    const timer = setTimeout(() => setDebounced(value), delay);
    return () => clearTimeout(timer);               // cancel the pending update on each change
  }, [value, delay]);

  return debounced;
}

// Usage:
// const [query, setQuery] = useState("");
// const debouncedQuery = useDebounce(query, 300);  // only this triggers the search effect
```

> We implement debounce **from scratch** (no lodash) on purpose — interviewers love asking you to explain it line by line. The key insight: the `setTimeout` from the previous keystroke is cleared by the effect cleanup before the next one starts.

---

## 3. Context API for Auth State

**Problem it solves:** the logged-in user is needed *everywhere* (navbar, protected pages, API calls). Passing it down through props ("prop drilling") is painful. Context broadcasts it to the whole tree.

```jsx
// File: client/src/context/AuthContext.jsx
import { createContext, useContext, useState } from "react";

const AuthContext = createContext(null);            // the broadcast channel

export function AuthProvider({ children }) {
  // Initialize from localStorage so a refresh keeps you logged in.
  const [token, setToken] = useState(() => localStorage.getItem("token"));
  const [user, setUser] = useState(null);

  function login(newToken, userData) {
    localStorage.setItem("token", newToken);        // persist across refreshes
    setToken(newToken);
    setUser(userData);
  }

  function logout() {
    localStorage.removeItem("token");
    setToken(null);
    setUser(null);
  }

  // Everything inside <AuthProvider> can read this value.
  return (
    <AuthContext.Provider value={{ token, user, login, logout, isAuthed: !!token }}>
      {children}
    </AuthContext.Provider>
  );
}

// Convenience hook so components just call useAuth().
export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth must be used inside <AuthProvider>");
  return ctx;
}
```

```jsx
// File: client/src/components/PrivateRoute.jsx
import { Navigate } from "react-router-dom";
import { useAuth } from "../context/AuthContext";

// Wrap protected pages. If not logged in, redirect to /login.
export function PrivateRoute({ children }) {
  const { isAuthed } = useAuth();
  return isAuthed ? children : <Navigate to="/login" replace />;
}
```

---

## 4. Optimistic UI Updates

**Problem it solves:** after an action (like marking a todo done), waiting for the server round-trip before updating the screen feels laggy.

**Optimistic update** = update the UI *immediately* assuming success, then reconcile if the server disagrees (roll back on error).

```jsx
// File: client/src/components/TodoItem.jsx
import { useState } from "react";
import { updateTodoStatus } from "../api/todos";

export function TodoItem({ todo, onChange }) {
  const [saving, setSaving] = useState(false);

  async function toggleDone() {
    const previous = todo.status;                   // remember current state for rollback
    const next = todo.status === "done" ? "todo" : "done";

    onChange({ ...todo, status: next });            // 1) OPTIMISTIC: update UI instantly
    setSaving(true);
    try {
      await updateTodoStatus(todo.id, next);        // 2) tell the server
    } catch (err) {
      onChange({ ...todo, status: previous });      // 3) ROLLBACK on failure
      alert("Could not save — reverted.");
    } finally {
      setSaving(false);
    }
  }

  return (
    <li>
      <input type="checkbox" checked={todo.status === "done"}
             onChange={toggleDone} disabled={saving} />
      {todo.title}
    </li>
  );
}
```

> Used well, this is a strong senior signal (it's how Linear, Notion, and Gmail feel instant). Always pair it with rollback — optimism without a rollback is just a bug.

---

## 5. Controlled vs Uncontrolled Forms

**Problem it solves:** how form inputs hold their value.

- **Controlled:** React state is the single source of truth. The input's value comes *from* state; every keystroke updates state. This is the default you should reach for — it makes validation and conditional UI trivial.
- **Uncontrolled:** the DOM holds the value; you read it via a `ref` only when you need it (e.g., on submit). Lighter, but harder to validate live.

```jsx
// File: client/src/components/LoginForm.jsx
import { useState } from "react";

export function LoginForm({ onSubmit }) {
  // CONTROLLED: state is the source of truth for both fields.
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState("");

  function handleSubmit(e) {
    e.preventDefault();                             // stop the browser's full-page reload
    if (!email || !password) {                      // live validation is easy with controlled state
      setError("Email and password are required.");
      return;
    }
    setError("");
    onSubmit({ email, password });
  }

  return (
    <form onSubmit={handleSubmit}>
      {error && <p role="alert">{error}</p>}        {/* error state */}
      <input
        type="email"
        value={email}                               // value comes FROM state (controlled)
        onChange={(e) => setEmail(e.target.value)}  // every keystroke updates state
        placeholder="you@example.com"
      />
      <input
        type="password"
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        placeholder="Password"
      />
      <button type="submit">Log in</button>
    </form>
  );
}
```

```jsx
// Uncontrolled equivalent (read the value only on submit via a ref):
// const emailRef = useRef();
// <input ref={emailRef} type="email" />
// onSubmit: const email = emailRef.current.value;
```

> **Default to controlled** in interviews. It gives you live validation, disabled-submit-until-valid, and conditional rendering for free — all of which score on the edge-case dimension.

---

## ✅ Key Takeaways

1. **Container/Presentational:** keep data logic and UI separate; it forces the loading/error/empty states.
2. **Custom hooks** (`useFetch`, `useDebounce`) kill copy-pasted fetch ceremony and per-keystroke requests.
3. **Context** is the clean home for auth state; pair it with a `PrivateRoute`.
4. **Optimistic updates** make the UI feel instant — always with a rollback.
5. **Controlled forms** are the default; they make validation and edge cases easy.

---

## 🔗 Navigation
⬅️ Previous: [04 — Database Schema Design Basics](./04-database-schema-design-basics.md)
➡️ Next: [06 — Node/Express Patterns You Must Know](./06-node-express-patterns-you-must-know.md)
🏠 [Module Home](./README.md)
