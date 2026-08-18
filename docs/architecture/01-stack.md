# Stack decision — language, runtime & frameworks

*Architecture chapter 01. Companion to [Database Schema](../DATABASE_SCHEMA.md), which remains authoritative for everything about the data layer.*

| | |
|---|---|
| **Doc version** | 2.0.0 |
| **Date** | 2026-08-12 |
| **Status** | **Decided, unimplemented.** No application code exists in any language |
| **Owner** | Vincent Khoo (sole operator) |
| **Headline** | **Svelte** (SPA via Inertia) + **Laravel/PHP** (application spine) + **Python** (AI/ML, and probably the scraper) |

> ## ⚠️ v2.0.0 is a reversal, not a correction
>
> Version 1.x of this document selected **TypeScript** for the application spine. That ruling is withdrawn. The full v1.0.1 reasoning is preserved in git at `ec79af8`/`daf1785` and is not reproduced here; §3.4 adjudicates each of its three pillars — one survived, two did not.
>
> The reversal is recorded rather than edited away because the v1.x arguments were not all wrong, and the two that still stand are now **accepted costs** (§3.5) rather than refuted claims.

---

## 1. Scope & non-goals {#scope}

**Covers** the language, runtime and framework choices for the property agent workspace: the HTTP application, database access, scheduled jobs, the scraper, the frontend, and the boundary with the AI/ML layer.

**Non-goals.** The schema itself — that is `DATABASE_SCHEMA.md` and its chapters, and nothing here changes a single table. Hosting, CI and deployment topology are undecided and out of scope. The design of whatever replaces n8n is out of scope; §8 records only the constraints it must satisfy.

**Provenance markers** follow the database chapters' convention: `[MEASURED]` for something observed, `[E]` for evidenced in the repo, `[D]` for design intent, `[ASSUMED]` for a working assumption not yet tested.

---

## 2. The decision {#decision}

| ID | Layer | Choice | Status |
|---|---|---|---|
| **SD-1** | Application language | **PHP / Laravel** | Decided — §3 |
| **SD-2** | Runtime | PHP-FPM. Frontend ships as static assets served by Laravel — no Node at runtime | Decided |
| **SD-3** | Database access | **Eloquent + Laravel migrations** | Decided — §3.2 |
| **SD-4** | Driver & engine | **PDO SQLite against a local file.** Turso Cloud exits | Decided — §6 |
| **SD-5** | Frontend | **Laravel's official Svelte starter kit** — Inertia 3, Svelte 5, TypeScript, Tailwind, shadcn-svelte | Decided — §7 |
| **SD-6** | Server rendering | **Inertia SSR** when the public-feed trigger fires — not SvelteKit | Provisional — trigger in §7 |
| **SD-7** | Scraper | **Conditional on who writes to the database**, now leaning **Python** | Conditional — §5.2 |
| **SD-8** | AI/ML | **Python**, separate service or job | Decided |
| **SD-9** | Ingest orchestration | n8n, unchanged for now | Deferred — §8 |

**The timing fact is unchanged and still governs everything.** `[MEASURED: wc -c on all 7 files under src/pw/ @ 2026-08-06 → 32 bytes total]`. There is no application to migrate in any direction. This remains the cheapest language-change moment the project will ever have, and it does not recur.

---

## 3. Why Laravel {#why-laravel}

### 3.1 The operator is faster in it — and that is a technical argument here

One person is building this, and the MVP goal is a useful, user-friendly agent workspace. Framework familiarity converts directly into shipped features, and there is no team to amortise a learning curve against. **Recorded explicitly because it is the primary reason**, and a decision record that hides its primary reason is not a record.

This does not generalise. It is load-bearing precisely because the operator count is one.

### 3.2 The batteries map onto documented gaps

| Laravel provides | Gap it closes |
|---|---|
| **Migrations** | `01-current-state.md` P1: *"none exists — no `migrations/`, no `alembic/`, no version table. `PRAGMA user_version` = 0."* Schema changes are applied by hand today. This is a real hole, not a nicety |
| **SQLite foreign keys on by default** | **IG-7** warns that `PRAGMA foreign_keys=ON` must be set per connection or foreign keys silently do nothing. Laravel enables them by default on SQLite connections (`DB_FOREIGN_KEYS`, opt-out) `[MEASURED: Laravel 13.x docs @ 2026-08-12]`. In TypeScript this would have been unenforced discipline |
| **Scheduler, queues, Horizon** | §8's n8n replacement, with retries, backoff and repeatable jobs out of the box |
| **Eloquent** | A mature ORM over a seven-table schema whose relationships are already fully specified in `03-entities.md` |

