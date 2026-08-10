# Database Schema — Property Agent Workspace

| | |
|---|---|
| **Engine** | Turso Database 0.7.1 (SQLite dialect, Rust reimplementation) `[MEASURED: /Users/vincent-sequoia/.turso/tursodb --version @ 2026-08-06 → "Turso 0.7.1"]`; driver `pyturso` 0.7.2 `[MEASURED: .venv/lib/python3.13/site-packages/pyturso-0.7.2.dist-info @ 2026-08-06]` |
| **Doc version** | 1.1.0 |
| **Last updated** | 2026-08-10 |
| **Status** | Partially implemented — V1 DDL exists in the repo but is deployed **nowhere**; the only live database carries a pre-V1 (V0) shape |
| **Owner** | Vincent Khoo (sole operator) |

> **This file is the index. The chapters under [`docs/database/`](docs/database/) are authoritative.**
> Everything below is navigation and a summary of what changed. Where this page and a chapter
> disagree, the chapter is right — and if you are editing, edit the chapter.

---

## Chapters

| File | Sections | What is in it |
|---|---|---|
| [`01-current-state.md`](docs/database/01-current-state.md) | §1–§2 | Scope and non-goals; the drift register — what is deployed versus what the repo declares, the broken n8n write path, engine-maturity constraints, secrets |
| [`02-access-patterns.md`](docs/database/02-access-patterns.md) | §3–§4 | AP-01…AP-16 with frequencies and latency targets; naming, timestamp, money, enum and soft-delete conventions; primary-key strategy |
| [`03-entities.md`](docs/database/03-entities.md) | §5–§7 | The ERD; all seven V1 tables plus the deprecated V0 `listings`, each with grain, columns, constraints, indexes, storage and lifecycle; cardinalities and invariants |
| [`04-integrity.md`](docs/database/04-integrity.md) | §8–§10 | IG-1…IG-10 — invariants the DDL cannot hold; the indexing strategy and the one missing index; the full traceability matrix and orphan analysis |
| [`05-behaviour.md`](docs/database/05-behaviour.md) | §11–§13 | `follow_up_inbox`; why there are no triggers; the denormalization register |
| [`06-operations.md`](docs/database/06-operations.md) | §14–§18 | Audit, retention and the PII register; storage projections; the scaling ladder and the engine decision; the migration plan M1…M7; query-plan assertions |
| [`07-decisions.md`](docs/database/07-decisions.md) | §19–§21 | Fourteen rejected alternatives with reasons; thirteen open questions; the changelog |
| [`08-review-v1.1.md`](docs/database/08-review-v1.1.md) | §22–§24 | **New in 1.1.0** — five defects found after v1.0.0; the proposed entity roadmap; the proposed cuts |

**Start here:**

- **New to the schema** → [`01-current-state.md`](docs/database/01-current-state.md), then the ERD at the top of [`03-entities.md`](docs/database/03-entities.md).
- **About to implement** → [`06-operations.md`](docs/database/06-operations.md) §17, the migration plan. Read [`08-review-v1.1.md`](docs/database/08-review-v1.1.md) first — it changes what M1 has to do.
- **Deciding what to build** → [`08-review-v1.1.md`](docs/database/08-review-v1.1.md), then the open questions in [`07-decisions.md`](docs/database/07-decisions.md).

Cross-references inside the chapters are written as plain `§N.N`, `IG-N` and `AP-NN` — use the table above to find the file.

---

## The headline, unchanged since 1.0.0

> ⚠️ **DRIFT (P0 vs P3) — the live database and the repo schema have no table in common.**
> `listings.db` contains exactly one domain table, `listings`, with 39 columns
> `[MEASURED: PRAGMA table_info(listings) @ 2026-08-06]`. `schema.sql` declares `contacts`,
> `properties`, `property_sources`, `contact_properties`, `interactions`, `price_history`,
> `scrape_runs` and the `follow_up_inbox` view. **Zero overlap.** Per Gate 1, P0 is fact:
> what is deployed is V0. P3 is intent: V1 is a design, not a deployment.

This remains a *good* problem. `listings` holds **0 rows** `[MEASURED @ 2026-08-06]`, and the V1 tables exist in no database at all. Nothing to migrate, nothing to backfill, nothing to lose — **this is still the cheapest schema-change moment the project will ever have**, and every recommendation in every chapter is priced on that basis.

---

## What changed in 1.1.0

Three v1.0.0 rulings are superseded. Each carries an inline `⚠️ SUPERSEDED v1.1.0` marker at its original site, with the original reasoning left intact — see §22–§24 for the arguments.

**Five defects** ([§22](docs/database/08-review-v1.1.md#defects-v11))

1. **IG-10 — the timestamp contract names two incompatible formats.** `datetime('now')` writes a space separator; the n8n producer writes `T`. `TEXT` compares bytewise, so a mixed column is not ordered at all — the expiry sweep silently never fires on half the rows.
2. **`contacts.phone` is identity on one mutable, nullable attribute.** Two numbers, a recycled number, or an email-only contact each break dedup in a different direction.
3. **`follow_up_inbox` sorts never-contacted rows last** — the bucket that most needs action is the one the ordering hides.
4. **No change-detection hash on `property_sources`** — every field but price is blind-overwritten each run.
5. **`properties.status` carries two lifecycles**, so the staleness sweep and the agent overwrite each other.

**Entity roadmap** ([§23](docs/database/08-review-v1.1.md#roadmap)) — 5 Tier-0 infrastructure tables (`schema_migrations`, `raw_payloads`, `portals`, `scrape_targets`, `fetch_log`), 13 Tier-1 workspace tables (`deals`, `appointments`, `tasks`, `requirements` and friends), 4 Tier-2 triggered. Plus AP-17…AP-24 marked proposed, a second ERD, and the PII rows the new tables bring with them.

**Seven cuts** ([§24](docs/database/08-review-v1.1.md#cuts)) — the `follow_up_inbox` view (removes the schema's largest engine risk), `scrape_runs` conditionally, `price_per_sqft`, `price_at_scrape_cents`, `properties.created_at`, `updated_at` on two tables, and six unverifiable `scrape_runs` counters. With an explicit kept-list so they are not re-proposed.

**Suggested order** — each is a `CREATE TABLE` today and a maintenance window in six months:

1. `schema_migrations` — nothing else is safe to ship without it
2. The timestamp guard and `contact_identifiers` — free while the tables are empty
3. `portals`, `scrape_targets`, `raw_payloads` — makes the scraper a scraper
4. `deals`, `appointments`, `tasks` — makes the workspace a workspace
5. `requirements` + `requirement_matches` — the reason the other two exist

---

## Not covered here

- **`src/pw/db/schema.sql` is unchanged** and still carries the uncorrected V1 DDL — `AUTOINCREMENT`, `price REAL`, `price_history.website`, anonymous constraints. §17's M1 and M1b describe every edit it needs; applying them is a separate change.
- **n8n's own operational database** (workflow definitions, execution history) lives in the `n8n_data` volume and is n8n's business, not ours. Google Sheets is a presentation sink, not a source of truth.
