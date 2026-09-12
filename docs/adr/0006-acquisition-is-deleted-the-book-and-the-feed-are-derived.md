# `properties.acquisition` is deleted; the book and the feed are derived

`properties.acquisition` carried `own_mandate` or `scraped` and was the column that separated
the agent's book from the scraped feed. It is deleted. Whether a Property is in the book is
answered by whether an open Mandate row exists for it; whether it is in the feed is answered
by whether an Advertisement row exists for it. Both, neither, and each alone are all
expressible, and none of them needs a column.

## The demonstration, which is shorter than the argument

Two schemas were built side by side and loaded with the same four properties: one purely
scraped, one purely a mandate, one held under mandate *and* self-advertised on PropertyGuru by
the agent, and one scraped and later won. **With correct data the two schemas agree on every
query.**

Then withdraw one mandate. That is one statement — `UPDATE mandates SET withdrawn_on = …` —
and nothing else is touched. It is also exactly what an agent does when an owner pulls a unit.

Version A, the one with `acquisition`, is now **wrong in both directions from that single
write**: the withdrawn unit is still in the book, because `acquisition` still says
`own_mandate`, and it is missing from the feed, because `acquisition` says it is not scraped.
Version B is correct in both, with no second write.

`[MEASURED 2026-09-11: the comparison database and its sources were built and run; see the
session scratch artifacts `q9.db`, `q9.sql` and `q9data.sql`]`

## The argument the demonstration sharpens

`acquisition` is not wrong because it is denormalised. Denormalisation is a legitimate move
and this document takes it elsewhere. It is wrong because **no event maintains it.**

A withdrawal is a date on the Mandate — a fact the agent records anyway, because they need to
know when the instruction ended. Under Version A that same withdrawal additionally requires a
remembered `UPDATE` on a different table, performed by a human who has already finished the
task from their point of view. Every skipped one is silent. There is no error, no constraint
violation and no report that disagrees.

The structural version of the same point: `acquisition` is a **one-bit lossy summary of two
orthogonal tables**, welded into an either/or that reality routinely breaks. An open `mandates`
row computes `own_mandate`; an `advertisements` row computes `scraped`; neither is computable
in reverse. And the both-case is not exotic — the agent wins a mandate and then advertises it
on PropertyGuru themselves, which is a Wednesday.

## The provenance objection, which does not hold

The column was challenged on the grounds that provenance is leaking into the schema. That
reason is wrong and is recorded here so it is not re-argued: provenance *is* data here. It
drives retention, it drives which portal to refresh from, and it is why `advertisements` exists
at all. The column goes for the maintenance reason above, not for a purity reason.

## What replaces each use

| Was | Becomes |
|---|---|
| AP-10, the mandate board — `acquisition='own_mandate' AND status=?` | Read from `mandates` and join out to `properties`. Faster, because the small table leads. `idx_properties_acq` is deleted and not replaced |
| AP-05, the feed browse — `acquisition='scraped' AND …` | `NOT EXISTS` against `ux_mandates_open`. `[MEASURED: 4,000 properties / 12 mandates — SEARCH p USING COVERING INDEX ix_feed + SEARCH m USING COVERING INDEX ux_mandates_open, 74 µs]` |
| The feed partial index predicate | Shortens to `WHERE listing_status = 'active'` |
| The 90-day purge — `acquisition='scraped' AND last_seen_at < …` | Rewritten as *no mandate, no deal, no interactions, no property-party links, and every advertisement stale*. See below |

## Consequences

**The purge becomes expressible, and it was a data-loss path before.** Every foreign key into
`properties` is `ON DELETE CASCADE` or `SET NULL`, so the old rule hard-deleted a scraped
property the agent had actually worked — interactions logged, an owner link recorded — and took
that work with it, silently, at ninety days. The replacement rule was run against the
comparison database and returns zero rows for the worked property. Version A hard-deleted it
whenever the manual `UPDATE` had been missed, which is the same failure as above wearing a
different hat.

**ADR 0001 survives and is amended rather than superseded.** Its claim was one Property table
rather than two, and that claim is unchanged and now *better* supported: converting a scraped
unit to an own mandate is one `INSERT` into `mandates` with no `UPDATE` at all, and
`first_seen_at` is never touched. What does not survive is the mechanism 0001 named. A future
reader finds the discriminator defended in prose at `docs/database/07-decisions.md` §19 item 3
and needs to arrive here.

**One column of the same class remains and is not ruled on here.**
**[Settled 2026-09-12: the column is cut. See `../database/03-entities.md` §6.2.]**
`properties.last_seen_at` is provably `MAX(advertisements.last_seen_at)` — a second copy of a
fact with no event guaranteed to maintain it, which is precisely why
`docs/database/08-review-v1.1.md` §24.5 already cut `properties.created_at`. It is recorded at
`docs/database/03-entities.md` §6.2 as an open defect rather than decided here.
