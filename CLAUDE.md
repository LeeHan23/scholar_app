# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**ScholarSync** is a scholarly paper reading queue manager with three components sharing a Supabase backend:

1. **iOS App** (`ios-app/ScholarSync/`) — SwiftUI app, opens in Xcode
2. **Web Dashboard** (`web-dashboard/`) — Next.js 16 / React 19 / TypeScript
3. **Browser Extension** (`ios-app/ScholarSync/ScholarSync Extension/Resources/`) — Manifest V3, embedded in the Xcode project

## Web Dashboard Commands

Run from `web-dashboard/`:

```bash
npm run dev      # Start dev server (localhost:3000)
npm run build    # Production build
npm run lint     # ESLint
```

Environment variables are in `web-dashboard/.env.local` (`NEXT_PUBLIC_SUPABASE_URL`, `NEXT_PUBLIC_SUPABASE_ANON_KEY`).

## iOS App

Open `ios-app/ScholarSync/ScholarSync.xcodeproj` in Xcode. Build and run via Xcode (⌘R). There is no CLI build setup.

## Architecture

### Data Model

The core `Paper` model (defined in both `ios-app/.../Models/Paper.swift` and typed in `web-dashboard/src/components/PaperCard.tsx`) has: `title`, `authors`, `journal`, `year`, `doi`, `abstract`, `status` (`unread`/`read`), plus extended fields: `userId`, `projectId`, `tags`, `locationName`, `latitude`, `longitude`, `pageNumber`.

Papers are stored in a Supabase `papers` table with a `user_id` foreign key. A `projects` table provides one-to-many grouping of papers. Both use snake_case columns (Swift model has custom CodingKeys for mapping).

### iOS App Architecture (MVVM)

- **Entry point** `ScholarSyncApp.swift` — checks `SupabaseManager.shared.isAuthenticated` to route between `LoginView` and `ContentView`; provides `QueueViewModel` and `StoreManager` as environment objects
- **`QueueViewModel`** — `@MainActor` central state; handles scan → Crossref fetch → location auto-tag → Supabase save; manages both papers and projects CRUD
- **`CrossrefService`** — calls `api.crossref.org/works/{doi}` (polite pool User-Agent header required); also supports ISBN lookup via Open Library API as fallback
- **`SupabaseManager`** — singleton with real Supabase REST API calls; reads URL/key from Info.plist with hardcoded fallbacks; stores auth tokens in Keychain via `KeychainHelper`
- **`KeychainHelper`** — wraps Security framework for `accessToken`, `refreshToken`, `currentUserId` storage (`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`)
- **`LocationManager`** — CLLocationManager singleton with reverse geocoding; auto-tags papers with capture location
- **`TitlePageReader`** — Vision framework OCR; extracts ISBN, year, publisher, title, authors from photographed title pages
- **`ZoteroService`** — exports papers to Zotero via API; credentials stored in Keychain
- **`CitationExporter`** — generates BibTeX, RIS, CSV formats
- **`AutoRenamer`** — generates `LastName_Year_FirstFourTitleWords.pdf` filenames
- **`StoreManager`** — freemium gating (15 free captures/month); RevenueCat integration is mocked

### Data Flow: Scan Workflow

Scanner detects DOI/ISBN/arXiv → `CrossrefService` fetches metadata → `LocationManager` auto-tags location → `SupabaseManager` saves to Supabase → `QueueViewModel` updates UI. Title page workflow is similar but uses Vision OCR → user review form → optional ISBN lookup → save.

### Web Dashboard Architecture

- `src/lib/supabaseClient.ts` — singleton Supabase client
- `src/app/page.tsx` — "use client" main page; auth check redirects to `/login`; real-time `onAuthStateChange()` listener; papers CRUD with Supabase RLS
- `src/app/login/page.tsx` — uses `@supabase/auth-ui-react` with GitHub provider
- `src/components/Sidebar.tsx` — navigation sidebar (nav items are static/non-functional placeholders)
- Styling uses CSS variables in `globals.css` (dark slate/blue theme, glass-panel effects, no Tailwind)
- React Compiler is enabled in `next.config.ts` (`reactCompiler: true`)

### Browser Extension

- `content.js` — injected into academic sites (arxiv.org, nature.com, jstor.org, sciencedirect.com, doi.org, ieee.org); extracts DOI/arXiv ID/title/authors from page meta tags and URL patterns
- `popup.js` — queries active tab's content script for metadata; **save to Supabase is mocked** (setTimeout delay)
- `background.js` — minimal service worker placeholder

## Key Implementation Notes

- iOS auth is real Supabase auth with Keychain token storage. Web auth uses Supabase Auth UI with GitHub provider. Extension auth is not implemented.
- `StoreManager.purchasePro()` immediately sets `isPro = true` without a real RevenueCat call.
- The browser extension's save flow is a mock; real implementation needs Supabase auth token retrieval and an API call.
- Web dashboard search bar and sidebar navigation are UI placeholders only.
- External APIs: Crossref (DOI), Open Library (ISBN), Zotero (export), Supabase REST (`/rest/v1/`).
