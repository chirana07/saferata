# SafeRata Web UI & Jac Backend Integration

SafeRata is an AI-powered migrant worker protection platform that verifies overseas job offers against the official SLBFE (Sri Lanka Bureau of Foreign Employment) licensed agency register and community scam graph using a 10-agent multi-agent team.

---

## Architecture Overview

- **Backend**: Built with **Jac 0.34.24** (`agents.jac`, `slbfe.jac`, `rules.jac`, `jobboard.jac`, `models.jac`). Serves public walkers over HTTP at `http://localhost:8000`.
- **Frontend**: Built with **TanStack Start**, **React 19**, **Vite / Nitro**, and **Tailwind CSS v4** in `web-ui/`. Communicates with the Jac backend via the typed API client in `src/lib/api.ts`.

---

## Quick Start & Startup Commands

### 1. Start the Jac Backend (Root directory)

Requirements: Jac 0.34.24 (`~/.local/bin/jac034`).

```bash
# In the repository root
export LC_ALL=en_US.UTF-8

# (Optional) Export API keys if testing LLM fallback modes
export GEMINI_API_KEY="your-gemini-key"
export OLLAMA_API_KEY="your-ollama-key"

# Start the Jac backend server on port 8000
jac034 start --port 8000
```

To populate the backend graph with demo seed data (licensed agency listings, community checks, impersonation reports):

```bash
jac034 run seed.jac
```

---

### 2. Start the Frontend (web-ui directory)

Requirements: Node.js (v20+ recommended) and npm.

```bash
cd web-ui

# Install dependencies (if not already installed)
npm install

# Start Vite development server
npm run dev
```

The frontend will run at `http://localhost:3000` (or `http://localhost:5173` depending on port availability).

---

## Environment Configuration

Configure the backend URL using `VITE_BACKEND_URL` in `web-ui/.env` or in your environment:

```env
# web-ui/.env
VITE_BACKEND_URL="http://localhost:8000"
```

If `VITE_BACKEND_URL` is omitted, `web-ui/src/lib/api.ts` defaults to `http://localhost:8000`.

---

## Connected Backend Endpoints

The frontend connects to the following Jac walkers:

| Endpoint               | Method | Walker         | Purpose                                                                                                                                                |
| ---------------------- | ------ | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `/walker/Investigate`  | `POST` | `Investigate`  | Submits offer text for 10-agent investigation against live SLBFE register. Supports optional `answers: string[]` for the pause-and-ask follow-up loop. |
| `/walker/ListJobs`     | `POST` | `ListJobs`     | Retrieves all verified jobs posted on the SafeRata board with real scores, badges, and warnings.                                                       |
| `/walker/PostJob`      | `POST` | `PostJob`      | Agency portal job submission with live SLBFE licence gate verification.                                                                                |
| `/walker/AddReview`    | `POST` | `AddReview`    | Submits worker reviews/fraud reports; evaluated by Review Verifier for impersonation vs agency fraud.                                                  |
| `/walker/RecentChecks` | `POST` | `RecentChecks` | Retrieves recent community offer checks and alerts from the shared graph.                                                                              |

---

## Offline Demo Mode & Resilience

- When the Jac backend is offline or unreachable, the frontend automatically falls back to **Demo Mode**.
- In Demo Mode, the UI shows a clear `Demo mode · Jac backend offline` pill.
- When the live backend responds, the UI displays `● Live Jac backend connected` and presents exact quotes, hard/soft scoring points, and the Courtroom debate (Prosecutor, Defender, and Judge).
- The pause-and-ask loop allows workers to answer missing information questions and re-investigate dynamically.

---

## Testing & Quality Assurance

In `web-ui`:

```bash
# Run Vitest test suite (including API client mocks and network failure tests)
npm run test

# Type-check TypeScript code
npx tsc --noEmit

# Run ESLint check
npm run lint

# Production build
npm run build
```
