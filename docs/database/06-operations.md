# Operations: PII, storage, scaling, migration

*Part of [Database Schema](../DATABASE_SCHEMA.md) — §14–§18. Chapter files are authoritative; the root index only summarises.*

---

## 14. Audit, retention & PII {#audit-pii}

### 14.1 Audit

**Layer 1 of doctrine §8's five — row provenance only, and that is the right depth for a single-operator tool.** Every table carries `created_at`; the mutable ones carry `updated_at`. There is no `created_by` / `updated_by` because there is exactly one actor, and there is no `audit_log` table because the generic after-trigger that would populate it needs triggers, which this engine gates as experimental (§2.7).

`interactions` is the de-facto business audit log — it records who was contacted, how, in which direction, and when. It has no `updated_at`, which is the correct instinct: **it should be append-only**. Doctrine §8 says an audit log the application can rewrite is theatre. The discipline that makes it real is simply "never `UPDATE interactions`", and since the engine offers no `REVOKE`, that is a code-review rule, not an enforced one. Recorded here so it is at least written down.

**Escalation trigger:** the day a second person can write to this database, layer 2 (a change log with an actor id) stops being optional.

### 14.2 Retention

| Table | Retention | Mechanism |
|---|---|---|
| `contacts` | **Forever** | Never deleted except on a PDPA erasure request |
| `property_parties`, `interactions` | **Forever** | The book. Irreplaceable |
| `properties` with any Mandate, Deal, Interaction or `property_parties` row | **Forever** | §7.3. **Amended 2026-09-11** — was `acquisition='own_mandate'`. The test is whether anyone has *touched* the unit, not how it arrived |
| `properties` with none of those, and every Advertisement stale | `hidden` at 14 days without a sighting; hard-deleted to `properties_archive` at 90 days | §7.3. **Neither step is implemented** — see OQ-4. **Amended 2026-09-11: the old rule was a data-loss path**, purging worked units silently through `ON DELETE CASCADE` — see §7.3 and ADR 0006 |
| `advertisements` | Follows its parent (cascade) | |
| `price_history` | Follows its parent (cascade) — **and this is the uncomfortable part**: purging a scraped listing destroys its price trail, which is precisely what V2 wants (§6.6, OQ-4) | |
| `scrape_runs` | **90 days**, hard delete | Not implemented |

### 14.3 PII register

Malaysia's **PDPA 2010** applies. Personal data here is collected from public portal listings — which limits the sensitivity but does not exempt it, and a data subject can still demand erasure.

| Column | Classification | Source | Erasure strategy |
|---|---|---|---|
| `contacts.phone` | **PII — direct identifier, and the primary key of a person in this system** | Scraped from public ads, or entered manually | **Hard delete of the `contacts` row**, cascading to `property_parties` and `interactions`. Soft delete does not satisfy erasure regulation (doctrine §7 cost 5) — which is a further argument for §7.3's no-soft-delete ruling. **⚠️ SUPERSEDED v1.1.0** — this row, and the `email` / `ren_number` rows below, are replaced by `contact_identifiers.value` (§22.2). The erasure strategy is unchanged: cascade from `contacts`. Additional rows for `documents` and `message_outbox` are staged in §23.4 |
| `contacts.name` | PII — direct identifier | as above | cascade with the row |
| `contacts.email` | PII — direct identifier | as above | cascade with the row |
| `contacts.ren_number` | PII — **regulator-issued** professional identifier | public agent registry | cascade with the row |
| `contacts.company` | Low — a business name, not personal data | | — |
| `contacts.notes`, `interactions.summary` | **PII, free-text, unbounded, and the hardest to erase** | agent-authored | Erased with the parent row. Risk: an agent may name a third party in a note about someone else, and that person's erasure request cannot reach it. No mechanism proposed — flagged as OQ-8 |
| `properties.full_address`, `latitude`, `longitude` | Borderline — a property address is personal data when it identifies a resident | scraped | Retained; the property is the subject, not the person |
| `properties.summary`, `outreach_message` (V0) | Potentially PII — LLM-generated text that quotes owner names. The pinned sample contains `"Hi Yong Wei Sim, this is Vincent Khoo…"` | LLM | Erased with the row |