### 3.3 What is *not* an argument

**Performance.** AP-01 through AP-16 total roughly 105 writes and a few hundred reads per day; §15 projects 6 MB at twelve months. Every language considered is idle at this volume. Any argument reaching for throughput benchmarks is answering a question this project does not ask.

### 3.4 Adjudicating the v1.x TypeScript case

Version 1.x rested on three pillars. Two collapsed on inspection; one stands and is accepted as a cost.

| v1.x pillar | Verdict |
|---|---|
| *"One source of truth for a constraint-heavy schema"* | **Stands.** PHP types do not reach Svelte. See §3.5 item 1 |
| *"It removes a runtime rather than adding one"* | **Collapsed.** It assumed a Node frontend server. A Svelte SPA is static assets with no Node at runtime, so this stack runs **PHP-FPM + Python = 2**, exactly as `SvelteKit + Python = 2` would have. The argument never distinguished these two shapes; it only ruled out *Python backend plus Node frontend server*, which nobody proposed |
| *"n8n is already Node"* | **Collapsed.** It was flagged as the weakest pillar when written, and n8n is being retired (§8). Sharing a language with a component scheduled for deletion is worth nothing |

**A fourth v1.x claim was simply wrong and is corrected here.** §4 item 5 of v1.x stated that Turso's PHP driver situation blocked Laravel. The blocker is **Turso Cloud specifically**, not SQLite — and Laravel against a local SQLite file uses core PDO with no third-party package at all. See §6.

### 3.5 Accepted costs {#accepted-costs}

Recorded as accepted, not as refuted. If any of these bites, this section is where to look first.

