# Scope & current state

*Part of [Database Schema](../DATABASE_SCHEMA.md) — §1–§2. Chapter files are authoritative; the root index only summarises.*

---

## 1. Scope & non-goals {#scope}

**Covers** the persistent state of a single Malaysian property agent's working tool:

- **the book** — own mandates, contacts, the roles people play on deals, every interaction, and the follow-up queue derived from them. Small, high-value, hand-curated, irreplaceable if lost.
- **the feed** — listings scraped from mudah.my, PropertyGuru, iProperty and EdgeProp. Large, low-value per row, entirely reconstructible by re-scraping.

The two halves share one `properties` table separated by an `acquisition` discriminator. That is a deliberate choice and is defended in §19.

**Non-goals.** n8n's own operational database (workflow definitions, execution history) lives in the `n8n_data` volume and is n8n's business, not ours. Google Sheets is a presentation sink, not a source of truth. The Ollama model layer holds no state. Analytical/BI modelling is out of scope — at the volumes projected in §15 the transactional tables answer every analytical question directly.

**Planning horizon** — 12 months, with a named 100x checkpoint (one district → the Klang Valley) in §16.

---

## 2. Current state & drift register {#current-state}

### 2.1 Sources consulted

| Rank | Source | Reached? | What it told us |
|---|---|---|---|
| **P0** | `listings.db` (+ `-wal`, `-shm`) at repo root | **yes** — read-only via `sqlite3 -readonly` and `tursodb --readonly` | One table, `listings`, 39 columns, **0 rows**. A V0 shape. Not the V1 schema at all |
| **P0** | Turso Cloud primary at `property-websites-webscraper-vincent-khoo.aws-ap-northeast-1.turso.io` | **NO — deliberately not contacted** | A production host I was not pointed at. Its true schema and row count are unknown. See OQ-1 |
| **P1** | Applied migration history | **none exists** | No `migrations/`, no `alembic/`, no version table. `PRAGMA user_version` = 0 `[MEASURED @ 2026-08-06]`. Schema changes are applied by hand |
| **P2** | ORM / model definitions | **none exist** | Every module under `src/pw/` is empty except a docstring `[MEASURED: wc -c on all 7 files @ 2026-08-06 → 32 bytes total]`. There is no application yet |
| **P3** | `src/pw/db/schema.sql` | yes | The V1 design: 7 tables + 1 view. Well-reasoned, internally consistent, **and applied to no database on disk** |
| **P3** | `test.json` → node 29 (`n8n-nodes-base.postgres`) | yes | An abandoned **PostgreSQL** DDL draft (`GENERATED ALWAYS AS IDENTITY`, `TIMESTAMPTZ`, `VARCHAR(20)`). Historical origin only — see §19 |
| **P4** | Existing `DATABASE_SCHEMA.md` | **none existed** | This document is the first |
| **P5** | `current-n8n-setup.json`, `what.json` | yes | The **real write path**. n8n is today the only thing that writes to the database |
| **P5** | `tests/test_schema.py` | yes | The only executable queries against V1. All 8 passed on the last run `[MEASURED: .pytest_cache/v/cache/lastfailed == {} @ 2026-08-06]` |
| **P5** | `git log`, `.env`, `docker-compose.yml`, `pyproject.toml`, `.gitignore` | yes | Engine resolution, config, history |

### 2.2 The headline

> ⚠️ **DRIFT (P0 vs P3) — the live database and the repo schema have no table in common.**
> `listings.db` contains exactly one domain table, `listings`, with 39 columns
> `[MEASURED: PRAGMA table_info(listings) @ 2026-08-06]`. `schema.sql` declares `contacts`,
> `properties`, `property_sources`, `contact_properties`, `interactions`, `price_history`,
> `scrape_runs` and the `follow_up_inbox` view. **Zero overlap.** Per Gate 1, P0 is fact:
> what is deployed is V0. P3 is intent: V1 is a design, not a deployment.

This is a *good* problem. `listings` holds **0 rows** `[MEASURED: SELECT count(*) FROM listings @ 2026-08-06 → 0]`. There is nothing to migrate, nothing to backfill, nothing to lose. **This is the cheapest schema-change moment this project will ever have**, and every recommendation below is priced accordingly. In six months, with 40,000 scraped rows and a year of interaction history, the same changes cost a maintenance window and a backfill script.

### 2.3 The `floor` / `floors` mismatch

`schema.sql` line 52 carries its own confession:

```sql
floor INTEGER,   -- NB: old schema said `floors`, code wrote `floor`
```

The comment is half right, and the half it gets wrong matters.