**Encryption at rest: none.** Turso Database offers it behind `--experimental-encryption` (§2.7). A database file holding several thousand people's names and phone numbers on a laptop is a real exposure; full-disk encryption (FileVault) is the pragmatic answer today. Flagged as OQ-9.

**Crypto-shredding is not recommended here.** Doctrine §7 offers it as an erasure strategy, but it means per-subject encryption keys, and at this scale the operational cost exceeds a `DELETE`.

---

## 15. Storage & growth projection {#storage}

Formula, from profile §9 — SQLite stores rows as variable-length records, integers in the smallest width that fits, `NULL` at zero bytes, and `INTEGER PRIMARY KEY` at zero because it *is* the rowid:

```
row_width  = record_header (2 + 1 per column) + Σ(actual value widths) + ~4 B cell overhead
table_size = row_width × rows
index_size = Σ over indexes of (key_bytes + rowid_varint 1-9 + ~4 B cell) × rows
```

### 15.1 Twelve-month projection, current scope (one district, 3 portals, daily)

| Table | Rows @ 12mo | Row width | Table | Indexes | **Total** |
|---|---|---|---|---|---|
| `price_history` **(policy b, change-only)** | ~5,400 | 40 B | 216 KB | 151 KB | **367 KB** |
| `properties` | ~4,000 | 534 B | 2.1 MB | 296 KB | **2.4 MB** |
| `interactions` | ~7,300 | 153 B | 1.1 MB | 241 KB | **1.3 MB** |
| `advertisements` | ~5,600 | 163 B | 913 KB | 297 KB | **1.2 MB** |
| `contacts` | ~1,300 | 208 B | 270 KB | 53 KB | **323 KB** |
| `property_parties` | ~2,000 | 84 B | 168 KB | 66 KB | **234 KB** |
| `scrape_runs` | ~1,095 | 115 B | 126 KB | 33 KB | **159 KB** |
| | | | | **12-month total** | **≈ 6.0 MB** |

> **⚠️ Amended 2026-09-12.** Two rows moved. `properties` loses `last_seen_at` and
> `idx_properties_seen`, and `advertisements` gains the same column inside a widened
> `idx_advertisements_property` (`03-entities.md` §6.2, §6.3). The transfer is close to a wash —
> the whole-database figure moves from ≈ 6.2 MB to ≈ 6.0 MB — which is the point: the cut was
> made for correctness, and it did not have to be paid for in space.

*All row counts `[ESTIMATED]` per §6; all row widths `[ESTIMATED]` with the per-table arithmetic shown inline in §6.1-6.7 so a reader can recompute them.*

### 15.2 The number that actually matters

| Scenario | `price_history` @ 12mo | **Whole database @ 12mo** |
|---|---|---|
| Change-only writes (**recommended**) | 367 KB | **≈ 6.0 MB** |
| Every observation written | 139 MB | **≈ 145 MB** |
| Every observation, at the 100x checkpoint | **13.9 GB/yr** | **≈ 14.6 GB** |

**One undecided `WHERE` clause spans a factor of 24 today and 2,400 at the checkpoint.** That is the entire justification for Gate 5b: nobody would have found this by reading the DDL, because the DDL is identical in both cases. It is a decision in code that has not been written yet, which makes now the only cheap moment to make it.

### 15.3 Where the current deployment fails