1. **No shared types between backend and frontend.** PHP types do not reach Svelte, so the six `TEXT CHECK` enumerations, the `acquisition` discriminator and the follow-up `bucket` values are declared in more than one place. Mitigation: generate TypeScript types from PHP (Spatie's typescript-transformer, or Scramble for an OpenAPI surface) and **treat the generated file as a build artifact with a drift check**, not as something hand-maintained. A generation step that can be skipped will eventually be skipped.

2. **PHP-FPM is multi-process; the write model is single-writer.** §16.2 names the multi-process deployment shape as one of two binding constraints, and M6 asks for a single writer. PHP-FPM runs N workers, any of which can write. At ~105 writes/day in one nightly batch this will not bite — but the daily-batch-in-one-transaction rule (§3) must be honoured from whichever worker runs it, and WAL plus `busy_timeout` must be set on every connection, not assumed.

3. **Turso Cloud exits, which imposes an ordering constraint on the MVP.** See §6 and SQ-1.

---

## 4. Rejected alternatives {#rejected}

Following §19's convention: what was considered, and why it lost.

| # | Considered | Why it lost |
|---|---|---|
| 1 | **TypeScript / Node** — selected in v1.0.0, withdrawn in v2.0.0 | The close call, and the two pillars that survive are §3.5's accepted costs. Lost on §3.1 (operator velocity) once its runtime-count and n8n arguments were found not to apply to a Svelte-SPA-plus-Laravel shape. Would be the correct answer again if a second developer joined, or if the public feed made shared types load-bearing across a larger surface |
| 2 | **Python / FastAPI** — declared in `pyproject.toml` (`fastapi>=0.115`, `uvicorn`, script `pw-api`) `[E]` | Workable, and zero switch cost in either direction today. Lost to Laravel on batteries (§3.2) and on the migration-tooling gap in particular. **Retained for AI/ML and probably the scraper** (§5) — a narrowing, not a rejection |
| 3 | **Laravel + Filament** | Filament is the strongest admin-panel tooling in any ecosystem and the MVP screens (AP-05, AP-06, AP-07, AP-10, AP-16) are the CRUD-table-and-form class it generates. **Declined by the owner:** an admin panel is not the user-friendly agent workspace the MVP targets. Note that this removed the single strongest argument *for* Laravel, and the decision was taken anyway on §3.1 |
| 4 | **SvelteKit** | Selected in v1.x as the endgame frontend. Superseded by SD-5/SD-6: with Laravel owning the server, SvelteKit's server layer would be a second backend or a proxy, and Inertia SSR reaches the same SEO outcome without one (§7) |
| 5 | **Go** | Right tool, wrong problem. Its wins — concurrency, deploy size, memory — are all unfelt at ~105 writes/day, and it costs verbose CRUD plus codegen to recover type safety |
| 6 | **C#** | The strongest of the remaining options; Minimal APIs and EF Core are first-rate. Lost on operator familiarity and on the thinnest SQLite/libSQL story in the set |
| 7 | **Java / Spring Boot** | Disproportionate. Seven tables, one writer, one human, 6 MB at twelve months |
| 8 | **PostgreSQL** (revisited under a PHP stack) | Laravel would make this easy, and that is precisely the trap. §19 item 1 rejected Postgres on its own merits — it buys nothing this workload can use and costs a server, a backup story and a pooler. **Choosing an engine to suit a framework is the wrong direction of causation.** The §16.2 triggers remain the only reason to move |

---

## 5. Python's scope {#python-scope}

### 5.1 The AI/ML layer — settled

Ollama, embeddings, and any classification or extraction work. It runs as a separate service or invoked job. It does not own domain logic and holds no database credentials (SQ-3).

### 5.2 The scraper — conditional, now leaning Python {#scraper}

**The rule is unchanged from v1.0.1 and survives the language reversal intact:**

> **The scraper's language follows whoever writes to the database.**
>
> | Shape | Scraper language |
> |---|---|
> | Scraper **writes the database directly** | Must be PHP, inside the Laravel application |
> | Scraper **POSTs extracted listings to the Laravel API**, which owns all writes | **Free** |

**Why the write path decides.** The database chapters are uncompromising about write discipline: `STRICT` tables (§16.2), IG-7's per-connection foreign keys, the one-transaction daily batch (§3), and M6's single writer. Routing the scraper through the API keeps every write in one place, which §3.5 item 2 makes *more* important under PHP-FPM, not less.

**The lean reverses from v1.0.1 — to Python.** Two reasons:

1. **A TypeScript scraper would now be a third language.** Under v1.x it was free; under SD-1 it is not. The runtime-count argument that failed for the backend (§3.4) genuinely applies here.
2. **Python is already in the stack for AI/ML**, so a Python scraper adds nothing — and it restores the operator's original instinct and existing BeautifulSoup familiarity.

**The v1.0.1 ecosystem comparison remains valid and is not repeated** — see `ec79af8` for the full Crawlee/Cheerio/Playwright versus Scrapy/BeautifulSoup table. Its conclusion under this stack: the TypeScript advantages were real but are no longer purchasable at an acceptable price, and Python's genuine strengths (Scrapy's middleware corpus, `rapidfuzz`, `curl_cffi` for TLS-fingerprint anti-bot work) now come for free.

**PHP scraping was considered and is not recommended** even though it would collapse the stack to two languages. Symfony Panther and BrowserKit exist, but the ecosystem is materially thinner than either Python's or JavaScript's, and tiers 2–4 need real browser automation.

### 5.3 Consequence for AP-14

AP-14's provenance reads *"Narrow fuzzy-dedup candidates before doing string work in Python."* **Under the leading branch it stands unchanged** — a reversion to accuracy relative to v1.0.1. If the scraper ends up inside Laravel, only the language of the post-filter moves; predicates and `idx_properties_dedup` are untouched either way. Performance is irrelevant at ~15 candidates × ~105 listings/day.

---

## 6. Engine and driver {#engine}

### 6.1 The ruling: PDO SQLite against a local file

**Turso Cloud exits.** This is the one place where SD-1 forces a change the database chapters had left optional.

### 6.2 Why — the PHP client is not a production bet

`[MEASURED: packagist.org/packages/turso/libsql @ 2026-08-12]`

| Fact | Value |
|---|---|
| Latest release | **v0.2.5, 2 April 2025** — roughly sixteen months stale |
| Requirements | **PHP 8.3+ and the FFI extension** |
| Adoption | ~8,050 installs; 27 GitHub stars |
| Maintainer | A single individual, not Turso the company |
| Stability | Verbatim: *"This SDK is currently in technical preview. Join us in Discord to report any issues."* |

