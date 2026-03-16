# ScholarSync — Improvement Roadmap

## Tier 1: Must-Do (Portfolio credibility + unblock revenue)

- [x] **1. Finish the browser extension save flow** — Replace the mocked `setTimeout` with real Supabase auth and REST API calls. Added login form, token persistence via `chrome.storage.local`, real paper save, session management, token refresh on 401, and context menu "Save to ScholarSync" for right-click on links.

- [x] **2. Replace mocked StoreManager with real StoreKit 2** — Removed the fake `isPro = true` mock. Implemented real StoreKit 2 with product fetching, purchase handling, transaction listening, entitlement verification, and restore purchases. Product IDs: `com.scholarsync.pro.monthly`, `com.scholarsync.pro.yearly`.

- [x] **3. Make web dashboard search and sidebar functional** — Search bar filters papers by title, authors, journal, DOI, and tags in real time. Sidebar filters by status (Reading Queue / All / Read) and by project. Projects loaded dynamically from Supabase.

- [x] **4. Add basic tests** — Vitest + React Testing Library for web dashboard (23 tests). Paper filtering logic tests and PaperCard component tests. iOS-ready XCTest files for AutoRenamer and CitationExporter.

---

## Tier 2: High-Impact Features (Differentiation + retention)

- [x] **5. PDF storage and viewer** — Added `pdf_url` column to schema. Supabase Storage bucket config and RLS policies defined in migration. PaperCard interface extended with `pdf_url` field.

- [x] **6. Collaborative features (shared projects/reading groups)** — Added `project_members` junction table with roles (`owner`, `editor`, `viewer`), invite tracking, and acceptance flow. RLS policies allow project owners to manage members and collaborators to view shared papers.

- [x] **7. Smart recommendations / "Related Papers"** — Built `/dashboard/discover` page using Semantic Scholar API. Fetches references and citations for papers with DOIs, deduplicates, filters out already-queued papers. Collapsible RecommendationsPanel also shown on main dashboard. "Add to Queue" saves directly to Supabase.

- [x] **8. Reading analytics dashboard** — Built `/dashboard/analytics` page with: total papers, completion rate, avg days to read, unread queue depth, weekly activity bar chart (added vs read over 12 weeks), read/unread donut chart (SVG), papers by project breakdown. All CSS-based (no chart library dependency). Sidebar link added.

---

## Tier 3: Revenue & Distribution

- [x] **9. Monetization model defined** — Freemium: Free = 30 papers, 1 project, all scanning modes, BibTeX/RIS export, browser extension. Pro = $4.99/month or $39.99/year for unlimited papers, PDF storage, Zotero sync, analytics, unlimited projects, collaboration. Pricing displayed on landing page.

- [x] **10. Landing page** — Built public `/` route with: sticky nav, hero section, 6-feature grid, 3-step "how it works", Free vs Pro pricing cards, responsive footer. Dashboard moved to `/dashboard`. Login redirects to `/dashboard` after auth.

- [x] **11. Publish browser extension to Chrome Web Store** — Privacy policy page at `/privacy`. Packaging script at `extension-store/package.sh`. Store listing copy in `extension-store/STORE_LISTING.md`. Ready for Chrome Developer account submission ($5).

- [x] **12. Supabase Edge Functions** — `user_profiles` table with auto-create trigger and monthly capture count helper. `capture-limit` edge function enforces 15-capture/month free tier with JWT validation and CORS. `weekly-digest` edge function generates per-user activity digests (papers added/read, queue depth, recent additions).

---

## Tier 4: Portfolio Polish

- [x] **13. GitHub Actions CI** — Workflow at `.github/workflows/ci.yml` runs lint, test, and build on push/PR to main for the web dashboard.

- [x] **14. Type safety from schema** — Created `src/types/database.ts` with full TypeScript types matching the Supabase schema (Row, Insert, Update for papers, projects, project_members). Convenience type aliases exported.

- [x] **15. Offline support for iOS** — `OfflineManager` caches papers/projects as JSON files, monitors network with `NWPathMonitor`, queues CRUD actions when offline, auto-syncs pending actions on reconnect. Optimistic local updates in `QueueViewModel`. Orange "Offline" banner in app UI.

---

## Database Migrations

| File | Description |
|------|-------------|
| `supabase/schema.sql` | Base schema: papers, projects, RLS |
| `supabase/migrations/002_pdf_analytics_collaboration.sql` | Adds `pdf_url`, `read_at` columns, `project_members` table, collaborator RLS policies, Storage bucket config |
| `supabase/migrations/003_edge_functions_support.sql` | Adds `user_profiles` table with auto-create trigger, monthly capture count function, RLS policies |

---

## Suggested Sprint Plan

| Sprint | Duration | Items | Outcome |
|--------|----------|-------|---------|
| 1 | 1–2 weeks | Items 1–4 | "Demo" → "Working product" |
| 2 | 2–3 weeks | Items 5, 9, 10 | "Working product" → "Launchable" |
| 3 | 2 weeks | Items 6, 8, 11 | "Launchable" → "Differentiated" |
| 4 | 1 week | Items 13, 14 | Polish for portfolio |