| Constraint | Headroom |
|---|---|
| **Storage** | Effectively unbounded. Even the pessimistic 14.6 GB is nowhere near the engine's 281 TB ceiling or any plausible disk |
| **Working set in RAM** | At ~6 MB the entire database — data *and* indexes — fits in page cache. Every query is a memory read. This holds until roughly the 100x checkpoint |
| **Write concurrency** | **One writer, database-wide.** With ~105 writes/day in a single nightly batch, utterly irrelevant. This is SQLite's real ceiling and this workload is three orders of magnitude below it |
| **`count(*)`** | A full scan; there is no cheap estimate (profile §10). Fine at these volumes; do not build a dashboard that recounts on every page load |
| **What actually fails first** | **None of the above.** The binding constraints are engine *maturity* (§2.7) and the multi-process deployment shape — not size, not throughput. See §16 |

---

## 16. Scaling plan {#scaling}

The scaling ladder (doctrine §11) says do the cheap thing first, and most "we need to migrate" conversations are a missing index. Here, one rung of the ladder is genuinely relevant and the rest are not — but the engine question is real and is not about scale at all.

### 16.1 Now — rungs 1 and 2 only

| Rung | Action | Status |
|---|---|---|
| **1. Fix the schema and the queries** | Add `idx_properties_feed` (§9.1); drop four orphan indexes (§10.3); split AP-01's `OR` into two indexed probes; use keyset pagination; **wrap the daily batch in one transaction** — unbatched, each insert is its own fsync and throughput drops ~100x (profile §6) | **The whole job** |
| **2. Connection pooling** | **Not applicable.** An embedded engine has no connections to pool in the network sense (profile §6). What replaces it: `PRAGMA journal_mode=WAL` (already set on the live file `[MEASURED: PRAGMA journal_mode → wal @ 2026-08-06]`), `PRAGMA synchronous=NORMAL`, `PRAGMA busy_timeout=5000`, and **`PRAGMA foreign_keys=ON` on every connection** (IG-7). For the Turso Cloud HTTP path there is no persistent connection at all — each n8n call is a fresh request, which is why IG-7 bites hardest there | pragmas partly set |
| 3-7 | Vertical scale, caching, replicas, partitioning, sharding | **All unnecessary and will remain so.** A 6 MB database on one laptop serving one human does not need any of it. Partitioning is worth considering above ~50-100M rows (doctrine §11); the 100x checkpoint projects ~400k |

### 16.2 The engine decision — argued, not assumed

**The question is not "SQLite or Postgres". It is "Turso Database or stock SQLite".** Getting that framing right matters, because the reflex when a schema doc says "SQLite" is to reach for Postgres, and here that would be solving the wrong problem at meaningful cost.

**Why not Postgres — the size argument fails.** The 12-month projection is 6 MB and the 100x checkpoint is ~270 MB. A multi-GB SQLite database serving heavy reads is entirely normal (profile preamble). Migrating to Postgres would buy nothing this workload can use and would cost a server to run, back up, and patch, plus a connection pooler, plus the loss of "the database is a file I can copy". Rejected on the evidence — see §19.

**Why the current engine is nonetheless a problem, and it is not about scale:**

1. **Views, triggers, generated columns, `WITHOUT ROWID`, `VACUUM`, and `ATTACH` are all experimental** on Turso Database 0.7.x `[MEASURED: tursodb --help @ 2026-08-06]`. This schema *needs* a view (`follow_up_inbox` — it is the follow-up feature) and *wants* triggers (`updated_at`, IG-4) and generated columns (`price_per_sqft`, §13).
2. **Multi-process access is documented as unsupported**, and the deployment is inherently multi-process: the n8n container, a future `pw-api`, an APScheduler process, and the test runner.
3. **It is pre-1.0.** The repo pins `pyturso>=0.7.2` with no upper bound, so a `uv sync` can pull a breaking minor at any time.

**Recommendation: move the embedded path to stock SQLite; keep Turso Cloud only if the n8n layer genuinely needs network access to the data.**

The move is close to free, which is what makes it the right call rather than a preference:

- `pyturso` presents a DB-API-shaped interface, so the Python change is `import sqlite3` in place of `import turso` plus an exception-type rename in the two tests that assert `turso.IntegrityError`.
- The project's own interpreter already ships **SQLite 3.51.0** `[MEASURED: .venv/bin/python -c "import sqlite3; print(sqlite3.sqlite_version)" @ 2026-08-06]` — far above 3.37, so `STRICT` tables, `RETURNING`, partial indexes, generated columns, and stable views and triggers are all available **at zero install cost**.
- The on-disk format is already compatible: stock `sqlite3` 3.51.0 reads the Turso-created `listings.db` without complaint `[MEASURED @ 2026-08-06]`.
- **`STRICT` tables are the single biggest win.** Profile §2: SQLite has type *affinity*, not types — a `TEXT` column will silently accept an integer. `STRICT` (3.37+) turns declarations into enforcement. For a database fed by a scraper and an LLM, both of which emit whatever they emit, that is worth more than every index in §9.

**What keeps Turso Cloud in the picture:** the n8n container talks to the database over the HTTP `/v2/pipeline` API, and an embedded file is not reachable that way. If n8n remains the ingest path, the remote stays. §17 offers the alternative — put a single writer in front of it — which is better for IG-7 (foreign keys per connection) regardless of engine.

> ### ⚠️ Reconciled 2026-09-11 — `STRICT` is taken, and the engine question is closed
>
> This section recommends `STRICT` and moving the embedded path to stock SQLite. **Both are now
> rulings rather than recommendations** — see ADR 0005. SQLite runs in development, CI and
> production; there is no second engine anywhere, and CI needs no service container because it
> inherits the same file database.
>
> Two corrections to what is written above. **The version floor that matters is the driver's,
> not the shell's** — migrations run through `pdo_sqlite` 3.45.2, not the CLI's 3.51.0
> `[MEASURED 2026-09-02: sqlite3 CLI 3.51.0 · pdo_sqlite 3.45.2 · PHP 8.4.23]`. `STRICT` needs
> 3.37, so there is headroom, but a future feature must be checked against the driver.
>
> And `STRICT` is worth less than this section claims in one specific place. It constrains
> **storage class, not meaning**: a `TEXT` column under `STRICT` accepts a `T`-form timestamp
> and the string `banana` equally. It contributes nothing to IG-10, which is closed by the
> `strftime` `CHECK` instead (§22.1a).

**When to revisit Postgres — the actual triggers, so nobody has to guess:**

| Trigger | Why it forces the move |
|---|---|
| A **second machine** must write to the same database | The hard boundary. Profile §6: multi-machine writes are not a SQLite workload, and it is the usual reason to migrate — *not* size |
| Sustained **concurrent writers > 1** | The one-writer ceiling. ~105 writes/day in one batch is not close |
| **More than ~5 concurrent human users** | Multi-tenancy (§3) arrives at the same moment, and both retrofits are cheaper together |
| Genuine need for **geospatial** proximity search | R\*Tree can do bounding boxes, but PostGIS is a different class of tool |

None is true today: one agent, one district, one machine.

### 16.3 The 100x checkpoint

Expansion from Kajang to the Klang Valley: ~400,000 properties, ~560,000 sources, ~270 MB total with change-only price history. What changes:

- The working set stops fitting in page cache. `idx_properties_feed` being **partial** matters here — it indexes only active scraped rows, and that is what keeps the hot index resident.
- `count(*)` on `properties` becomes noticeable (profile §10). Cache the number.
- The daily batch grows from ~105 to ~10,500 upserts. Still one transaction, still seconds.
- **Still no partitioning, no sharding, no replicas.** 400k rows is a small table.

---

## 17. Migration plan {#migration}

**Framing: this is not a migration, it is a first deployment that happens to have a corpse to remove.** The live `listings` table holds **0 rows** `[MEASURED @ 2026-08-06]`. There is no backfill, no dual-write, no data at risk. Every step below is cheap *today* and expensive in six months, and that asymmetry is the reason to do it now.