> ⚠️ **DRIFT (P0 vs P3 vs P5) — three sources, three spellings, and the comment points the wrong way.**
> - **P0, live** — the column is `floors SMALLINT` `[MEASURED: PRAGMA table_info(listings) → ordinal 11 = "floors" @ 2026-08-06]`. The "old" spelling is not old; it is what is deployed.
> - **P3, `schema.sql`** — declares `floor INTEGER`.
> - **P5, n8n** — the INSERT column list says `floor`, and binds it to the JavaScript key `$json.floor`, while the surrounding record builder emits `floors` nowhere.
>
> Per Gate 1, **P0 is fact**: the live column is `floors`. The comment in `schema.sql` describes
> the correct *destination* but implies the migration already happened. It has not.

**Resolution.** Keep `floor` (singular) as the V1 name — it is the correct English for "which floor is this unit on", it is what the n8n producer already emits, and `floors` invites the reading "how many floors does it have". Since the live table is empty, this costs a `CREATE TABLE`, not a rename. Fix the comment in `schema.sql` to stop implying history that did not occur.

### 2.4 The n8n write path is broken against the live schema

Not a stylistic drift — a hard, current, total failure of the only write path in the system.

> ⚠️ **DRIFT (P0 vs P5) — every n8n database call fails against `listings.db` as deployed.**

**The dedup probe** (`current-n8n-setup.json` nodes 22 and 24, `HTTP Request2` / `HTTP Request – Retrieve All Listings From DB`):

```sql
SELECT * FROM listings WHERE advertisement_id = ? OR phone = ?
```

```
[MEASURED: tursodb --readonly listings.db "EXPLAIN QUERY PLAN SELECT * FROM listings
           WHERE advertisement_id = 1 OR phone = '60123456789'" @ 2026-08-06]
  × Parse error: no such column: advertisement_id
```

