# Access patterns & conventions

*Part of [Database Schema](../DATABASE_SCHEMA.md) — §3–§4. Chapter files are authoritative; the root index only summarises.*

---

## 3. Access patterns {#access-patterns}

IDs are permanent (Gate 4). `[E]` = evidenced by a real query in the repo or the n8n workflows; `[D]` = design intent inferred from the schema's own indexes and comments, not yet written anywhere.

| ID | Pattern | Predicates | Sort | Scanned→Returned | Frequency | Target | Provenance |
|---|---|---|---|---|---|---|---|
| **AP-01** | Before inserting a scraped listing, check whether we already know this ad *or* this person `[E]` | `advertisement_id = ? OR phone = ?` | — | full table → 0-2 | ~105/day | p99 < 50 ms | `[ESTIMATED: 35 ads/page × 3 portals × 1 run/day; page size from mudah `__NEXT_DATA__` extractor]` |
| **AP-02** | Resolve a portal ad to its property row `[E]` | `website = ? AND advertisement_id = ?` | — | ~1 → 1 | ~105/day | p99 < 10 ms | `[ESTIMATED: one probe per scraped listing, same basis as AP-01]` |
| **AP-03** | Resolve a person by normalised phone (the dedup key) `[E]` | `phone = ?` | — | ~1 → 1 | ~105/day | p99 < 10 ms | `[E: tests/test_schema.py::_contact; n8n node 22]` |
| **AP-04** | Insert or refresh one scraped listing `[E]` | write | — | — | ~105/day | p99 < 100 ms | `[ESTIMATED: as AP-01]` |
| **AP-05** | Browse the feed: rent listings in an area under a price ceiling, newest first, 20/page `[D]` | **⚠️ AMENDED 2026-09-11:** `listing_status='visible' AND location_id IN (SELECT id FROM locations WHERE path GLOB :prefix) AND listing_type=? AND price_minor<=?` **AND `NOT EXISTS` against `ux_mandates_open`** `[MEASURED 2026-09-02: 74 µs]`. Was `acquisition='scraped' AND status='active' AND area=? AND listing_type=? AND price<=?` | `first_seen_at DESC, id DESC` | ~2,000 → 20 | ~30/day | p99 < 100 ms | `[ASSUMED: the agent browses their own feed a few dozen times a day. If this becomes a public web surface at 5k/day, AP-05 moves from "nice to index" to the hottest path in the system and §9's feed index becomes mandatory rather than recommended]` |
| **AP-06** | Follow-up inbox: who is owed a reply, who has gone quiet, who was never contacted — ordered by staleness `[E]` | `bucket = ?` over the view | `stale_hours DESC` | all contacts ⋈ all interactions → ~50 | ~20/day | p99 < 200 ms | `[E: tests/test_schema.py::test_owed_reply_ordering_is_by_staleness]` |
| **AP-07** | One contact's timeline, newest first `[D]` | `contact_id = ?` | `occurred_at DESC` | ~30 → 30 | ~40/day | p99 < 20 ms | `[D: idx_interactions_contact(contact_id, occurred_at DESC) exists for this]` |
| **AP-08** | Everyone attached to a property, with their role `[E]` | `property_id = ?` | — | ~3 → 3 | ~20/day | p99 < 20 ms | `[D: idx_pp_property]` |
| **AP-09** | Every property a contact is attached to, with their role `[E]` | `contact_id = ?` | — | ~3 → 3 | ~30/day | p99 < 20 ms | `[E: tests/test_schema.py::test_role_lives_on_the_relationship_not_the_person]` |
| **AP-10** | The mandate board: my own listings by status `[D]` | **⚠️ AMENDED 2026-09-11:** read from `mandates` and join out to `properties`. Was `acquisition='own_mandate' AND status = ?` | `updated_at DESC` | ~10 → ~10 | ~30/day | p99 < 20 ms | `[D: ~~idx_properties_acq~~ deleted. Faster now — the small table leads. See ADR 0006]` |
| **AP-11** | Staleness sweep: listings with no fresh Advertisement `[D]` | **⚠️ AMENDED 2026-09-11:** staleness is a fact about Advertisements, not about the discriminator. Was `acquisition='scraped' AND last_seen_at < ?`. **Amended again 2026-09-12:** `NOT EXISTS (advertisements a WHERE a.property_id = properties.id AND a.last_seen_at >= ?)` | — | ~4,000 → ~150 | 1/day | < 5 s | `[D: ~~idx_properties_seen~~ deleted with the column. Probes idx_advertisements_property(property_id, last_seen_at), which the FK already required. No code performs this sweep yet — see OQ-4]` |
| **AP-12** | Scrape health: recent runs per portal `[D]` | `website = ?` | `started_at DESC` | ~365 → 10 | ~3/day | p99 < 20 ms | `[D: idx_scrape_runs(website, started_at DESC)]` |
| **AP-13** | Price trail for one property (**V2**) `[D]` | `property_id = ?` | `observed_at DESC` | ~12 → 12 | 0/day today | p99 < 20 ms | `[D: idx_price_history exists; no reader until V2 — see §19]` |
| **AP-14** | Narrow fuzzy-dedup candidates before doing string work in Python `[D]` | **⚠️ AMENDED 2026-09-11:** `location_id = ? AND bedrooms = ? AND size_sqft BETWEEN ? AND ?` — free-text `area` is replaced by Location (ADR 0008), which also removes IG-3's spelling problem from the dedup key | — | ~4,000 → ~15 | ~105/day | p99 < 50 ms | `[D: idx_properties_dedup(area, bedrooms, size_sqft) exists and its comment says exactly this]` |
| **AP-15** | Find a contact by name (partial match) `[D]` | `name LIKE ?` | `name` | all contacts → ~5 | ~15/day | p99 < 50 ms | `[D: idx_contacts_name exists. See §9 — it will not serve an infix LIKE]` |
| **AP-16** | Outreach queue: listings with a phone and no interaction yet `[E]` | V0: `contact_status = 'Not Contacted'`; V1: AP-06's `never_contacted` bucket | `first_seen_at DESC` | full table → ~50 | ~10/day | p99 < 200 ms | `[E: live column `contact_status NOT NULL DEFAULT 'Not Contacted'`]` |

