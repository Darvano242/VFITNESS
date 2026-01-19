# VFITNESS Upgrade Plan (Current Code → Fast Wins → Vite Build)

This document converts the current architecture into a practical, staged improvement plan with acceptance criteria and deliverables.

## Current Build Facts (As Provided)

- **Architecture**: Static site on Netlify, no bundler.
- **Single page**: `index.html` contains the entire app.
- **Dependencies (CDN)**: React, Babel standalone, Firebase compat SDK, Tailwind, Chart.js.
- **Routing**: SPA redirect via `netlify.toml` and `_redirects`.
- **Service worker**: `sw.js` caches `/` and `/index.html`.
- **Main issue**: Babel compiling JSX in the browser → slower loads, harder debugging, larger payloads, weaker mobile performance.

---

## Track 1 — Fast Wins (Keep Current Stack)

### 1) Split the giant `index.html` into real files

**Goal**: Improve maintainability without changing deployment or tooling.

**Actions**

- Create folder structure:
  - `/assets`, `/images`, `/icons`, `/src`, `/components`, `/pages`, `/styles`, `/utils`
- Create files:
  - `app.jsx` (React code)
  - `firebase.js` (Firebase config)
  - `state.js` (client state helpers)
- Move inline CSS to: `/src/styles/app.css`
- Update `index.html` to load React via Babel:
  ```html
  <script type="text/babel" src="/src/app.jsx"></script>
  ```

**Acceptance Criteria**

- App runs exactly the same.
- `index.html` is small and clean.
- All React logic is in `/src`.

---

### 2) Fix service worker caching so updates show up

**Problem**: Only caching `/` and `/index.html` can produce stale deployments.

**Actions**

- Update `CACHE_NAME` per deployment (e.g., `vfitness-v3`, `vfitness-v4`).
- Either:
  - Cache JS/CSS/media assets used offline, **or**
  - Disable SW caching until Track 2 migration is complete (recommended if updates are inconsistent).

**Acceptance Criteria**

- New Netlify deploys appear reliably.
- No stale cache complaints after deploy.

---

### 3) Implement “Workout Player” (single-screen experience)

**Requirements**

- Exercise name
- Embedded video player (pinned/floating)
- Coach cues visible
- Sets + reps + weight inputs
- “Done” checkbox per set
- Rest timer auto-start after set completion
- “Next Exercise” button

**Acceptance Criteria**

- Client can complete a full workout without leaving the page.
- No external video searches needed mid-workout.

---

## Track 2 — Proper Netlify Build (Premium Performance)

### 4) Migrate from CDN+Babel to Vite+React

**Why**

- Build-time compile → faster, smaller, easier to debug, scalable.

**Actions**

1. Create Vite project:
   ```bash
   npm create vite@latest vfitness -- --template react
   ```
2. Move app logic to `vfitness/src/`.
3. Install Tailwind properly:
   ```bash
   npm install -D tailwindcss postcss autoprefixer
   npx tailwindcss init -p
   ```
4. Add Netlify SPA redirect (choose **one** method):
   - `public/_redirects`
     ```
     /* /index.html 200
     ```
   - OR `netlify.toml`:
     ```toml
     [build]
       command = "npm run build"
       publish = "dist"

     [[redirects]]
       from = "/*"
       to = "/index.html"
       status = 200
     ```

**Acceptance Criteria**

- No Babel in production.
- App loads faster and is easier to maintain.
- Netlify build uses `npm run build` and publishes `dist`.

---

### 5) Move Firebase config to Netlify Environment Variables

**Why**: Keep config clean per environment and avoid hardcoding values.

**Actions**

- Add environment variables in Netlify:
  - `VITE_FIREBASE_API_KEY`
  - `VITE_FIREBASE_AUTH_DOMAIN`
  - `VITE_FIREBASE_PROJECT_ID`
  - `VITE_FIREBASE_STORAGE_BUCKET`
  - `VITE_FIREBASE_MESSAGING_SENDER_ID`
  - `VITE_FIREBASE_APP_ID`
- Update `src/firebase.js`:
  ```js
  const firebaseConfig = {
    apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
    authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
    projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
    storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
    messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
    appId: import.meta.env.VITE_FIREBASE_APP_ID,
  };
  ```

**Acceptance Criteria**

- No config hardcoded in repo.
- Environment variables control behavior per deploy.

---

### 6) Add Netlify Functions for secure actions

**Use cases**

- Stripe billing
- Email triggers
- Admin actions
- Webhooks

**Implementation**

- Add server-side logic under `/netlify/functions/`.

**Acceptance Criteria**

- Secrets never touch the frontend.
- Webhooks and secure actions run server-side.

---

## Feature Requirements (for Product Clarity)

### 7) Home Screen — “Client First”

**Must show**

- Today’s workout card + Start
- Streak / weekly goal bar
- Coach message
- Quick actions:
  - log weight
  - upload photo
  - message coach

---

### 8) Progress Dashboard — Visual + Motivating

**Must show**

- Weight chart
- Photo timeline
- Strength PR tracking

---

### 9) Accountability System

**Must show**

- Streaks
- Missed workout reminder
- Weekly recap screen

---

## Delivery (Sprint Plan)

### Sprint 1 — Foundation

- Track 2 migration to Vite+React
- Tailwind install
- Routing + Netlify deploy stable

### Sprint 2 — Workout Player

- Embedded video + sets + timer + completion

### Sprint 3 — Progress + Streaks

- Charts + streak logic + weekly goal

### Sprint 4 — Nutrition + Weekly Check-in

- Check-in forms + coach review view

---

## Deliverables After Each Sprint

- Netlify deploy preview link
- Short changelog
- Mobile screen recording (30–60s) showing features working
- List of any new environment variables
