# Location is three levels, stored as an adjacency list with a materialised path

Free-text `area` is replaced by a `locations` table with three levels — state, district,
locality — seeded from OpenStreetMap and data.gov.my. Each row stores its `parent_id` as the
truth and a materialised `path` as a rebuildable cache. Mukim is dropped. A separate
`location_postcodes` table exists for the resolver, not for users.

---

## Three levels, and why mukim is not the fourth

Mukim is a land-title concept. No portal emits it, no agent asks for it, and the data to seed
it does not exist in usable form.

`[MEASURED 2026-09-07: live Overpass, all relations inside ISO3166-1=MY]`

| `admin_level` | Meaning | Count | Usable? |
|---|---|---|---|
| 4 | negeri / state + federal territory | **16** | yes, complete |
| 5 | bahagian / division (Sarawak) | 19 | not applicable |
| 6 | daerah / district | **158** | yes, complete |
| 7 | mukim | 22 | **no — wrong, not merely sparse** |
| 8 | bandar / town | 31 | **no** |

Level 7 mixes cities (`Petaling Jaya`, `Shah Alam`), *municipal councils* (`Majlis Perbandaran
Kajang`, which is a government body rather than a place) and Sarawak villages (`Bario`,
`Spaoh`, `Debak`). Level 8 contains actual mukims (`Mukim 16`, `Mukim Parit Buntar`), a Kuala
Lumpur neighbourhood (`Brickfields`) and three islands. Neither level is a hierarchy tier; both
are a mixed bag with a number on it. Selangor's nine districts at level 6 are correct and
complete, with `name:ms`.

Level 3, the locality, is therefore the marketing level — what an agent and a buyer both call
the place. It is seeded from data.gov.my poskod and extended by hand as the portals reveal
localities neither source carries.

## Shape: adjacency list plus a stored materialised path

`parent_id` is the truth. `path` is a cache that can be rebuilt from `parent_id` at any time.
`level` is derivable and is best generated rather than stored.

**`path` is the row's own address — its ancestors' ids plus its own.** `/1/` is Selangor,
`/1/2/` is Hulu Langat within Selangor, `/1/2/7/` is Sungai Long. Every path starts and ends
with `/`. The subtree prefix is therefore `path || '*'` and is never hand-typed; the
self-excluding subtree prefix is `path || '?*'`.

### The reason is composability, not speed

An earlier draft justified this shape on the subtree query being three times faster. That is
true and it is a rounding error: `[MEASURED 2026-09-07: 1,648 locations]` a recursive CTE is
71 µs, `GLOB` on `path` is 24 µs, and a closure table is 15 µs, against a whole-query budget
of 74 µs. Nothing user-visible moves.

**The reason that survives is that a recursive CTE must be hoisted to the top of a statement.**
It cannot be nested inside another query, it cannot appear in a `CHECK`, it cannot appear in an
index expression, and in Eloquent it forces raw SQL every single time a location filter is
involved. `path` makes the filter `->where('path', 'glob', $prefix)`, which nests inside any
other query as an ordinary subexpression. Under the raw-DDL-and-Laravel ruling of ADR 0005,
that is what is actually being bought.

The closure table was also measured and rejected on a different axis: it costs **5,968 rows to
describe 1,648** — 3.6 rows of index per row of data — for a 9 µs gain on a query that runs
well inside budget.

### What `path` in a `CHECK` does and does not buy — a correction

An earlier draft claimed `path` was an ordinary indexed `TEXT` column and so could appear in a
`CHECK` or a partial-index predicate, implying it enabled **hierarchy** constraints. It does
not, and the limit is absolute rather than a question of shape:

```
CREATE INDEX bad ON locations((SELECT 1 FROM locations));
  → Error: in prepare, subqueries prohibited in index expressions
CREATE TABLE t(a INTEGER, CHECK (a IN (SELECT id FROM locations)));
  → Error: in prepare, subqueries prohibited in CHECK constraints
```

A `CHECK` sees one row and no others. *"A locality's parent must be a district"* is not
expressible by **any** shape considered here, this one included. That guard belongs in the
Action.

What `path` in a `CHECK` genuinely buys is a **self-consistency guard** — small, but real. It
catches a botched path rebuild and nothing more:

```sql
CONSTRAINT ck_path_shape CHECK (path GLOB '/*/' AND path NOT GLOB '*//*'),
CONSTRAINT ck_path_depth CHECK (length(path) - length(replace(path,'/','')) = level + 1),
CONSTRAINT ck_root       CHECK ((parent_id IS NULL) = (level = 1))
```

Verified firing: `INSERT INTO locations VALUES (9,2,3,'Broken','/1/9/')` →
`CHECK constraint failed: ck_path_depth`.

`level` can be generated rather than stored, verified working through `pdo_sqlite`:

```sql
lvl INTEGER GENERATED ALWAYS AS (length(path) - length(replace(path,'/','')) - 1) VIRTUAL
```