Per the hard constraint, **I do not write migration files.** The DDL below is ready to lift out and apply in the order given.

| # | Change | Lock / duration | Blocks | Abort-safe? | Forward fix |
|---|---|---|---|---|---|
| **M1** | Fix `schema.sql` **before it is ever applied**: drop `AUTOINCREMENT` (§4.1); `price REAL` → `price_cents INTEGER` (§4.2); `price_history.website TEXT` → `property_source_id` FK (§6.6); add `UNIQUE (property_source_id, observed_at)`; add `CHECK` on `advertisements.website` (IG-6); add the lat/lng presence-pair check (§6.2); name every constraint (§9.3); drop the four orphan indexes (§10.3); add `idx_properties_feed` (§9.1); fix the misleading `floor`/`floors` comment (§2.3) | none — edits a file | nothing | **yes** | Edit again. Nothing is deployed |
| **M1b** *(v1.1.0)* | Also in `schema.sql`, before first apply: add the timestamp-format `CHECK` to every instant column (§22.1, IG-10); replace `contacts.phone`/`email`/`ren_number` with `contact_identifiers` (§22.2); rename `status` → `listing_status` and drop `under_offer`/`closed` from its `CHECK` (§22.5); add `content_hash` + `parser_version` to `advertisements` (§22.4); drop `price_per_sqft`, `price_at_scrape_cents`, `properties.created_at` and both `updated_at` columns (§24.3–§24.6). **Amended 2026-09-11:** the timestamp guard is the `strftime` round-trip, not the `GLOB` pattern (§22.1a), and `schema_migrations` is **cut** — Laravel ships its own `migrations` table (§23.1) | none — edits a file | nothing | **yes** | Edit again. Nothing is deployed |
| **M1c** *(2026-09-11, extended 2026-09-12)* | Also in `schema.sql`, before first apply — the ADR set: **delete `properties.acquisition`** and `idx_properties_acq` with it (ADR 0006); rename `contact_properties` → **`property_parties`** (a table rebuild in SQLite, not a rename); `price_cents` → **`price_minor`** plus `currency_code TEXT NOT NULL DEFAULT 'MYR'` with a membership `CHECK` (ADR 0007); create **`mandates`** with `ux_mandates_open` (ADR 0009); create **`locations`** and **`location_postcodes`**, add `properties.location_id`, `properties.postcode` and `properties.location_raw` (ADR 0008); `listing_status` values become `visible`/`hidden` (ADR 0003 amendment); add `deals.mandate_id` and `deals.commission_minor`, `mandates.commission_rate_bp` (ADR 0010). **Added 2026-09-12 — the three items the ADR set left undecided:** rename `property_sources` → **`advertisements`** and `idx_sources_property` → `idx_advertisements_property` (another rebuild, `02-access-patterns.md` §4.3); **delete `properties.last_seen_at`** and `idx_properties_seen` with it, widening `idx_advertisements_property` to `(property_id, last_seen_at)` (§6.2); `deals.commission_split_pct REAL` → **`commission_split_bp INTEGER`** with a `BETWEEN 0 AND 10000` `CHECK` (ADR 0010 amendment) | none — edits a file | nothing | **yes** | Edit again. Nothing is deployed |
| **M2** | Decide and document the `price_history` write policy: **change-only** (§6.6). **v1.1.0 amends:** the first observation for a new source must **always** be written, not only on change — §24.4's cut depends on it | none — a decision | nothing | **yes** | — |
| **M3** | Apply the corrected `schema.sql` to a **fresh** database file. Set `PRAGMA journal_mode=WAL`, `synchronous=NORMAL`, and establish `foreign_keys=ON` + `busy_timeout=5000` as per-connection defaults in application code (IG-7) | exclusive on a new empty file — **milliseconds** | nothing | **yes** — pure expand | Delete the file and redo |
| **M4** | Move the Python path from `pyturso` to stdlib `sqlite3`; adopt `STRICT` tables (§16.2). Update the two tests asserting `turso.IntegrityError` | none | nothing | **yes** | Revert the import |
| **M5** | **Fix the n8n producer.** Rename the 7 mismatched columns (§2.4); emit `facilities` as a JSON array; normalise phones to `60…`; ensure `advertisement_id` is populated and fail the item if it is not (IG-1); split AP-01's `OR` probe into two indexed probes (§10.3) | none — workflow edits | nothing | **yes** | Revert the workflow |
| **M6** | Retarget n8n writes at a **single writer** — either `pw-api` or the V1 tables directly. Verify with a full scrape run against the new schema | none | nothing | **yes** — **this is the last abort-safe moment** | Point n8n back at the V0 table; it still exists |
| **M7** | **`DROP TABLE listings`** | exclusive, **milliseconds** (0 rows) | nothing | ❌ **NO** | None. The V0 table and every workflow path that referenced it are gone |