The Turso quickstart page presents `composer require turso/libsql` without any of these caveats. **Read the registry, not the marketing page.** Two further community Laravel drivers exist (`tursodatabase/turso-driver-laravel`, `richan-fongdasen/turso-laravel` — the latter HTTP-based and therefore FFI-free), which confirms rather than resolves the fragmentation.

### 6.3 Why this costs almost nothing

Against a **local SQLite file**, Laravel uses core PDO. No FFI, no third-party package, no preview code. `DB_CONNECTION=sqlite` and an absolute path.

This is also where the database chapters were already heading:

- §16.2 recommends moving the embedded path off Turso Database 0.7.x to stock SQLite, because views, triggers, generated columns, `VACUUM` and `ATTACH` are all experimental there and the schema *needs* a view (`follow_up_inbox` is the follow-up feature).
- Migration step **M4** says *"move the Python path from `pyturso` to stdlib `sqlite3`."* SD-1 completes M4 by a different route: `pyturso` is deleted along with the Python application layer.
- §16.2's only argument for keeping Turso Cloud is that *"the n8n container talks to the database over the HTTP `/v2/pipeline` API, and an embedded file is not reachable that way."* That is a statement about n8n, not about the data.

**The stack therefore lands on the engine §16.2 recommended**, and does so for an unrelated reason. `STRICT` tables remain the single biggest win and should be declared in the Laravel migrations.

### 6.4 The sequencing constraint

Dropping Turso Cloud means the n8n HTTP write path must go first. Two orderings work; pick one deliberately:

| Order | Shape |
|---|---|
| **A** | Retire n8n before cutover. Laravel owns ingest from day one. Cleanest, but delays the workspace MVP behind scraper work |
| **B** | Keep n8n, but point it at a Laravel HTTP endpoint instead of the database. n8n keeps orchestrating; Laravel becomes the single writer immediately (M6, and §3.5 item 2). **Preferred** — it decouples the two migrations |

Order B is the recommendation: it satisfies M6 early, keeps the MVP unblocked, and reduces n8n's eventual retirement to deleting workflows rather than rewriting a write path.

---

## 7. Frontend {#frontend}

**SD-5: Laravel's official Svelte starter kit**, via `laravel new` `[MEASURED: laravel.com/docs/13.x/starter-kits @ 2026-08-12]`.

This is a first-party, supported scaffold rather than a hand-wired integration, which is the single largest velocity argument in §3.1 made concrete. It ships:

| Component | Note |
|---|---|
| **Inertia 3 + Svelte 5** | Single-page experience over classic server-side routing and controllers, so **no REST API is hand-built for the workspace's own screens** |
| **TypeScript + Tailwind + shadcn-svelte** | Components published into the repo with `npx shadcn-svelte@latest add <name>` — owned code, not a dependency. Answers the component-library question that made Solid unattractive in v1.x |
| **Laravel Fortify** | Login, registration, password reset, email verification, **TOTP two-factor**, and configurable login rate limiting — none of which appears anywhere in the schema docs' scope and all of which the workspace needs |
| **Wayfinder** | Type-safe routing, generated at build time. See SQ-5 — it does not close the type gap, but it closes the *route* half of it |
| **Inertia SSR** | `npm run build:ssr`; `composer dev:ssr` to run it locally. See SD-6 |

**Note the version correction:** the starter kit is on **Inertia 3**, not the v2 line referenced earlier in this session.

Two caveats worth carrying:

1. **A scraper posting listings (§5.2) still needs a conventional JSON endpoint.** Inertia removes the API for *screens*, not for *machines*. The same is true of §6.4's order-B ingest endpoint.
2. **Wayfinder generates routes at build time**, so removing a Fortify feature without also removing its frontend route references breaks the build. Mentioned because it is a non-obvious coupling when trimming features for a single-user tool — public registration in particular is likely unwanted here.

**An unplanned bearing on OQ-6.** The starter kits can be generated **with team support**, where every user belongs to one or more teams and routes are scoped by team slug. OQ-6 — *"Will a second agent ever use this database?"* — is described in `07-decisions.md` as **the most expensive item on that list**, because retrofitting `tenant_id` means rebuilding every composite index and unique constraint. This does not make the database retrofit cheap; the schema work is unchanged. But it does mean the *application* half arrives pre-built if the answer is ever yes. Worth weighing when OQ-6 is finally answered, and worth deciding **at `laravel new` time**, since generating with teams later is more disruptive than generating with them now.