returning `1|/1/|1`, `2|/1/2/|2`, `7|/1/2/7/|3`.

### Four traps that must survive into the code

**1. A `GLOB` prefix must be a literal or a bound parameter. A column expression loses the
index.** `[MEASURED: sqlite3 3.51.0, 1,648-row locations table]`

```
WHERE path GLOB '/1/2/*'         → SEARCH ... USING COVERING INDEX (path>? AND path<?)
WHERE path GLOB :p   (:p bound)  → SEARCH ... USING COVERING INDEX (path>? AND path<?)
WHERE path GLOB d.path || '*'    → SCAN   ... USING COVERING INDEX      ← not indexed
```

Build the prefix in PHP from the stored `path` and bind it. **Do not write the subtree query as
a self-join on `locations`.**

**2. `EXPLAIN QUERY PLAN` with an unbound `?` lies about `GLOB`.** The CLI reports `SCAN` for
`path GLOB ?` purely because no value is bound at explain time. Bind one with `.parameter set
:p '/1/2/*'` and the same statement reports `SEARCH`. Any future verification of this must bind
a value first — a bare-`?` plan is not evidence. This nearly caused trap 1 to be recorded
backwards.

**3. `LIKE` reports `SCAN` under every condition** — bound or literal, leading wildcard or none.
No path-prefix query may use it.

**4. The trailing slash is load-bearing.** `/1/2` prefix-matches `/1/23`:

```
WHERE path GLOB '/1/2*'   → Hulu Langat, Sungai Long, AND Petaling (/1/23/), Bandar Sunway
WHERE path GLOB '/1/2/*'  → Hulu Langat, Sungai Long.  Correct.
```

`ck_path_shape` is the mitigation, and the prefix is built by one helper rather than typed at
each call site.

---

## Seeding, and the two sources that do not join by name

**States and districts come from OSM `admin_level` 4 and 6** — complete, correct, and carrying
geometry. **Localities come from data.gov.my poskod**, trimmed and deduplicated. Roughly 674
rows in total.

The poskod file carries the exact defect this table exists to fix: `Bestari Jaya` and `Bestari
Jaya ` (trailing space) are separate rows, and it reports **17 distinct states** because
`Negeri Sembilan` appears twice, once with trailing spaces.

**The two sources do not join by name, and this is not a data-cleaning problem.** Of Selangor's
nine OSM districts only four appear at all as poskod cities, and those are coincidences —
`Klang` is both a district and a town, while the district `Petaling` is not the town `Petaling
Jaya`. They sit at *different levels*. They must be joined **geographically**: point-in-polygon
against the OSM district boundaries, or one Nominatim call per locality.

**Nominatim is a bridge, never an oracle.** A real query for `Sungai Long, Kajang, Selangor`
returned `district: Hulu Langat` correctly, but `city: Majlis Perbandaran Kajang` — the council
rather than the town — and matched a **river**, because Sungai Long is both. Strong input,
reviewed by hand, never unsupervised. The public instance is one request per second, which is
fine for a ~500-row seed and unusable for per-scrape lookups.

**Attribution is a licence obligation, not a courtesy.** ODbL for OSM and CC BY 4.0 for
data.gov.my both require it, and it is recorded in the seeder file itself so it cannot be lost
when the data is copied.

### The resolver may propose a locality; it may never create one silently

Portals emit real marketing localities that neither source carries — "Sunway Velocity", "KL Eco
City". Free text that does not resolve goes to a quarantine with a count. **The top of that
list, sorted by count, is the genuine level-3 backlog**, and it is the only honest way to
discover which localities matter.

`properties.location_raw TEXT` is retained so a quarantined row re-resolves without a
re-scrape. That is the whole reason the raw string is kept.

---

## Postcode: a resolver input, not a user-facing filter

`[MEASURED 2026-09-11: data.gov.my poskod, CC BY 4.0]`

| | |
|---|---|
| rows | 2,932 |
| distinct postcodes | 2,930 |
| postcodes mapping to more than one city | 2 |
| of those, genuine | **1** |

One of the two is dirt rather than geography — `Negeri Sembilan,Port Dickson,71000` and
`Negeri Sembilan  ,Port Dickson,71000`, differing by trailing spaces. Trimming removes it. The
one genuine many-to-many case is `40160`, which is both Sungai Buloh and Shah Alam.

The reverse direction is heavily one-to-many: Kuala Lumpur has 273 postcodes, Kota Kinabalu
208, Kuching 125, Kuala Terengganu 119, Ipoh 106.

**A bare `properties.postcode` column was recommended first and the recommendation was
reversed, because it named the wrong consumer.** Buyers do search by name and never by
postcode — that part was right. But the consumer that needs postcode is **the resolver**. A
scraped address string such as `"Jalan SS15/4, Subang Jaya, 47500 Selangor"` has exactly one
machine-readable token in it, and the poskod file itself proves every other part is dirty.

