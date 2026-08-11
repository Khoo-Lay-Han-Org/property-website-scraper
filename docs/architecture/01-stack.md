# Stack decision — language, runtime & frameworks

*Architecture chapter 01. Companion to [Database Schema](../../DATABASE_SCHEMA.md), which remains authoritative for everything about the data layer.*

| | |
|---|---|
| **Doc version** | 1.0.0 |
| **Date** | 2026-08-11 |
| **Status** | **Decided, unimplemented.** No application code exists yet in either language |
| **Owner** | Vincent Khoo (sole operator) |
| **Headline** | **TypeScript** for the application spine — API, database access, jobs, scraper, frontend. **Python retained for the AI/ML layer only.** |

---

## 1. Scope & non-goals {#scope}

**Covers** the language, runtime and framework choices for the property agent workspace: the HTTP API, database access, scheduled jobs, the scraper, the frontend, and the boundary with the AI/ML layer.

**Non-goals.** The schema itself — that is `DATABASE_SCHEMA.md` and its chapters, and nothing here changes a single table. Hosting, CI and deployment topology are undecided and deliberately out of scope. The design of whatever eventually replaces n8n is out of scope; §8 records only the constraint it must satisfy.

**Provenance markers** follow the database chapters' convention: `[MEASURED]` for something observed, `[E]` for evidenced in the repo, `[D]` for design intent, `[ASSUMED]` for a working assumption that has not been tested.

---

## 2. The decision {#decision}

| ID | Layer | Choice | Status |
|---|---|---|---|
| **SD-1** | Application language | **TypeScript** | Decided |
| **SD-2** | API + jobs runtime | Node (single process; the frontend server *is* the backend) | Decided |
| **SD-3** | Database access | **Drizzle ORM** over libSQL/SQLite | Decided |
| **SD-4** | Driver | `@libsql/client` for Turso Cloud; `better-sqlite3` for the embedded path | Decided — see §6 |
| **SD-5** | Frontend, now | Solid + Vite, SPA, served by the Node process | Decided |
| **SD-6** | Frontend, at scale | SvelteKit | **Provisional** — trigger in §7 |
| **SD-7** | Scraper | **Conditional on who writes to the database** — see §5.2 | **Conditional**; leaning TypeScript + Crawlee |
| **SD-8** | AI/ML | **Python**, separate service or job | Decided |
| **SD-9** | Ingest orchestration | n8n, unchanged for now | Deferred — see §8 |

**The single most important fact about this decision is its timing.** `[MEASURED: wc -c on all 7 files under src/pw/ @ 2026-08-06 → 32 bytes total]`. There is no application to migrate. Every argument below is priced on that basis, exactly as §17 of the database docs prices the schema changes — this is the cheapest language-change moment the project will ever have, and it does not recur.

---

## 3. Why TypeScript {#why-typescript}

Three arguments, all grounded in the repository rather than in preference.

### 3.1 One source of truth for a constraint-heavy schema

§4 of `02-access-patterns.md` commits to `TEXT CHECK (c IN (...))` for all six V1 enumerations, plus the `acquisition` discriminator that splits `properties` into two halves with different lifecycles (§19 item 3), plus the `follow_up_inbox` view.

In any backend language that is not the frontend's language, that shape is declared three times — once in SQL, once in the backend's model layer, once in the frontend's types — and the three drift silently, because nothing checks them against each other. With Drizzle the schema is declared once in TypeScript and emits both the DDL and the types the frontend consumes.

This matters more here than in a typical CRUD app, because the enumerations are not decorative: `acquisition`, `status`, and the follow-up `bucket` values carry the domain's core distinctions.

### 3.2 It removes a runtime rather than adding one

The frontend decision (§7) puts a Node process in the deployment regardless. Choosing TypeScript for the backend means that process **is** the backend: one runtime, one deploy, one dependency tree, one origin — no CORS configuration.

Any other backend language yields Node (frontend) + that language (API) + Python (ML) — three runtimes for a tool with one user. §16.2 of `06-operations.md` already names the multi-process deployment shape as one of the two binding constraints on this system. Adding processes works directly against a constraint the database docs identified independently.

**Scope limit, stated because v1.0.0 over-applied this argument.** It holds for the API and the request path. It does **not** hold for the scraper, which is a once-daily batch job: Python is retained for the AI/ML layer regardless (§5.1), so a Python scraper rides along in a service that already exists and adds no runtime at all. The scraper is decided on different grounds — see §5.2.

### 3.3 n8n is already Node

