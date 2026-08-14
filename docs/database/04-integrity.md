# Integrity & indexing

*Part of [Database Schema](../DATABASE_SCHEMA.md) — §8–§10. Chapter files are authoritative; the root index only summarises.*

---

## 8. Integrity gaps {#integrity-gaps}

Invariants the engine cannot enforce, or does not currently.

| ID | Invariant | Why the DDL cannot hold it | Enforced instead at | Risk if bypassed |
|---|---|---|---|---|
| **IG-1** | Every scraped listing has a portal advertisement id | `advertisement_id` is `NOT NULL` in V1, which is correct — but the producer currently binds `NULL` (§2.4). In V0's `listing_id BIGINT UNIQUE NOT NULL`, SQLite treats `NULL`s as **distinct** in a unique index, so a nullable variant would admit unlimited identity-less duplicates | The scraper's extractor must fail the item, not emit `null` | Unbounded duplicate rows that no dedup query can collapse — the exact failure the whole `property_sources` design exists to prevent |
| **IG-2** | Phones are E.164-normalised digits; emails lowercased | SQLite has no `CHECK` that can express "is a valid Malaysian mobile" cheaply, and normalisation is inherently a transform, not a predicate. A partial guard **is** expressible and should be added: `CHECK (phone IS NULL OR (phone GLOB '6[0-9]*' AND length(phone) BETWEEN 10 AND 13))` | Python, before insert — the `schema.sql` header already declares this contract | **A unique index over unnormalised input is decoration** (doctrine §4). `0162339069` and `60162339069` are the same person and two rows. Deduplication silently stops working, which is the single most valuable thing this database does |
| **IG-3** | `area` values are a controlled vocabulary | Free-text `TEXT`. "Kajang", "kajang", "Selangor - Kajang" and "Kajang, Selangor" are four different areas to an index. The live pinned payload contains `"Selangor - Kajang"` in `full_address` and nothing in `area` | Python normalisation, then a `CHECK` list or a lookup table once the vocabulary is known | AP-05 and AP-14 both lead with `area`. If it is inconsistent, the feed index and the dedup index are both partially blind — queries return subsets and nobody notices |
| **IG-4** | `updated_at` reflects the last write | The baseline mechanism is a trigger (doctrine §8), and **triggers are experimental on this engine** (§2.7). `DEFAULT datetime('now')` fires on insert only | Every application write path must set it explicitly | `updated_at` silently equals `created_at` forever — losing the cheapest debugging column that exists (doctrine §13). This is the concrete cost of the engine choice in §16 |
| **IG-5** | `scrape_runs` counters equal the rows the run produced | No `scrape_run_id` on `property_sources`, so there is nothing to count against | Nothing today | A computed value with no maintenance mechanism (doctrine §13). Scrape health metrics drift from reality undetectably — you learn the scraper broke by noticing the feed is stale, not from the dashboard |
| **IG-6** | `website` is one of four known portals | `property_sources.website` has **no `CHECK`**, unlike every other enumerated column in the schema. An oversight rather than a decision — it is trivially expressible | — | `'mudah'`, `'Mudah'`, `'mudah.my'` become three portals. Breaks the `UNIQUE (website, advertisement_id)` dedup key, which is the whole point of the table. **Add the `CHECK`** — it is one line and costs nothing |
| **IG-7** | Foreign keys are actually enforced | `PRAGMA foreign_keys = ON` **defaults to OFF and must be set on every connection** (profile §4/§10 — "the single most common SQLite data-integrity failure"). `schema.sql` sets it at the top of the *script*, which covers the connection that applies the schema and **no other**. The n8n path opens a fresh HTTP connection per request and never sets it | Every connection, explicitly, in application code | Every `ON DELETE CASCADE` and `SET NULL` in §7.1 silently does nothing. Orphan rows accumulate and the schema's referential guarantees are fiction. **This is the highest-severity item in this table** |
| **IG-8** | No two properties are the same real-world unit | Genuine fuzzy matching — address strings, size tolerance, coordinate proximity. Not expressible as a constraint in any engine | Python, narrowed by `idx_properties_dedup` (AP-14) | Duplicate units in the feed. Contained, not prevented — which is the correct design; AP-14 exists precisely to make the Python step cheap |
| **IG-9** | Overlapping-tenancy rules (no two `current_tenant` roles on one unit at once) | Requires an exclusion constraint. **SQLite family has none** (profile §4). Not currently a modelled requirement, but named because check-then-insert in the application is a race condition, always | Serialized write path. The single-writer model makes this materially safer here than on a multi-writer engine | Only relevant if tenancy periods get modelled in V2 |
| **IG-10** *(v1.1.0)* | Every stored instant uses one format | `datetime('now')` emits a space separator and no offset; Python `.isoformat()` and JS `toISOString()` emit `T`. Both are "ISO-8601" by the loose reading §4 used. A `CHECK` **can** pin the shape — `GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]'` — but cannot make a producer emit UTC | Both producers, before insert | `TEXT` compares bytewise and space (`0x20`) sorts below `T` (`0x54`), so a mixed column is not ordered at all: the §7.3 expiry sweep silently never matches T-form rows, and §9.1's keyset pagination skips pages. `julianday()` parses **both**, so every aggregate stays right while the ordering around it is wrong. See §22.1 |