**SD-6: Inertia SSR, when the public feed arrives.** The trigger is unchanged and remains a business event, not a technical one:

> AP-05's own provenance note: *"If this becomes a public web surface at 5k/day, AP-05 moves from 'nice to index' to the hottest path in the system."* At that point SEO becomes existential and server rendering earns its place.

The starter kit is SSR-compatible out of the box, so the public surface requires neither SvelteKit nor a re-architecture. **Be clear-eyed about one thing:** Inertia's SSR renderer is a Node process, so Node does appear in production at that point. The difference from SvelteKit is that it appears as a *render process alongside the application* rather than as a *second backend the application must move into*. Components carry over unchanged.

---

## 8. n8n {#n8n}

**Unchanged for now, and deliberately so.** It works, it is the only current write path `[E: §2.1 source P5]`, and replacing it competes for MVP time against work the user sees.

**Two constraints on the replacement, one of them new:**

1. It lives in Laravel — scheduler for the daily run, queues plus Horizon if retries and backoff are wanted. At one scrape run per day, the scheduler alone is sufficient.
2. **§6.4's ordering applies first.** Under the preferred order B, n8n stops writing the database *before* it stops existing.

**The detail that outranks the job runner.** §3 of `02-access-patterns.md`: the daily batch of ~105 upserts must be wrapped in **one transaction**. Unbatched, each insert is its own fsync and throughput drops by roughly two orders of magnitude. No scheduler compensates for getting this wrong, and none is needed to get it right.

**This answers OQ-2 fully.** *"Is `pw` (Python/FastAPI) or n8n the intended long-term system?"* — neither. Laravel is, `src/pw/` is deleted, and n8n is transitional. What remains open is timing (SQ-1, SQ-2).

---

## 9. Open questions {#open-questions}

1. **SQ-1 — Which of §6.4's two orderings is taken?** *In force:* order B — n8n is repointed at a Laravel endpoint before Turso Cloud is dropped. *Blast radius:* moderate and schedule-shaped rather than architectural. Order A blocks the workspace MVP behind scraper work; order B carries an HTTP endpoint that exists only for the transition. *Who answers:* Vincent, before the first Laravel migration is applied.

2. **SQ-2 — When does n8n retire completely?** *In force:* no date. Under order B this decouples from the engine change, which is the point of preferring it. *Blast radius:* now low, where under v1.x it gated the engine. It still gates whether `raw_payloads` (§23.1) is practical. *Who answers:* Vincent.

3. **SQ-3 — Does the AI/ML layer talk to the database, or only to the application?** *In force:* only to the application; Python holds no database credentials and owns no domain logic. *Blast radius:* significant if it drifts. A second writer reintroduces the multi-process problem §16.2 names as binding — **and §3.5 item 2 means this stack is already closer to that line than the v1.x stack was.** Keep the Python layer stateless and credential-free unless explicitly revisited.

4. **SQ-4 — What happens to `pyproject.toml` and `src/pw/`?** *In force:* `src/pw/api/` and `src/pw/db/` are deleted; `fastapi`, `uvicorn`, `pyturso` and `apscheduler` leave, and the `pw-api` script with them. `httpx`, `pydantic` and the `pw-scrape` script survive **if** the scraper stays Python (SQ-6). *Blast radius:* small and mechanical, but leaving it unchanged makes the repository state a false claim about the architecture. *Who answers:* mechanical; do it with the first Laravel commit.

   > ⚠️ **PARTIALLY EXECUTED 2026-08-14 — the deletion is blocked, not forgotten.** The Python layer moved to `apps/scraper/` (`pyproject.toml`, `uv.lock`, `.python-version`, `src/`, `tests/`) with no edits; nothing was deleted and no dependency was dropped. **The blocker is that `src/pw/db/schema.sql` is the only V1 DDL that exists anywhere** — the live database carries the V0 shape (§2.2 of `01-current-state.md`) and no Laravel migration declares a domain table yet. `tests/test_schema.py` builds those seven tables plus `follow_up_inbox` in memory through the `turso` driver and asserts the inbox behaviour case by case; deleting `src/pw/db/` or dropping `pyturso` destroys both the DDL and its only test. **Unblocked by M1** (`06-operations.md` §17), which ports the schema to Laravel migrations. Execute SQ-4 in full at that point, not before.