§2.1 of `01-current-state.md`, source P5: n8n is today the only thing that writes to the database. During the handover period described in §8, custom nodes and function steps share a language with the application. This is the weakest of the three arguments and is listed for completeness, not as load-bearing.

### 3.4 What is *not* an argument

**Performance.** AP-01 through AP-16 total roughly 105 writes and a few hundred reads per day. §15 projects 6 MB at twelve months. Every language considered is idle at this volume, and any argument that reaches for throughput benchmarks is answering a question this project does not ask. The decision rests entirely on type boundaries, runtime count, and ecosystem fit.

---

## 4. Rejected alternatives {#rejected}

Following the convention of §19 in the database docs: what was considered, and why it lost. None of these are bad choices in the abstract; each lost to something specific about this project.

| # | Considered | Why it lost |
|---|---|---|
| 1 | **Python / FastAPI** — already declared in `pyproject.toml` (`fastapi>=0.115`, `uvicorn`, script `pw-api = "pw.api.main:run"`) `[E]` | The genuinely close call, and it would still work. FastAPI plus Pydantic is excellent, OpenAPI codegen recovers most of the type-sharing story, and switch cost is zero in both directions today. It loses on **runtime count** (§3.2) and on the fact that the type-sharing is *generated and synchronised* rather than *shared*, which is a step that can be skipped and therefore eventually will be. **Retained for AI/ML** (§5) — this is a narrowing, not a rejection |
| 2 | **Go** | Right tool, wrong problem. Its decisive wins are concurrency, deploy size and memory footprint; the workload is ~105 writes/day, where none of the three is felt. The cost is verbose CRUD plus OpenAPI or sqlc codegen to recover the type safety TypeScript provides natively, and a third language for one operator to maintain |
| 3 | **C#** | The strongest of the non-TypeScript options — Minimal APIs are terse, EF Core is a genuinely first-rate ORM, tooling is excellent. Still a third runtime, still no shared types, and Turso/libSQL support is the thinnest in the set. Would be the pick if this were a .NET shop; it is not |
| 4 | **Java / Spring Boot** | Disproportionate. Seven tables, one writer, one human, 6 MB at twelve months. Spring Boot's strengths are large teams and complex domains, and its costs — ceremony, iteration speed, deploy weight — are paid in full regardless of project size |
| 5 | **PHP / Laravel + Filament** | Taken seriously, because Filament genuinely is the best admin-panel tooling in any ecosystem, and the MVP screens (AP-05, AP-06, AP-07, AP-10, AP-16) are exactly the CRUD-table-and-form class it generates. Laravel's scheduler, queues and Horizon would also answer §8 well. **Lost on the driver:** the Turso PHP and Laravel SDKs are in technical preview, split across three competing packages, and the official adapter requires FFI enabled. Betting the backend on a technical-preview driver against a production host is not a risk this project needs. Choosing it would also have forced abandoning Turso for MySQL/Postgres — reopening a decision §16.2 settled on its own merits, to accommodate a language choice. Wrong direction of causation. Secondary cost: Filament is the TALL stack, so the frontend decision in §7 would be discarded, and an admin panel is not automatically the *user-friendly agent workspace* the MVP is aiming at |
| 6 | **A separate backend service in any language** (rather than the frontend server doing double duty) | Premature. One operator, one database, no independent scaling axis. The split can be made later if a genuine boundary appears; making it now buys nothing and costs a deploy target |

---

## 5. What stays Python {#python-scope}

### 5.1 The AI/ML layer — settled

**Retained, and it is the only settled Python component.** Ollama, embeddings, and any classification or extraction model work. It runs as a separate small service or as an invoked job, and it does not own domain logic or write to the database directly (SQ-3).

### 5.2 The scraper — conditional, not decided {#scraper}

> **⚠️ REVISED v1.0.1.** Version 1.0.0 stated flatly that the scraper moves to TypeScript, on the grounds that Playwright is TypeScript-native. That argument is true but thin, and it was propped up by §3.2's runtime-count argument, which does not apply to a batch job. The original reasoning is replaced rather than annotated, because unlike a ruling with downstream dependents, nothing was built on it.

**The rule, which is what SD-7 actually decides:**

> **The scraper's language follows whoever writes to the database.**
>
> | Shape | Scraper language |
> |---|---|
> | Scraper **writes the database directly** | **Must be TypeScript** |
> | Scraper **POSTs extracted listings to the TypeScript API**, which owns all writes | **Free** — Python is fully acceptable |