**The INSERT** (`what.json`, and node 28's generated body) names 40 columns. Seven of them do not exist on the live table `[MEASURED: set difference of the INSERT column list against PRAGMA table_info(listings) @ 2026-08-06]`:

| n8n writes | Live table actually has | Nature of the mismatch |
|---|---|---|
| `advertisement_id` | `listing_id` | renamed concept |
| `floor` | `floors` | §2.3 |
| `scraped_date` | `scrapped_date` | **typo in the live column** (double `p`) |
| `created_date` | `created_at` | convention drift |
| `updated_date` | `updated_at` | convention drift |
| `rating_reason` | *(absent)* | column never added |
| `scam_reasons` | *(absent)* | column never added |

The statement fails on the first unknown column. Placeholder count is fine (40 `?` for 40 columns), so this is purely a naming failure — the least excusable kind and the easiest to fix.

**Two more producer defects, both live:**

1. **`facilities` is not JSON.** The pinned sample payload sends
   `"Playground, Tennis Court, Gymnasium, Parking, Security, ..."` — a comma-separated string.
   ```
   [MEASURED: SELECT json_valid('Playground, Tennis Court, Gymnasium') @ 2026-08-06 → 0]
   ```
   Both the live table and V1 guard this column with `CHECK (facilities IS NULL OR json_valid(facilities))`. The constraint is correct; **the producer is wrong**. See §6.2 and §19.
2. **Phones are not normalised.** The pinned payload carries `"0162339069"` — local Malaysian format. `schema.sql`'s header states the storage contract is digits-only with country code and no `+` (`60162339069`). Nothing in the n8n path performs that transform. A unique index over unnormalised input is decoration, not deduplication (doctrine §4). See §8, IG-2.
3. **The dedup key is never populated.** In the pinned payload the first bound argument — `advertisement_id` — is `{"type":"null"}`. The extractor assigns `listing_id: scraped.advertisement_id || ''`, and the upstream parser did not produce one. Even with the column names fixed, the row would insert with a null identity, and the live table declares `listing_id BIGINT UNIQUE NOT NULL` — so the second such row would collide on `NULL`… except SQLite treats `NULL`s as distinct in a unique index, so it would instead insert unboundedly many identity-less duplicates. See IG-1.

### 2.5 The cross-portal collision in the live unique key

The live table's only index is the implicit one behind `listing_id BIGINT UNIQUE`:

```
[MEASURED: SELECT name, sql FROM sqlite_master WHERE type='index' @ 2026-08-06
           → sqlite_autoindex_listings_1 | NULL]
```

> ⚠️ **DRIFT (P0 vs domain contract) — the live uniqueness key is `listing_id` alone.**
> The stated identity of a portal listing is **`(website, advertisement_id)`**. mudah ad `115402662`
> and an iProperty ad that happens to share that integer are different listings, and the live
> schema would reject the second as a duplicate. `schema.sql` gets this right with
> `UNIQUE (website, advertisement_id)` on `property_sources`. The live table does not.
>
> Confirmed at plan level — filtering on both columns still probes the single-column index:
> ```
> [MEASURED: EXPLAIN QUERY PLAN SELECT * FROM listings WHERE website='mudah' AND listing_id=1
>            @ 2026-08-06]
>   `--SEARCH listings USING INDEX sqlite_autoindex_listings_1 (listing_id=?)
> ```
> `website` is not part of the key; it is only a residual filter.

### 2.6 Migration-history defects

Reported as their own class per Gate 1 rule 4.

| Defect | Detail |
|---|---|
| **No migration mechanism at all** | No `migrations/`, no `alembic/`, no `drizzle/`, no `atlas.hcl`, and `PRAGMA user_version = 0` `[MEASURED @ 2026-08-06]`. There is no way to tell, from a database file, which schema version it holds — which is exactly how the V0/V1 divergence in §2.2 went unnoticed |
| **`schema.sql` is a bootstrap file, not a migration** | It is `CREATE TABLE IF NOT EXISTS` throughout. Run against `listings.db` it would create all seven V1 tables **alongside** the V0 `listings` table and report success. Silent divergence by design |
| **Applied but not in the repo** | The live `listings` table was created by something not in this repository. `test.json` node 29 holds a *Postgres* draft of it; no SQLite/Turso DDL for it exists anywhere in the tree |
| **Engine artifacts confirm provenance** | The live file contains `__turso_internal_seq___turso_internal_autoincrement_listings` `[MEASURED: .tables @ 2026-08-06]` — a Turso-Database-specific structure backing `AUTOINCREMENT`. The file was created by Turso, not stock SQLite. It remains readable by stock SQLite 3.51.0, so the on-disk format is compatible |

### 2.7 Engine maturity — the finding that constrains everything below

Gate 2 Step 3 requires validating every recommendation against the profile, and this engine's feature set is narrower than the SQLite profile assumes.

```
[MEASURED: /Users/vincent-sequoia/.turso/tursodb --help @ 2026-08-06]
  --experimental-views            --experimental-generated-columns
  --experimental-vacuum           --experimental-without-rowid
  --experimental-autovacuum       --experimental-attach
  --experimental-encryption       --experimental-multiprocess-wal
  --experimental-index-method     --experimental-mvcc-passive-checkpoint
```

Turso's own manual states the engine lacks *"multi-process and multi-threading access, savepoints, triggers, views, and vacuum"* outside those flags. That collides with this schema in three places:

1. **`follow_up_inbox` is a view.** It is the follow-up feature. On this engine views are experimental.
2. **Honest `updated_at` wants a trigger.** Triggers are experimental. Doctrine §8 calls `updated_at` maintained by a trigger the baseline; here it must be enforced in the application. See IG-4.
3. **The deployment shape is multi-process** — the n8n container, a future `pw-api` (FastAPI/uvicorn), an APScheduler process, and the test suite. Multi-process access is exactly what the manual excludes.

**Countervailing measurement, and it matters:** views demonstrably *work* through `pyturso` 0.7.2 — `tests/test_schema.py` queries `follow_up_inbox` in four tests and all 8 tests passed on the last run `[MEASURED: .pytest_cache/v/cache/lastfailed == {} @ 2026-08-06]`. So the Python binding is ahead of the CLI's flag gating, or enables the feature by default. Treat this as "works today, not contractually stable" — it is a pre-1.0 engine.

**Upsert and partial indexes are supported** and may be recommended freely (verified against current Turso documentation, 2026-08-06): `CREATE INDEX ... WHERE <predicate>` and `INSERT ... ON CONFLICT (cols) [WHERE expr] DO UPDATE SET ... ` including `excluded.*` references and conditional `WHERE` on the update. Note: a *partial* unique index used as a conflict target must repeat its `WHERE` clause in the `ON CONFLICT` clause.

### 2.8 Secrets

Not a schema defect, but it sits in the files this review read, so it gets one line. The Turso **read-write** auth token appears in plaintext in `.env` and in `current-n8n-setup.json` (twice, as a hardcoded `Authorization: Bearer` header on nodes 22 and 24). `.env` is gitignored; `current-n8n-setup.json` is **not** — it is untracked and uncovered by `.gitignore`, so a `git add -A` commits it. No tracked file currently contains the token `[MEASURED: grep over git ls-files @ 2026-08-06 → no matches]`. Add `current-n8n-setup.json` to `.gitignore` or move the credential to an n8n credential object.

---