---

## 9. Indexing strategy {#indexing}

### 9.1 The one index that is missing

**AP-05 — browsing the feed — has no serving structure.** `idx_properties_price(listing_type, price)` lacks `area`; `idx_properties_area(area)` lacks price and sort. Neither can serve the composite, so the query scans and then sorts. This is confirmed empirically against the live table, where the equivalent query produces exactly that shape:

```
[MEASURED: tursodb --readonly listings.db "EXPLAIN QUERY PLAN SELECT id, listing_title, price
           FROM listings WHERE area='Kajang' AND price<=1500
           ORDER BY scrapped_date DESC LIMIT 20" @ 2026-08-06]
  QUERY PLAN
  |--SCAN listings
  `--USE SORTER FOR ORDER BY
```

```sql
-- Turso Database 0.7.x / stock SQLite 3.37+
CREATE INDEX idx_properties_feed
    ON properties (area, listing_type, first_seen_at DESC, price_cents)
 WHERE acquisition = 'scraped' AND status = 'active';
```

Column order follows doctrine §6 — **equality predicates first (`area`, `listing_type`), then the sort column (`first_seen_at DESC`), then the range (`price_cents`)**. Putting `price_cents` before `first_seen_at` would still let the index be *used* but would reintroduce the sort, which is the expensive half. The trade-off, stated plainly: with this ordering the price ceiling is a residual filter applied to index entries rather than a seek bound, so a very selective price cap reads more index entries than strictly necessary. That is the right trade here because the sort feeds pagination and the scan is bounded by `LIMIT`.

It is **partial** because every feed query filters on exactly that predicate pair, which is what makes the index roughly ten times smaller and lets it stay resident (doctrine §6). Partial-index support on this engine is verified (§2.7).

Keyset pagination, not offset (doctrine §6 — `OFFSET 100000` reads and discards 100,000 rows every time):

```sql
-- Turso Database 0.7.x / stock SQLite 3.37+ — page N+1 of AP-05
SELECT id, title, price_cents, area, first_seen_at
  FROM properties
 WHERE acquisition = 'scraped' AND status = 'active'
   AND area = ?1 AND listing_type = ?2 AND price_cents <= ?3
   AND (first_seen_at, id) < (?4, ?5)
 ORDER BY first_seen_at DESC, id DESC
 LIMIT 20;