**Why the write path is the decider and the parsing library is not.** The database chapters are uncompromising about write discipline: `STRICT` tables (§16.2), IG-7's `PRAGMA foreign_keys=ON` on every connection, the one-transaction rule for the daily batch (§3), and M6's single writer. A Python scraper writing directly against a Drizzle-declared schema gets **no type safety on the write path** and reimplements the connection-pragma discipline in a second codebase — precisely the drift §3.1 exists to prevent. Routing the scraper through the API removes that objection entirely, and satisfies M6 as a side effect.

**The ecosystem question, answered honestly.** Python was originally chosen for BeautifulSoup, and that instinct was not wrong. The JavaScript ecosystem is nonetheless competitive rather than a compromise:

| Python | JS/TS | Assessment |
|---|---|---|
| Scrapy | Crawlee | Crawlee is the closest direct successor to Scrapy in architectural maturity, and its **JS version is more feature-complete than its own Python port** `[MEASURED: as reported March 2026]`. It covers HTTP crawling and browser automation in one tool, with unblocking and proxy rotation on by default |
| BeautifulSoup | Cheerio | Same role. Cheerio benchmarks ~6.6× faster on identical input (0.32 s vs 2.13 s) and is async-friendly; BeautifulSoup is strictly synchronous |
| Playwright (bindings) | Playwright (native) | TypeScript is the reference implementation |

**Where Python genuinely still wins**, recorded so this is not read as one-sided: Scrapy's middleware and pipeline corpus is deeper for large-scale server-rendered crawls; post-extraction data work (`pandas`, `rapidfuzz`) has no real JS equal; and TLS-fingerprint impersonation for anti-bot evasion (`curl_cffi`) is more established than its JS counterparts. That last point is not academic — the target portals do employ bot protection.

**Where TypeScript fits these particular targets:**

| Tier | Portal | Shape | Bearing on the choice |
|---|---|---|---|
| 1 | mudah.my | `httpx` against the `__NEXT_DATA__` payload `[E: pyproject.toml comment]` | A JSON blob embedded by Next.js. **Not HTML parsing at all** — BeautifulSoup contributes nothing here |
| 2–4 | PropertyGuru, iProperty, EdgeProp | not implemented `[ASSUMED: modern JS single-page applications]` | Browser automation or reverse-engineered JSON APIs. Native JS territory |

BeautifulSoup's decisive strength is forgiving parsing of messy server-rendered HTML. **That is the case this project has least of** — which is the substantive argument for TypeScript, and the one v1.0.0 should have made.

**Current lean: TypeScript + Crawlee.** Overrule it if portal markup churn means constant scraper iteration — familiarity in the fastest-changing component is a legitimate reason for a solo operator to prefer Python, and choosing Python costs nothing architecturally provided the API owns the writes.

### 5.3 Consequence for AP-14

AP-14's provenance reads *"Narrow fuzzy-dedup candidates before doing string work in Python."* **Under the Python branch it stands unchanged.** Under the TypeScript branch only the language of the post-filter moves — the access pattern, its predicates and `idx_properties_dedup` are untouched. Either way performance is irrelevant at ~15 candidates × ~105 listings/day, so nothing here depends on `rapidfuzz`-class matching speed.

---

## 6. Consequence for the engine and driver {#engine}

**This decision interacts directly with §16.2 of `06-operations.md`, and resolves part of it favourably.**

§16.2 recommends moving the embedded path off Turso Database 0.7.x to stock SQLite, on three grounds: views, triggers, generated columns, `VACUUM` and `ATTACH` are all experimental on that engine; multi-process access is documented as unsupported; and it is pre-1.0 with an unpinned upper bound. The schema *needs* a view — `follow_up_inbox` is the follow-up feature.

Migration step **M4** states this as *"Move the Python path from `pyturso` to stdlib `sqlite3`"*. Under SD-1 that step does not disappear; it changes shape into a driver choice:

| Path | Driver | Note |
|---|---|---|
| Embedded (local dev, tests, single-writer job) | **`better-sqlite3`** | Synchronous API, which suits SQLite's single-writer model rather than fighting it. Bundles a current SQLite, so `STRICT` tables, stable views, triggers and generated columns are all available |
| Turso Cloud remote (while n8n needs HTTP reach) | **`@libsql/client`** | Version 0.17.x, production-grade. Also accepts `file:` URLs, so it can serve both paths if a single driver is preferred |

**Do not use `node:sqlite`** despite it being built in: `drizzle-kit` does not support it for migrations, requiring `better-sqlite3`, `bun`, `@libsql/client` or `@tursodatabase/database` instead. It is also still short of the final stability stamp — Stability 1.2, release candidate, on Node 24+.