**Read/write shape.** Overwhelmingly read-heavy by call count, but the writes are the interesting ones: one daily batch of ~105 upserts (AP-04) against a table read interactively all day. Single writer, no contention — the SQLite concurrency ceiling (profile §6) is not remotely in play. The correct optimisation is to wrap the daily batch in **one transaction**: unbatched, each insert is its own fsync and throughput drops by roughly two orders of magnitude (profile §6).

**Transactional boundaries.** Three aggregates must commit atomically, and they are the hard limit on any future sharding:

1. `properties` + its `advertisements` rows + any `price_history` row for the same observation. Splitting these lets a listing exist with no portal identity, or a price with no listing.
2. `contacts` + `property_parties`. A role with a dangling person is meaningless.
3. `scrape_runs` counters + the rows that run produced. Today the counters are written independently, so they can disagree with reality — see IG-5.

**Multi-tenancy: none, and that is a decision, not an omission.** One agent, one database, no tenant key. Retrofitting a tenant key is among the most expensive migrations there is (doctrine §requirements-5), so it is worth naming the trigger: **the first day a second agent's data enters this database.** At that moment `tenant_id` must be added to every table and lead every composite index and unique constraint — including `UNIQUE (website, advertisement_id)`, which would become `UNIQUE (tenant_id, website, advertisement_id)`. Until then, the cost of carrying an always-`1` column exceeds its option value.

> ✅ **RULED 2026-09-11 —** [ADR 0004](../adr/0004-no-multi-tenancy-and-the-three-things-it-is-confused-with.md).
> The tripwire above stands unchanged, with one correction to its wording: the trigger is a
> second **agency's** data, not a second agent's. Two agents inside one agency sharing one book
> is **multi-user**, which is additive — users, roles, one nullable ownership column — and two
> agents from *different* agencies splitting a commission is **co-broke**, which costs nothing
> structural at all. Only the third case reaches the schema. Closes OQ-6.