```

### 9.2 Deliberately **not** indexed

Stating these prevents someone adding them "for safety" later (doctrine §13).

| Not indexed | Why |
|---|---|
| `properties.facilities` | Nothing filters on it `[MEASURED: no `WHERE` clause references it anywhere in the repo or workflows @ 2026-08-06]`. An expression index over `json_extract` becomes correct the day "has a pool" is a filter — not before |
| `properties.status` alone | Five values, ~4,000 rows. Doctrine §6: use a partial index instead — which §9.1 does |
| `properties.acquisition` alone | Two values. Already the leading column of `idx_properties_acq` and the partial predicate of the feed index |
| `properties.latitude` / `longitude` | Proximity search is not an access pattern yet. When it is, it needs an **R\*Tree virtual table** (profile §3), not a B-tree on either column — a B-tree on latitude cannot answer "within 2 km" |
| `properties.title`, `summary` | Substring search is not an access pattern. When it is, it needs **FTS5** (profile §3), not a B-tree — `LIKE '%x%'` cannot use an ordered index |
| `interactions.occurred_at` alone | Always queried with `contact_id`, and `idx_interactions_contact(contact_id, occurred_at DESC)` covers it by left prefix |
| `contacts.email` | No access pattern. Would need a `lower(email)` expression index to be useful at all |
| `scrape_runs.status` | Four values, ~1,095 rows. A full scan of this table will always be cheaper than an index probe |
| Everything on `price_history` beyond the two named | Nothing reads this table until V2 (§6.6). Indexes for a reader that does not exist are a pure write tax |

### 9.3 Constraint naming

Every V1 `UNIQUE` and `CHECK` is anonymous — the engine generates the name. Doctrine §2: *you cannot drop what you cannot name*, and the generated name differs between engines and sometimes between versions. Since these are all `CREATE TABLE` recreations anyway (§17), name them at creation: `uq_property_sources_website_ad`, `ck_properties_status`, and so on. Cost: zero. Benefit: the day one needs changing, it is one statement instead of a 12-step rebuild to find out what it was called.

---

## 10. Traceability matrix {#traceability}

### 10.1 Access pattern → serving structure

| AP | Served by | Status |
|---|---|---|
| AP-01 | `UNIQUE(website, advertisement_id)` + `UNIQUE(contacts.phone)` — **but only if split into two probes**; see the orphan analysis below | ⚠️ partial |
| AP-02 | `UNIQUE (property_sources.website, advertisement_id)` | ✅ |
| AP-03 | `UNIQUE (contacts.phone)` | ✅ |
| AP-04 | `UNIQUE (website, advertisement_id)` as the upsert conflict target | ✅ |
| AP-05 | **nothing today** → `idx_properties_feed` (proposed, §9.1) | ❌ **orphan AP** |
| AP-06 | `idx_interactions_contact (contact_id, occurred_at DESC)` for the inner aggregate; the outer `LEFT JOIN` over `contacts` is an unavoidable full scan | ⚠️ partial |
| AP-07 | `idx_interactions_contact` | ✅ |
| AP-08 | `idx_cp_property` | ✅ |
| AP-09 | `UNIQUE (contact_id, property_id, role)` by left prefix | ✅ |
| AP-10 | `idx_properties_acq (acquisition, status)` | ✅ |
| AP-11 | `idx_properties_seen (last_seen_at)` | ✅ |
| AP-12 | `idx_scrape_runs (website, started_at DESC)` | ✅ |
| AP-13 | `idx_price_history (property_id, observed_at DESC)` | ✅ |
| AP-14 | `idx_properties_dedup (area, bedrooms, size_sqft)` | ✅ |
| AP-15 | `idx_contacts_name (name)` — **prefix matches only** | ⚠️ partial |
| AP-16 | AP-06's `never_contacted` bucket (V1); nothing at all in V0 | ⚠️ inherits AP-06 |

### 10.2 Structure → access pattern

| Structure | Serves | Verdict |
|---|---|---|
| `UNIQUE (contacts.phone)` | AP-03, AP-01 | keep — **⚠️ SUPERSEDED v1.1.0**: replaced by `uq_contact_identifiers_kind_value`, serving AP-22 at the same cost (§22.2) |
| `idx_contacts_phone` | — | **DROP — orphan** |
| `idx_contacts_source` | — | **DROP — orphan** |
| `idx_contacts_name` | AP-15 (partial) | keep conditionally |
| `idx_properties_acq` | AP-10 | keep |
| `idx_properties_area` | — | **DROP — orphan (left-prefix redundant)** |
| `idx_properties_price` | AP-05 (insufficient) | **DROP** once `idx_properties_feed` lands |
| `idx_properties_seen` | AP-11 | keep |
| `idx_properties_dedup` | AP-14 | keep |
| `UNIQUE (website, advertisement_id)` | AP-02, AP-04 | keep |
| `idx_sources_property` | AP-08 + FK integrity | keep |
| `UNIQUE (contact_id, property_id, role)` | AP-09 | keep |
| `idx_cp_contact` | — | **DROP — orphan (left-prefix redundant)** |
| `idx_cp_property` | AP-08 + FK integrity | keep |
| `idx_interactions_contact` | AP-06, AP-07 | keep |
| `idx_interactions_property` | FK integrity only | **keep — justified, not orphan** |
| `idx_price_history` | AP-13 | keep |
| `idx_scrape_runs` | AP-12 | keep — **⚠️ SUPERSEDED v1.1.0**: falls with the table if §24.2's cut is taken |
| `sqlite_autoindex_listings_1` (V0, live) | AP-02 (partially — wrong key, §2.5) | dies with the table |

### 10.3 Orphan checks — both reported explicitly

**Orphan access patterns — patterns with no serving structure. Result: THREE found.**

1. **AP-05 (browse the feed) — a genuine missing-index defect.** No index covers `(area, listing_type, price)` with the `first_seen_at` sort. Measured today as `SCAN` + `USE SORTER FOR ORDER BY` (§9.1). **The index that should exist is `idx_properties_feed`, defined in §9.1.** This is the most user-visible gap in the schema: the feed is the thing the agent looks at.

2. **AP-01 (dedup probe) — served by two indexes that the query's own shape prevents it from using.** `WHERE advertisement_id = ? OR phone = ?` is an `OR` across two *different* tables' keys. Measured on the live table:
   ```
   [MEASURED: EXPLAIN QUERY PLAN SELECT * FROM listings
              WHERE listing_id = 1 OR phone = '60123456789' @ 2026-08-06]
     QUERY PLAN
     `--SCAN listings
   ```
   versus the same probe on one key alone:
   ```
   [MEASURED: EXPLAIN QUERY PLAN SELECT * FROM listings WHERE listing_id = 1 @ 2026-08-06]
     QUERY PLAN
     `--SEARCH listings USING INDEX sqlite_autoindex_listings_1 (listing_id=?)
   ```
   The index exists and is perfectly good; the `OR` defeats it. **No index can fix this — the query must change.** Split it into two indexed probes (`UNION`, or two round trips), which is also the semantically correct thing: "have I seen this ad?" and "do I know this person?" are different questions with different answers and different follow-up actions. In V1 they are different *tables*, so the split is forced anyway.

3. **AP-16 (outreach queue) in its V0 form** — `contact_status = 'Not Contacted'` has no index. Measured as `SCAN` + `USE SORTER FOR ORDER BY` (§18). V1 dissolves this pattern into AP-06's `never_contacted` bucket, so **no new index is proposed** — the defect retires with the V0 table.

**Orphan structures — indexes with no access pattern. Result: FOUR found, one near-miss cleared.**

1. **`idx_contacts_phone`** — `contacts.phone` is already `UNIQUE`, and a `UNIQUE` constraint creates its own index. Confirmed on the live database, where `listing_id BIGINT UNIQUE` produced `sqlite_autoindex_listings_1` with no explicit DDL `[MEASURED @ 2026-08-06]`. This is a **pure duplicate** — the same key indexed twice, paying double write tax on every insert and update, forever, for zero read benefit. **Drop.**
2. **`idx_contacts_source`** — four distinct values over ~1,300 rows. Doctrine §6 forbids indexing a low-cardinality column alone; the planner will usually decline it anyway. No AP cites it. **Drop.**
3. **`idx_properties_area`** — left-prefix redundant with `idx_properties_dedup(area, bedrooms, size_sqft)`, which already serves every `area = ?` lookup. Doctrine §6: do not create `(a)` when `(a, b)` exists. **Drop.**
4. **`idx_cp_contact`** — left-prefix redundant with `UNIQUE (contact_id, property_id, role)`, which leads with `contact_id`. **Drop.**

**Cleared on inspection — `idx_interactions_property`.** No access pattern cites it directly, which flags it as a candidate orphan. It is not one: `interactions.property_id` carries `ON DELETE SET NULL`, and profile §3 states foreign key columns are **not** indexed automatically. Without this index every property delete scans the whole `interactions` table while holding a write lock. It silently serves referential integrity, and that is now documented rather than left to be rediscovered by whoever next audits the index list. **Keep.**

**Net effect of the four drops:** four fewer B-tree writes per affected row insert, on a table set where the daily batch is ~105 upserts. Small in absolute terms — but they cost something and return nothing, and the reason to remove them now is that an index nobody can justify is one nobody later dares to drop.

---