**The distinction that makes this a de-risking rather than a lateral move.** The Turso name currently covers two different products:

- **libSQL** — the C fork of SQLite. Production-ready, and what Turso Cloud runs today.
- **Turso Database** — the clean-room Rust reimplementation, formerly *Limbo*. In beta; its maintainers state plainly that libSQL is production-ready and the Rust engine is not.

The repository is currently on the second: `DATABASE_SCHEMA.md` records the engine as *Turso Database 0.7.1 (SQLite dialect, Rust reimplementation)* with driver `pyturso` 0.7.2. Moving to `better-sqlite3` or `@libsql/client` puts the project on a production-ready engine and removes the experimental-feature constraints §16.2 spends three paragraphs working around. **This is a benefit of SD-1 that was not the reason for it.**

**`STRICT` tables remain the single biggest win**, exactly as §16.2 argues, and the argument gets stronger rather than weaker: for a database fed by a scraper and an LLM, both of which emit whatever they emit, declaration-as-enforcement is worth more than any index. Drizzle should declare tables `STRICT`.

---

## 7. Frontend {#frontend}

**Now (SD-5): Solid + Vite, as a single-page application**, served as static assets by the Node process.

There is no SSR requirement. §1 of `01-current-state.md` scopes this to one Malaysian agent's working tool — internal, authenticated, no SEO surface. AP-05 (browse the feed) runs ~30/day and AP-06 (follow-up inbox) ~20/day. Server rendering would buy nothing at that shape.

Supporting libraries: `@solidjs/router`, `@tanstack/solid-query`, `@tanstack/solid-table` for the AP-05 and AP-06 tables, and Kobalte or Ark UI for accessible primitives.

**At scale (SD-6): SvelteKit.** Provisional, and the trigger is explicit so it does not become a matter of taste:

> **Revisit when the feed becomes a public surface.** AP-05's own provenance note already anticipates this — *"If this becomes a public web surface at 5k/day, AP-05 moves from 'nice to index' to the hottest path in the system."* At that point SEO becomes existential rather than irrelevant, and server rendering earns its place.

SvelteKit was chosen over the alternatives at that horizon because it is the only one of the four candidates that handles a content-heavy public surface *and* an application dashboard competently in one codebase, and it is the most mature. TanStack Start (v1.0, March 2026) would win if the internal tool alone dominates; Astro would win if public SEO alone dominates, at the cost of a second codebase for the dashboard. SolidStart was rejected despite being the cheapest migration from SD-5 — component reuse should not select a production framework, and it is last of the four on ecosystem, maintainer count and hiring pool.

**SD-1 makes SD-6 cheaper**, incidentally: the server layer already speaks TypeScript, so adopting a meta-framework later changes the shell rather than the stack.

---

## 8. n8n {#n8n}

**Unchanged for now. This is deliberate.** n8n works, it is the only current write path `[E: §2.1 source P5]`, and replacing it competes for MVP time against work the user actually sees. The MVP goal is a useful, user-friendly agent workspace.

**The constraint the replacement must satisfy, recorded now so the choice is not made by accident:** whatever replaces n8n lives in the application language, and therefore in TypeScript. Candidates are BullMQ for queued and repeatable jobs, or a plain scheduler — at one scrape run per day, a cron trigger is genuinely sufficient.

**The detail that matters more than the job runner.** §3 of `02-access-patterns.md`: the daily batch of ~105 upserts must be wrapped in **one transaction**. Unbatched, each insert is its own fsync and throughput drops by roughly two orders of magnitude. No choice of scheduler compensates for getting this wrong, and no scheduler is required to get it right.

**This decision partially answers OQ-2** (*"Is `pw` (Python/FastAPI) or n8n the intended long-term system?"*). The application layer is now settled — TypeScript, replacing the `pw` Python/FastAPI half of that question. What remains open is the *timing* of the n8n handover, which is what OQ-11 turns on. See SQ-2.

---

## 9. Open questions {#open-questions}

Each carries the assumption currently in force and what breaks if it is wrong, following the convention of §20.

1. **SQ-1 — Does the embedded path or the Turso Cloud remote win?** *In force:* both exist during handover — `better-sqlite3` locally, `@libsql/client` against the remote while n8n needs HTTP reach. *Blast radius:* moderate. §16.2's note applies unchanged — *"an embedded file is not reachable that way"* — so this is decided by OQ-11, not by the language. Running both drivers indefinitely is a maintenance tax worth paying only for the length of the handover. *Who answers:* Vincent, once §8's timing is set.