---

## 4. Conventions {#conventions}

| Decision | Ruling | Why |
|---|---|---|
| **Case & separators** | `snake_case`, lowercase, everywhere | Already the house style in `schema.sql`; no exceptions found |
| **Table names** | plural (`contacts`, `properties`); columns singular. **Amended 2026-09-11: a table is named after what one row *is*, plural** — not after the tables it joins | Consistent in V1. The rule is what separates a good join-table name from a bad one, and it has teeth: see §4.3 |
| **Primary key** | `id INTEGER PRIMARY KEY` — **without `AUTOINCREMENT`** | See §4.1 |
| **Foreign key** | `<singular_table>_id`; every FK gets an explicit `ON DELETE` action and its own index | Profile §3: FK columns are **not** indexed automatically |
| **Instants** | `TEXT`, ISO-8601, **always UTC**, via `datetime('now')` | Profile §2/§10: `datetime('now')` returns UTC; text sorts and compares correctly. Render local (`Asia/Kuala_Lumpur`) at the edge only. **⚠️ SUPERSEDED v1.1.0** — "ISO-8601" and "`datetime('now')`" name two *different* formats, and a column fed both is not sorted at all. See §22.1 |
| **Timestamp suffix** | `_at` for instants, `_on` for dates | V1 complies. The live V0 table's `scrapped_date` / `listing_date` violate it (and misspell it) |
| **Money** | `INTEGER` minor units, suffix `_minor`, with `currency_code` alongside — §4.2 as amended by [ADR 0007](../adr/0007-currency-is-a-column-not-a-table.md) | `REAL` is forbidden for money. `_minor` rather than `_cents`, because the minor unit of MYR is the sen |
| **Booleans** | none exist today. When needed: `INTEGER CHECK (c IN (0,1))`, `NOT NULL`, named as an assertion (`is_active`), never negated | Profile §2 — there is no boolean type |
| **Enumerations** | `TEXT CHECK (c IN (...))`, backed by a PHP enum | Doctrine §4 default: visible in the DDL and cheap to read. Do **not** promote to lookup tables until a value needs attributes. **⚠️ Correction 2026-09-11: "cheap to change" is false in this engine.** There is no `ALTER TABLE ADD/DROP CONSTRAINT`, so adding or removing one value from any of these lists is a twelve-step table rebuild. `portals`, `locations` and `projects` are already real tables because their rows carry attributes; the five that remain — `listing_status`, `stage`, `property_role`, `deal_role`, `listing_type` — should move together, as one planned migration, rather than one at a time. See [ADR 0005](../adr/0005-sqlite-everywhere-and-raw-ddl.md) |
| **Units in names** | carried: `size_sqft`, `price_per_sqft`, `stale_hours` | V1 complies |
| **Constraint naming** | `idx_`, `uq_`, `fk_`, `ck_`, `trg_` + table + columns | V1 names its indexes but relies on *auto-generated* names for every `UNIQUE` and `CHECK` — you cannot drop what you cannot name. See §9.3 |
| **Soft delete** | **Per table. No blanket rule.** See §7.3 | Doctrine §7 |
| **Reserved words** | none in use. `status`, `role`, `source`, `notes`, `summary` are all safe in SQLite | |

### 4.1 Primary key strategy — and why nothing changes yet

**Ruling: keep `INTEGER PRIMARY KEY`. Drop `AUTOINCREMENT`. Do not add a public identifier yet — but name the day it becomes mandatory.**

*Keep the integer.* In SQLite-family engines `INTEGER PRIMARY KEY` **aliases the rowid and costs zero extra storage** (profile §9). It is already 64-bit, so the "never use a 32-bit key" rule is satisfied for free — no overflow risk at any volume this project will see. It gives perfect insert locality, the narrowest possible foreign keys, and the cheapest joins.