> ### ⛔ Point of no return: **M7**
> Everything through M6 is reversible by pointing n8n back at `listings`, which still exists and
> still works (badly). M7 removes that fallback. Because the table holds 0 rows the *data* risk is
> nil — the risk is purely that an un-migrated workflow path still targets it and starts failing.
> **Do not run M7 until a full scrape run has completed end-to-end against the V1 tables.**

**Notes on the lock and disk profile (Gate 5a).** Every step here is either a file edit or a `CREATE TABLE` on an empty database. No step rebuilds a populated table, so no step needs the temporary disk headroom that a table rewrite normally demands (the whole table again) or an index build (the finished index again). **That is only true today.** The same M1 changes applied after six months of scraping would each require the 12-step table rebuild (profile §5) — an exclusive lock for the duration, the whole table rewritten, every index, trigger and view recreated by hand, and no online alternative in this engine family. On a 400k-row `properties` table that is a maintenance window; on `price_history` under policy (a) it would be a 2-million-row rewrite. **Doing M1 now converts a future maintenance window into a text edit.**

**Ongoing discipline, once there is data:** one logical change per migration file; never edit an applied migration; forward-fix rather than down-migrate (doctrine §10). And adopt `PRAGMA user_version` as a schema-version marker from M3 — it is free, and its absence is how the V0/V1 divergence in §2.2 stayed invisible.

**Upsert shape for the ingest path (M5/M6)**, replacing the current blind `INSERT`:

```sql
-- Turso Database 0.7.x / stock SQLite 3.37+ — AP-04
INSERT INTO advertisements
       (property_id, website, advertisement_id, listing_url, listed_at,
        price_at_scrape_cents, first_seen_at, last_seen_at)
VALUES (?1, ?2, ?3, ?4, ?5, ?6, datetime('now'), datetime('now'))
    ON CONFLICT (website, advertisement_id) DO UPDATE
   SET last_seen_at          = datetime('now'),
       price_at_scrape_cents = excluded.price_at_scrape_cents,
       listing_url           = excluded.listing_url;
```

This is what makes `advertisements.last_seen_at` meaningful, and therefore what makes the staleness sweep in §7.3 possible. Verified supported on this engine, including `excluded.*` references (§2.7).

> **⚠️ Note 2026-09-12.** This statement is now the **only** writer of liveness anywhere in the
> schema. `properties.last_seen_at` was cut precisely because no equivalent statement ever
> maintained it (`03-entities.md` §6.2). Any future ingest path that stops touching this column
> silently disables the sweep, so it belongs in the same transaction as the row it describes and
> nowhere else.

---

## 18. Query plan assertions {#plan-assertions}

Split by what could actually be measured. Gate 5d forbids presenting an unverified plan as though it were run.

### 18.1 Measured — against the live `listings` table

