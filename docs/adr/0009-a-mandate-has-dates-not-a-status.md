# A Mandate is an entity with dates, not a status column

The agent's right to market a Property becomes its own table. A Mandate records when it was
granted, when it expires, and — as dates rather than as an enum — when it was withdrawn or
completed. There is no `status` column. At most one Mandate per Property may be open at a
time, enforced by a partial unique index.

## Why dates rather than a status enum

The four states an agent recognises are `open`, `withdrawn`, `expired` and `completed`. Three
of them are already dates the agent records anyway, because they are the facts they need:
`granted_on`, `expires_on`, `withdrawn_on`, `completed_on`. A status enum on top of those dates
is a second copy of a fact with no event guaranteed to maintain it — the same defect that
deleted `properties.acquisition` in ADR 0006, and it would fail the same way.

`expired` sharpens the point, because it is the one state that is not an event at all. It is a
function of `expires_on` and the current time. Storing it means a nightly sweep, and a nightly
sweep means the value is wrong for up to a day and silently wrong forever if the sweep stops.
Derived, it is never wrong.

The status vocabulary survives as **vocabulary** — it is what the agent says and what the
interface shows. It is computed on read, not stored.

## At most one open Mandate per Property

```sql
CREATE UNIQUE INDEX ux_mandates_open ON mandates(property_id)
  WHERE withdrawn_on IS NULL AND completed_on IS NULL;
```

Confirmed working through `pdo_sqlite`: a second open mandate on one property is rejected, and
accepted again once the first is withdrawn.

**Note what the predicate does not mention.** `expires_on` is absent, and that is deliberate
rather than an oversight. A partial index predicate must be deterministic, and `WHERE
expires_on > datetime('now')` is accepted by the migration and then fails **every subsequent
write** with *non-deterministic use of datetime() in an index* — see ADR 0005, trap 1. So the
index enforces "not withdrawn and not completed", and *expiry is enforced in the Action*: an
expired mandate is still an open row, and the Action refuses to treat it as live.

## Consequences

**Conversion from feed to book becomes an insert with no update.** Winning a mandate on a
scraped unit is one `INSERT` into `mandates`. `properties` is not written to at all, so
`first_seen_at` cannot be disturbed. This is the strongest form of the argument ADR 0001 made.

**A withdrawal is one write and it is complete.** `UPDATE mandates SET withdrawn_on = …` is
the whole operation. Nothing else needs remembering, which is exactly what ADR 0006's
demonstration turns on.

**The word `active` now means two different things and must stop.** A Mandate is `open` /
`withdrawn` / `expired` / `completed`; a Property is `visible` / `hidden`. Both vocabularies
previously used `active`, `expired` and `withdrawn` with different meanings. See ADR 0003, now
extended to three lifecycles.

**A Mandate is not a Deal, and one produces many.** A Mandate that expires unsold produced
none; a unit relisted after a failed sale is a second Deal under the same Mandate. The
commission consequence of keeping them separate is ADR 0010.
