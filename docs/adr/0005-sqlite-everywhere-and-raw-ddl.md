# SQLite in dev, CI and production, with migrations written as raw DDL

One engine runs everywhere: a SQLite file in development, the same file shape in CI, and the
same in production. There is no Postgres plan and no second engine in any environment.
Migrations are written as raw DDL in the migration files rather than through Laravel's schema
builder, and database portability is declined rather than preserved.

## Why one engine

The projection is ~6 MB at twelve months and ~270 MB at the 100x checkpoint, with one writer
and one human. Postgres would buy nothing this workload can use and would cost a server, a
backup story, a connection pooler and the property that the database is a file you can copy.
That argument is made in full at `docs/database/06-operations.md` §16.2 and is unchanged.

What is new is refusing to run a *different* engine in development or CI from the one in
production. A schema this dependent on engine-specific behaviour — `STRICT`, partial unique
indexes, `GLOB` index usage, table-level `CHECK` — is only tested if the tests run against the
real thing. CI needs no service container as a result; it inherits the same file database.

## Why raw DDL, and what it costs

An earlier session ruled Blueprint-first for portability. That ruling is reversed. Portability
is only worth paying for if it is exercised, and with one engine everywhere it never is.

More decisively, the schema's load-bearing constraints are the ones Blueprint cannot express.
`STRICT` on the table, table-level `CHECK` constraints, partial **unique** indexes, `GENERATED
ALWAYS AS … VIRTUAL` columns and `json_valid` guards all have to be reached through raw
statements anyway. A migration that is half builder calls and half raw strings is harder to
read than one that is entirely raw, and it invites a future contributor to "tidy up" a raw
statement into a builder call that silently drops the constraint.

**The cost, stated plainly:** if this project ever moves engines, every migration is rewritten
by hand. The triggers below are what that decision waits for.

## The engine floor, measured

`[MEASURED 2026-09-02: sqlite3 CLI 3.51.0 · pdo_sqlite 3.45.2 · PHP 8.4.23]`

**The floor that matters is 3.45.2, not 3.51.0.** Migrations run through PHP's driver, not the
CLI. `STRICT` requires 3.37 or later, so there is headroom, but a future feature must be
checked against the driver's version and not the shell's.

Verified working through `pdo_sqlite`: `STRICT` tables · table-level `CHECK` · `json_valid`
inside a `STRICT` table · partial indexes · partial **unique** indexes · `GENERATED ALWAYS AS
… VIRTUAL` columns. Evidence: `'450000'` stored as `integer` while `'450000.50'` is rejected
with *cannot store REAL value in INTEGER column*; `CHECK ((lat IS NULL) = (lng IS NULL))`
rejects half a coordinate; a second open mandate on one property is rejected and accepted
again once the first is withdrawn.

## Three traps this ruling makes permanent

**1. A partial index predicate must be deterministic, and it fails at write time rather than
at DDL time.**

```
CREATE UNIQUE INDEX a ON m(property_id) WHERE expires_on > datetime('now');
  → exit 0.  The migration SUCCEEDS.
INSERT INTO m ...
  → Error: stepping, non-deterministic use of datetime() in an index
```

The migration is accepted and every subsequent write fails. This is why the open-mandate index
in ADR 0009 tests only `withdrawn_on IS NULL AND completed_on IS NULL`, and why expiry is
enforced in the Action.

**2. `LIKE` does not use an index; `GLOB` and an explicit range do.** SQLite's `LIKE`
optimisation is off by default because `LIKE` is case-insensitive for ASCII.

```
WHERE path LIKE '/3/%'  →  SCAN   locations USING COVERING INDEX ix_loc_path   (647 µs)
WHERE path GLOB '/3/*'  →  SEARCH locations USING COVERING INDEX (path>? AND path<?)  (24 µs)
```

**3. `CHECK` is immutable.** There is no `ALTER TABLE ADD/DROP CONSTRAINT`. Every check must
live inside the original `CREATE TABLE`, and changing one later is a twelve-step table
rebuild. This is the hidden cost of the enum ruling below.

## Consequence: the enum ruling is temporary and its exit is expensive

`portals`, `locations` and `projects` become real tables because rows in them carry
attributes. The remaining discriminators — `listing_status`, `stage`, `property_role`,
`deal_role`, `listing_type` — stay backed PHP enums with `CHECK` constraints, on the grounds
that none of them has attributes yet.

That is accepted as temporary, and the cost of ending it must be named now rather than
discovered later: **adding or removing one value from any of those `CHECK` lists is a
twelve-step table rebuild, not a column change.** The move to lookup tables, when it comes,
should be done for all of them at once and planned as a migration in its own right.

## When to revisit the engine — as numbers, not as prose

| Trigger | Threshold |
|---|---|
| A second machine must write to the same database | 2 writing machines. The hard boundary — not a size question |
| Sustained concurrent writers | more than 1 |
| Concurrent human users | more than 5 |
| Rows in the largest table | more than 1,000,000 |
| A second application needs direct database access | 1 |
| Genuine geospatial proximity search | any. R\*Tree does bounding boxes; PostGIS is a different class of tool |

None is true today: one agent, one district, one machine. Reaching any one of them reopens
this ADR; reaching none of them does not, however slow something feels.

Reconciles `docs/database/06-operations.md` §16.2, where `STRICT` was a recommendation. It is
now taken.