Run with `tursodb --readonly listings.db "EXPLAIN QUERY PLAN <select>"` on 2026-08-06, engine **Turso 0.7.1**. **Caveat, stated because it changes how much these are worth: the table holds 0 rows and has no `sqlite_stat1`, so these plans show index *eligibility*, not cost-based choices.** A planner with statistics may choose differently. They are still decisive for the two questions that matter — *does an index exist that can serve this at all*, and *does the query shape permit its use*.

| AP | Query | Plan | Verdict |
|---|---|---|---|
| AP-01 | `WHERE advertisement_id = ? OR phone = ?` **(as n8n sends it)** | `× Parse error: no such column: advertisement_id` | ❌ **The live write path does not execute.** §2.4 |
| AP-01 | `WHERE listing_id = ? OR phone = ?` (corrected) | `` `--SCAN listings `` | ❌ Full scan — the `OR` defeats both indexes. §10.3 |
| AP-02 | `WHERE listing_id = ?` | `` `--SEARCH listings USING INDEX sqlite_autoindex_listings_1 (listing_id=?) `` | ✅ Index used |
| AP-02 | `WHERE website = ? AND listing_id = ?` | `` `--SEARCH listings USING INDEX sqlite_autoindex_listings_1 (listing_id=?) `` | ⚠️ Index used, but on `listing_id` only — `website` is a residual filter, confirming the cross-portal collision in §2.5 |
| AP-03 | `WHERE phone = ?` | `` `--SCAN listings `` | ❌ **The people-dedup key has no index on the live table.** V1 fixes this with `UNIQUE (contacts.phone)` |
| AP-05 | `WHERE area = ? AND price <= ? ORDER BY scrapped_date DESC LIMIT 20` | `` |--SCAN listings `` / `` `--USE SORTER FOR ORDER BY `` | ❌ Full scan **and** an unindexed sort. The orphan AP in §10.3 |
| AP-16 | `WHERE contact_status = ? ORDER BY scrapped_date DESC LIMIT 50` | `` |--SCAN listings `` / `` `--USE SORTER FOR ORDER BY `` | ❌ Full scan and sort. Retires with the V0 table |

**Summary of what was measured: of six executable live access patterns, one fails to parse, four full-scan, and one uses an index built on the wrong key.** The V0 schema serves no access pattern correctly.

### 18.2 Unverified — assertions for the V1 schema

The V1 tables exist in **no database on disk**, so these cannot be measured. They are an unchecked checklist for whoever applies §17 — verify each after M3, before M7.

```
Plan command (both engines):  EXPLAIN QUERY PLAN <select>;
Read as:  SEARCH … USING INDEX = good · SCAN = full scan · USE TEMP B-TREE / SORTER FOR ORDER BY = unindexed sort
Run ANALYZE after the first bulk load — without sqlite_stat1 the planner guesses (profile §3).
```