5. **SQ-5 — How are backend types kept in sync with Svelte?** *In force:* partially solved. The starter kit's **Wayfinder** covers *routes* type-safely at build time, and breaks the build when a referenced route disappears — a genuine drift check for that half. **It does not cover data shapes**, which is where §3.5 item 1's cost actually lands. *Blast radius:* grows silently on the uncovered half. The six `CHECK` enumerations and the `acquisition` discriminator are the specific values that will drift first, and a stale enum in a Svelte component produces a wrong dropdown rather than an error. **Whatever tool is chosen for model/DTO types (Spatie's typescript-transformer, or Scramble for OpenAPI), the generated file needs the same CI drift check Wayfinder gives routes for free.** *Who answers:* Vincent, before the first screen ships.

6. **SQ-6 — Which branch of SD-7 does the scraper take?** *In force:* Python, posting to the Laravel API. *Blast radius:* low by construction — behind an HTTP contract the language is an implementation detail. It becomes expensive **only** if the scraper is given direct database credentials and is later rewritten. *Who answers:* Vincent, on evidence from the first two portal adapters.

7. **SQ-7 — Does PHP-FPM's worker model ever actually collide with the single-writer rule?** *In force:* no, at ~105 writes/day in one nightly batch. *Blast radius:* the failure is not a crash but a `SQLITE_BUSY` under concurrent write attempts, and it will first appear as an intermittent, hard-to-reproduce error rather than a clean failure. **Set `busy_timeout` and WAL explicitly on every connection rather than relying on defaults**, and keep the batch in one transaction. Revisit if any write path other than the nightly batch appears. *Who answers:* deferred until a second write path is proposed.

---

## 10. Changelog {#changelog}

| Version | Date | Author | Change |
|---|---|---|---|
| **2.0.0** | 2026-08-12 | Vincent + Claude | **Reversal.** SD-1 changes from TypeScript to **PHP/Laravel**; the stack becomes Svelte + Laravel + Python. §3.4 adjudicates the three v1.x pillars — the shared-types argument survives and becomes an accepted cost (§3.5), while the runtime-count and n8n-is-Node arguments are shown not to apply to a Svelte-SPA-plus-Laravel shape. v1.x's claim that Turso's PHP driver blocked Laravel is corrected: the blocker is Turso Cloud specifically, and §6.2 records the registry evidence (`turso/libsql` v0.2.5 of April 2025, FFI-dependent, single maintainer, technical preview) that led to **SD-4 dropping Turso Cloud for local PDO SQLite** — which is the engine §16.2 recommended anyway. Frontend becomes **Laravel's official Svelte starter kit** — Inertia 3, Svelte 5, TypeScript, Tailwind, shadcn-svelte, Fortify auth and Wayfinder routing (SD-5) — with **Inertia SSR** replacing SvelteKit as the public-surface answer (SD-6); SvelteKit moves to rejected alternatives. Two side effects recorded: Wayfinder closes the *route* half of SQ-5 but not the data-shape half, and the starter kit's optional **teams** support means the application half of OQ-6 arrives pre-built if a second agent ever appears — a decision that must be taken at `laravel new` time. SD-7's conditional rule survives intact but its lean reverses to **Python**, since TypeScript would now be a third language. Adds §6.4's ordering constraint and prefers order B. Opened SQ-5 and SQ-7; SQ-1 and SQ-2 rewritten; OQ-2 now fully answered. |
| 1.0.1 | 2026-08-11 | Vincent + Claude | SD-7 reframed from a ruling into a conditional; §3.2 given an explicit scope limit; ecosystem comparison and branch-dependent consequences added; opened SQ-6. **Superseded by 2.0.0** — see `ec79af8`/`daf1785` for the full text. |
| 1.0.0 | 2026-08-11 | Vincent + Claude | Initial document. Established TypeScript as the application language with Python narrowed to AI/ML; Drizzle over libSQL/SQLite; Solid SPA now and SvelteKit at scale; six rejected alternatives; SQ-1…SQ-5. **Superseded by 2.0.0.** |