*Drop `AUTOINCREMENT`.* All seven V1 tables declare it. The profile's forbidden list (§11) is explicit: *"never propose `AUTOINCREMENT` reflexively — plain `INTEGER PRIMARY KEY` is faster."* It buys exactly one guarantee — ids are never reused after deletion — and costs a `sqlite_sequence` write on **every single insert**. On this engine it costs more than that: it materialises a whole extra table, visible in the live file as `__turso_internal_seq___turso_internal_autoincrement_listings` `[MEASURED: .tables @ 2026-08-06]`. Nothing in this system depends on id non-reuse. Rows are deleted (expired scrape rows) and their ids may be reused with no consequence, because nothing external ever saw them — which is precisely the next point.

*No `public_id`, yet.* Doctrine's two-key pattern (internal `id` + external UUIDv7/NanoID) exists to stop enumeration leaking your volume. **Nothing is externally exposed today.** `src/pw/api/` is empty `[MEASURED: 0 bytes @ 2026-08-06]`; there is no HTTP surface, no shared link, no public listing page. Adding 16 bytes and a unique index per row to defend against an attacker who has no endpoint to enumerate is paying a real write tax for a hypothetical.

The counter-argument deserves to be stated rather than waved away: retrofitting `public_id` **after** external links exist is the expensive version, because every already-shared URL must keep resolving. That is true, and it is why this is a *tripwire*, not a "never":

> **Trigger:** the first time `pw-api` returns a row identifier to anything outside this machine — a browser, a WhatsApp deep link, a shared listing page — `public_id TEXT NOT NULL UNIQUE` (UUIDv7, stored as 26-char text or 16-byte BLOB) ships **in the same release**, not after it.

Storing UUIDs as text is normally forbidden (2.25x the bytes in every index). Here the profile (§2) explicitly permits `TEXT` when human-readability of the file matters more than size, and at ~4,000 rows the difference is 40 KB. If volume reaches the 100x checkpoint, use `BLOB`.

*Why not the natural key?* `advertisement_id` is tempting — it is unique per portal and arrives with the data. Reject it: it is a **foreign** identifier we do not control, it collides across portals (§2.5), it is `NULL` in practice today (§2.4), and doctrine §3 is unambiguous that "permanent" reference numbers change. It belongs in a `UNIQUE` constraint, never in a primary key.

### 4.2 Money — an open defect, deliberately not "fixed" here

`properties.price`, `price_per_sqft`, and `price_history.price` are all `REAL`. The profile's forbidden list (§11) opens with *"never propose `REAL` for money"*, and doctrine §4 is equally blunt. IEEE-754 rounding loss on money is not theoretical.

The honest counter-argument, which is why this is a recommendation and not an emergency: Malaysian rental and sale prices are whole ringgit (`RM 450`, `RM 480,000`), and a `REAL` represents every integer up to 2^53 exactly. Today nothing sums, averages, or computes commission on these values — no code reads them at all. The loss materialises the moment someone computes a 2% commission or a price-per-sqft delta and stores the result.

**Ruling: store `price_cents INTEGER` (sen).** `price_per_sqft` may stay `REAL` — it is a derived display metric, never a payable amount, and doctrine's rule is about money, not about ratios. Because the tables are empty this is a `CREATE TABLE` today and a 12-step table rebuild (profile §5) in six months.

An amount without a currency is not a value (doctrine §4). Every price here is MYR. Rather than carry a constant `currency_code` column on every row, that fact is recorded here and enforced by a check: if a second currency ever appears, the column gets added then. Logged as OQ-5.

> ⚠️ **SUPERSEDED 2026-09-11 on both points —** [ADR 0007](../adr/0007-currency-is-a-column-not-a-table.md).
> The column **is** carried, because the cost of adding it later is not the column: it is that
> every amount already stored becomes retroactively ambiguous and no migration can tell you
> which rows were which. And the column is `price_minor`, not `price_cents` — the minor unit of
> MYR is the sen, and a column named `_cents` is a lie the moment a currency with a different
> exponent appears. Closes OQ-5.

---

### 4.3 Table names — a table is named after what one row *is* {#naming-rule}

The rule: **name a table after what one row of it is, in the plural.** Not after the two tables
it joins, and not after the medium or the category it belongs to.

It is a one-line rule with a sharp edge, and applying it retroactively found a wrong name:

| Name | One row is | Verdict |
|---|---|---|
| `interactions` | one touch | passes |
| `contact_identifiers` | one identifier | passes |
| `deal_parties` | one person in one role on one deal | passes |
| ~~`contact_properties`~~ → **`property_parties`** | one person in one role against one unit | **failed.** Renamed 2026-09-11 — the old name described the join, not the row. Structurally identical to `deal_parties`, so it takes the same shape of name |
| ~~`property_sources`~~ → **`advertisements`** | one appearance of one unit on one portal | **failed.** Renamed 2026-09-12 — the old name described the category the row belonged to, not the row. See the ruling below |
| `contact_channels` | *a channel is a medium, not a row* | would fail. The medium is `interactions.channel`, a column |

> ✅ **Ruled 2026-09-12 — `property_sources` becomes `advertisements`.** Raised on 2026-09-11 and
> left open; closed here. One row of it is one Advertisement, which is the glossary's own word —
> `apps/web/CONTEXT.md` defines **Advertisement** and lists *"property source"* under `_Avoid_`.
>
> The decision was forced by cost asymmetry rather than by taste. The 2026-09-11 ADR set already
> says `advertisements` throughout, so the chapters and the ADRs disagreed on one table name.
> Moving the chapters to the ADRs is a find-and-replace; moving seven ruled ADRs plus the glossary
> to the chapters is a rewrite of decisions already argued. The table also holds **zero rows in
> every environment** — `schema.sql` is deployed nowhere — so the rename costs a text edit today
> and a table rebuild at any later date.
>
> **Applied in the chapters and the ADRs. Not applied to `schema.sql`**, which is the input to
> **M1c** and is still contradicted by ADRs 0006–0010 on every other point; renaming one table
> there in isolation would leave a file matching neither design. M1c carries it — see
> [`06-operations.md` §17](06-operations.md#migration).
>
> ⚠️ **One consequence is deliberately left open.** `price_history.property_source_id`, the
> foreign key proposed at [`03-entities.md` §6.6](03-entities.md#e-price-history), now names a
> table that no longer exists. It cannot simply become `advertisement_id`, because
> `advertisements.advertisement_id` already means something else — the portal's own opaque string,
> not a row id — and two adjacent columns of that name on either side of a join is a trap. The
> clean fix renames the opaque column as well, which belongs with the `portal_id` work in
> [`08-review-v1.1.md` §23.1](08-review-v1.1.md#tier-0). **Decide the two together, before M1c.**
> Neither column exists yet, so nothing is at risk in the meantime.

**`deal_roles` is deliberately reserved and must stay unused.** When the enum ruling above is
reversed and the discriminators become lookup tables, `deal_roles` is the lookup table of roles
— one row is one role. Naming the *join* table `deal_roles` would consume the name the lookup
table needs, and that is exactly the mistake `contact_properties` made in the other direction.

---

### 4.4 Deferred: a denormalised `district_id` on `properties` {#deferred-district-id}

Feed browse filters by district on nearly every request, and under
[ADR 0008](../adr/0008-location-is-three-levels-with-a-materialised-path.md) that filter is a
subquery against `locations`. Storing `district_id` on `properties` would make it one equality
against a covering index.

**Not taken.** `[MEASURED 2026-09-07: 1,648 locations, 4,000 properties]` the subtree scan is
24 µs against a 74 µs whole-query budget, so removing it cannot move a page load — and
`district_id` is derivable from `location_id`, which makes it the same defect class as
`properties.acquisition` and `properties.last_seen_at`: a second copy of a fact with no event
guaranteed to maintain it. Both of those were deleted on that reasoning — `acquisition` by
ADR 0006, `last_seen_at` on 2026-09-12 (`03-entities.md` §6.2) — so this paragraph is now the
standing argument against the class rather than a comparison with surviving examples.

**Revisit trigger, as a number:** the feed query exceeds 10 ms at p95 **and** a query plan names
the `locations` subquery as the cost. The full argument, including what it would cost to
maintain, is in ADR 0008 under *Deferred optimisation*.

---