2. **SQ-2 — When does n8n hand over?** *In force:* no date; n8n keeps ingest until the workspace MVP ships. *Blast radius:* this is OQ-11 restated from the application side. It gates SQ-1, and it gates whether `raw_payloads` (§23.1) is practical, since pushing multi-KB gzipped blobs over the Turso HTTP `/v2/pipeline` API is materially different from writing them to a local file. *Who answers:* Vincent.

3. **SQ-3 — Does the AI/ML layer talk to the database, or only to the application?** *In force:* only to the application; Python holds no database credentials and owns no domain logic. *Blast radius:* significant if it drifts. A second writer reintroduces the multi-process problem §16.2 names as a binding constraint, and re-opens IG-7 (`PRAGMA foreign_keys=ON` per connection) on a second code path. **Keep the Python layer stateless and credential-free unless this is explicitly revisited.**

4. **SQ-4 — Is `pyproject.toml` narrowed or retired?** *In force:* narrowed, never retired. `fastapi`, `uvicorn`, `pyturso` and `apscheduler` leave unconditionally, and the `pw-api` console script with them. **`httpx` and the `pw-scrape` script are held pending SD-7** (§5.2) — they stay under the Python-scraper branch and leave under the TypeScript one. `pydantic` and `pydantic-settings` stay only if the ML service wants them. *Blast radius:* small and purely mechanical, but leaving it unchanged makes the repository state a false claim about the architecture. Note that `pyturso`'s removal completes M4 by a different route than M4 describes. *Who answers:* mechanical, except for the two entries gated on SQ-6; do the unconditional part with the first TypeScript commit.

5. **SQ-5 — Does the frontend stay a SPA through the MVP?** *In force:* yes (SD-5). *Blast radius:* low. The revisit trigger in §7 is a business event, not a technical one, and nothing in the SPA choice makes SD-6 more expensive later.

6. **SQ-6 — Which branch of SD-7 does the scraper take?** *In force:* the TypeScript branch, as a lean rather than a ruling (§5.2). *Blast radius:* **low, and deliberately so — that is the point of framing SD-7 as a conditional.** Provided the API owns every database write, the scraper's language is an implementation detail behind an HTTP contract, and switching it later costs one component rather than an architecture. It becomes expensive **only** if the scraper is allowed to write the database directly and is then rewritten in the other language. *What settles it:* whether the first portal adapters churn enough that BeautifulSoup familiarity outweighs Crawlee's browser-plus-HTTP coverage. *Who answers:* Vincent, on evidence from the first two adapters — not in advance.

---

## 10. Changelog {#changelog}

| Version | Date | Author | Change |
|---|---|---|---|
| 1.0.1 | 2026-08-11 | Vincent + Claude | **SD-7 reframed from a ruling into a conditional** (§5.2). v1.0.0 moved the scraper to TypeScript on the strength of Playwright being TypeScript-native, reinforced by §3.2's runtime-count argument — which does not apply to a once-daily batch job, since Python is retained for AI/ML regardless. §3.2 now carries an explicit scope limit. The replacement rule is that **the scraper's language follows whoever writes to the database**: TypeScript if it writes directly, free if it POSTs to the API. Added an honest ecosystem comparison (Crawlee/Cheerio/Playwright against Scrapy/BeautifulSoup) including three areas where Python still wins outright, and restated the pro-TypeScript case on the grounds that actually apply here — tier 1 is `__NEXT_DATA__` JSON extraction and tiers 2–4 are JS single-page applications, so BeautifulSoup's core strength is the case this project has least of. AP-14's consequence (§5.3) and SQ-4's `httpx`/`pw-scrape` entries are now branch-dependent. Opened SQ-6. No change to SD-1…SD-6, SD-8, SD-9. |
| 1.0.0 | 2026-08-11 | Vincent + Claude | Initial document. Established **TypeScript** as the application language (SD-1) with Python narrowed to the AI/ML layer (SD-8). Recorded six rejected alternatives with reasons, including the close call against the already-declared Python/FastAPI stack and the seriously-considered Laravel + Filament option. Chose Drizzle over libSQL/SQLite (SD-3) and recorded the driver consequence for §16.2 and migration step M4, including the libSQL versus Turso Database distinction. Recorded the frontend decision as Solid SPA now (SD-5) with SvelteKit provisional at a named public-surface trigger (SD-6). Deferred the n8n replacement (SD-9) while fixing the constraint it must satisfy. Opened SQ-1…SQ-5. Partially answers OQ-2. |