- [ ] **AP-02** — `SELECT property_id FROM advertisements WHERE website=? AND advertisement_id=?` → `SEARCH advertisements USING INDEX sqlite_autoindex_advertisements_1 (website=? AND advertisement_id=?)`; no `SCAN`.
- [ ] **AP-03** — `SELECT id FROM contacts WHERE phone=?` → `SEARCH contacts USING INDEX ... (phone=?)`; no `SCAN`.
- [ ] **AP-04** — the §17 upsert → conflict resolved via the `(website, advertisement_id)` unique index; **no `SCAN advertisements`**.
- [ ] **AP-05** — the keyset query in §9.1 → `SEARCH properties USING INDEX idx_properties_feed (area=? AND listing_type=?)`; **no `SCAN properties`**; **no `USE TEMP B-TREE FOR ORDER BY`** — the index must supply the order. *If a sort node appears, the `first_seen_at DESC` position in the index is wrong; re-check the column order against §9.1.*
- [ ] **AP-06** — `SELECT * FROM follow_up_inbox WHERE bucket='owed_reply' ORDER BY stale_hours DESC` → the inner aggregate uses `idx_interactions_contact`; a `SCAN contacts` on the outer `LEFT JOIN` is **expected and acceptable** (it is a full classification by definition); **no nested-loop join over an unindexed inner relation**.
- [ ] **AP-07** — `SELECT * FROM interactions WHERE contact_id=? ORDER BY occurred_at DESC LIMIT 30` → `SEARCH interactions USING INDEX idx_interactions_contact (contact_id=?)`; **no sort node** — the index is already `DESC`.
- [ ] **AP-08** — `SELECT * FROM property_parties WHERE property_id=?` → `SEARCH ... USING INDEX idx_pp_property`.
- [ ] **AP-09** — `SELECT * FROM property_parties WHERE contact_id=?` → `SEARCH ... USING INDEX sqlite_autoindex_property_parties_1` (the unique key's left prefix). *If this reports `SCAN`, the `idx_pp_contact` drop in §10.3 was wrong — revert it.*
- [ ] **AP-10** — ⚠️ **superseded 2026-09-11.** `idx_properties_acq` no longer exists. The check becomes: the plan leads from `mandates`, not from `properties`. *If `properties` leads, the join was written backwards.*
- [ ] **AP-11** — the §7.3 sweep → `SCAN properties` plus `CORRELATED SCALAR SUBQUERY` showing `SEARCH a USING COVERING INDEX idx_advertisements_property (property_id=? AND last_seen_at>?)`; **no `SCAN advertisements`**. `[MEASURED 2026-09-12: stock SQLite, empty tables — plan reproduced exactly. The index is covering, so the subquery never touches the table]` **Amended 2026-09-11** — the `acquisition` predicate is gone; the purge conditions are checked in the Action, not in this probe. **Amended 2026-09-12** — `properties.last_seen_at` and `idx_properties_seen` are cut, so the probe moves to `advertisements`; the outer `SCAN properties` is expected and is what the `< 5 s` daily budget is set against.
- [ ] **AP-05/AP-08 (Location)** — ⚠️ **added 2026-09-11.** Any subtree filter must report `SEARCH locations USING COVERING INDEX (path>? AND path<?)`. **Bind a real value before reading this plan**: `EXPLAIN QUERY PLAN` reports `SCAN` for `path GLOB ?` purely because nothing is bound, and a bare-`?` plan is not evidence. A plan that reports `SCAN` with a value bound means the prefix was built from a column expression instead of a bound parameter — see ADR 0008.
- [ ] **AP-12** — `SELECT * FROM scrape_runs WHERE website=? ORDER BY started_at DESC LIMIT 10` → `SEARCH ... USING INDEX idx_scrape_runs`; no sort node.
- [ ] **AP-13** — `SELECT price_minor, observed_at FROM price_history WHERE property_id=? ORDER BY observed_at DESC` → `SEARCH ... USING INDEX idx_price_history`; no sort node.
- [ ] **AP-14** — `SELECT id FROM properties WHERE area=? AND bedrooms=? AND size_sqft BETWEEN ? AND ?` → `SEARCH properties USING INDEX idx_properties_dedup (area=? AND bedrooms=? AND size_sqft>? AND size_sqft<?)`.
- [ ] **AP-15** — `SELECT * FROM contacts WHERE name LIKE ?` → with a **prefix** pattern (`'Ahmad%'`), `SEARCH contacts USING INDEX idx_contacts_name`. **With an infix pattern (`'%Ahmad%'`) expect `SCAN` — that is not fixable with a B-tree** and needs FTS5 (§9.2). Confirm which one the UI actually sends before keeping this index.
- [ ] **Cross-cutting** — after each of the four index drops in §10.3, re-run the AP that the dropped index might have been silently serving; confirm no plan regressed from `SEARCH` to `SCAN`.
- [ ] **Cross-cutting** — estimated versus actual rows within an order of magnitude on AP-05 and AP-14. A wide gap means `ANALYZE` has not run or `area` values are inconsistent (IG-3).

---
