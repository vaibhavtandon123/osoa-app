# OSOA Desk

Event management app for One State One Artist (OSOA), Paint with Prakash (PWP) and Workshops.
Frontend hosted on **Cloudflare Pages**; backend runs on **Google Apps Script** (data in a Google Sheet in Drive: `My Apps / OSOA Desk`).

## How it fits together
- `index.html` — the whole app (served by Cloudflare Pages). Works as an installable app (PWA) on iPhone, iPad, Android and desktop.
- `functions/api.js` — Pages Function at `/api` that forwards app calls to Apps Script. The Apps Script URL is the `APPS_SCRIPT_URL` environment variable in the Cloudflare Pages project (not in this repo).
- `qr.js` — QR code generator (MIT, Kazuhiko Arase) loaded on demand for artist QR codes.
- `functions/img.js` — cached image endpoint `/img?id=…` (only serves images inside the app's Drive folder).
- `apps-script/Code.gs.txt` — the Apps Script backend (paste into the Apps Script editor).

## Roles
- **Super admin** — all events, create events, programs (desk name, colour, logo), people.
- **Event admin** — everything inside one event.
- **Project Lead** — leads a team: members, positions, volunteer approvals, team access.
- **Assistant Project Lead (APL)** — adds/removes team members and manages team tasks.
- **Coordinator** — manages team tasks. **Senior Volunteer** — title and badge.
- **Volunteer** — check-in, artist list, own tasks, announcements.
- **Artist** — registration, status, updates, schedule.
- **Guest** — public event page, no login.

## Updating
Push to `main` → Cloudflare Pages auto-deploys the frontend. No copy-paste.
Backend changes (rare) → paste `apps-script/Code.gs.txt` into the Apps Script editor → Deploy → Manage deployments → Edit → New version.