**The bound, stated honestly:** at 273 postcodes for Kuala Lumpur, a KL postcode confirms *KL*
and narrows nothing below it. Postcode disambiguates state and district. It will never identify
a level-3 marketing locality such as "KL Eco City".

```sql
-- resolver lookup, seeded from poskod (~2,931 rows after trimming). Never user-facing.
CREATE TABLE location_postcodes (
  location_id INTEGER NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
  postcode    TEXT NOT NULL CHECK (length(postcode) = 5 AND postcode GLOB '[0-9][0-9][0-9][0-9][0-9]'),
  PRIMARY KEY (location_id, postcode)
) STRICT;
CREATE INDEX ix_loc_postcode ON location_postcodes(postcode);
```

Plus `properties.postcode TEXT`, holding the raw scraped token and retained even when it
resolves to nothing — the same reason `location_raw` is retained.

The junction costs no design work, because **the source file *is* the junction**: one row per
(locality, postcode) pair. What would have cost work is inventing a `postcodes` table with a
single `location_id`, which `40160` breaks on day one.

---

## Deferred: denormalised `district_id` on `properties`

Feed browse filters by district on nearly every request. Under this shape that filter is a
subquery — `location_id IN (SELECT id FROM locations WHERE path GLOB :prefix)` — with the
prefix bound from the district's stored `path`.

The optimisation is to store `district_id` on `properties` alongside `location_id`, making the
filter one equality against a covering index and removing the subquery entirely.

**Not taken, and the reason is measured rather than stylistic.** `[MEASURED 2026-09-07: 1,648
locations, 4,000 properties]` the subtree scan is 24 µs against a 74 µs whole-query budget.
Removing it cannot move a page load.

**The cost it would carry.** `district_id` is derivable from `location_id`, so it is the same
defect class as `properties.acquisition` (ADR 0006) and `properties.last_seen_at` (cut
2026-09-12): a second
copy of a fact with no event guaranteed to maintain it. Reparent a locality, or correct a bad
resolution, and every property under it is silently wrong. It would need a maintaining Action
and a test, and neither is free.

**Revisit trigger, as a number.** Take it when the feed query exceeds 10 ms at p95 *and* a query
plan names the `locations` subquery as the cost. Not before, and not on intuition.

---

## Rejected alternatives

### Other hierarchy shapes

| Shape | Verdict |
|---|---|
| **Nested sets** (Celko, `lft`/`rgt`) | Subtree is one range scan, but any insert rewrites roughly half the tree. Built for read-only hierarchies. Rejected |
| **Nested intervals** (rational numbers) | Fixes the insert cost with fractions; needs `REAL` arithmetic and loses precision with depth. Overkill for three levels |
| **One table per level** (`states`, `districts`, `localities`) | Joins are not the problem at this size. **The level count becomes schema** — a fourth level means a new table and new code in every query. Rejected |
| **Native path types** (`ltree`, `hierarchyid`) | ADR 0005 removed the option; SQLite has neither |
| **Denormalised keys on the fact row** | Not a rival, a companion. Documented and deferred above |
| **Pure geospatial, no hierarchy** (point-in-polygon, R\*Tree / SpatiaLite) | The honest alternative. Rejected because agents search by *name*, and a large share of scraped rows carry no coordinate at all |
| **Bit-packed fixed-width path** | A variant of the chosen shape; saves bytes, unreadable. No |

The axis is **not** read-easy versus write-hard, which an earlier draft implied. An adjacency
list and a materialised path cost the same for "children of X" — an equality on `parent_id`.
They differ on **unbounded-depth traversal**, where the path wins, versus **subtree moves**,
where the plain adjacency list wins and where a district is reparented approximately never.

### Commercial geocoders

**Google Maps is licence-blocked for this use, not merely expensive.** The Maps APIs Terms
limit storage of Content to *"temporary (and in no event more than 30 calendar days)"*, forbid
using Content without a corresponding Google map, and forbid displaying Content alongside a
non-Google map. A seeded Location table is permanent storage of geocoding Content — the
prohibited case rather than a grey area. Place IDs are the documented exception, but they are
opaque handles rather than a hierarchy, so they cannot seed anything.
*Re-verify the current revision of those terms before citing clause numbers anywhere.*

**Mapbox is usable but must be paid for.** Temporary geocoding is the default and forbids
storing results in a database; `permanent=true` permits indefinite storage and requires a card
on file or an enterprise contract. It buys nothing over OSM plus Nominatim here.

**MapLibre is a renderer, not a data source** — no geocoder, no place database. It cannot seed
anything. It is the natural *display* pairing with OSM data, which is a different decision.

---

Amends the **Location** entry in `apps/web/CONTEXT.md`, which named four levels including
mukim. Cross-referenced from `docs/database/02-access-patterns.md` §3.
