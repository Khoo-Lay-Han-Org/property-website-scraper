# The agreed commission rate and the earned commission are separate facts

`mandates.commission_rate_bp` is what the owner agreed to. `deals.commission_minor` is what the
agent actually earned. They are stored separately and neither is derived from the other.
`deals.mandate_id` is a nullable foreign key to the Mandate the Deal was done under, with `ON
DELETE RESTRICT`.

## Why the Deal must name its Mandate explicitly

Commission needs two numbers from two places: the rate from the Mandate and the price from the
Deal. The tempting shortcut is to find the Mandate by date — the one whose term contains the
Deal's completion date — and it picks the wrong row exactly at the boundary, which is exactly
where money is disputed.

The case that breaks it is ordinary, not contrived: a unit is held at 2%, the mandate expires,
the agent wins it back at 2.5%, and the sale completes under the second mandate. A date-range
join has two candidates and no basis to choose between them, and a `completed_on` that lands on
the changeover day picks by accident. **The Deal knows which instruction it was done under.
That knowledge is a fact and it should be stored, not reconstructed.**

`ON DELETE RESTRICT` rather than `CASCADE` or `SET NULL`: a Mandate that has produced a Deal is
not deletable, because deleting it would either destroy the transaction record or silently
detach the rate the commission was computed from.

## Why `mandate_id` is nullable — co-broke

A null `mandate_id` is the co-broke case: the agent acted on a transaction where another
agency held the instruction. There is a real commission and there is no Mandate in this
database to point at. Making the column `NOT NULL` would force a fictional Mandate row to be
invented for every co-broke deal, and that row would then be indistinguishable from a real one
in every mandate-board query.

## Why a second amount rather than a computed one

The Mandate rate is the **agreed default**. The Deal amount is **what was earned**, and the two
diverge routinely: a co-broke split halves it, a discount to close reduces it, a referral out
takes a slice. Every one of those is a fact about the transaction, not a change to the
instruction.

Conflating them means a discount granted on one sale silently rewrites the rate the owner
agreed to — the recorded history of the Mandate changes because of something that happened to
a Deal. Stored separately, the two can be compared, and the difference between them is a number
the agent can actually be shown.

**Basis points, as an integer.** `commission_rate_bp` holds 200 for 2% and 250 for 2.5%.
Percentages are fractional and would invite `REAL`; basis points give a hundredth of a percent
of resolution, which is finer than any rate that is negotiated, in an exact integer.
`commission_minor` follows ADR 0007's money convention.

## Amendment — 2026-09-12

**Basis points are the schema's only representation of a percentage.** This ADR introduced
`commission_rate_bp` without saying what happens to the other percentage already proposed for
`deals`. `deals.commission_split_pct REAL`, from the v1.1.0 roadmap
([`../database/08-review-v1.1.md` §23.2](../database/08-review-v1.1.md#tier-1)), becomes
**`deals.commission_split_bp INTEGER`**, bounded by
`CHECK (commission_split_bp IS NULL OR commission_split_bp BETWEEN 0 AND 10000)`.

The reasoning above stopped one step short. It is true that a split is a ratio rather than a
payable amount, which is why `REAL` looked defensible for it. But the split's only purpose is to
be multiplied by `commission_minor`, and `commission_minor` is money. A float factor against an
integer minor-unit amount puts inexact arithmetic back into the one number a counterparty is
most likely to dispute, which is precisely what ADR 0007's convention exists to prevent. In
integers the calculation is exact and has a single, visible rounding point:

```sql
SELECT commission_minor * commission_split_bp / 10000 FROM deals WHERE id = ?1;
```

The secondary benefit is that two spellings of "a percentage" in one schema invite the wrong one
at a call site, and a `_pct REAL` beside a `_bp INTEGER` gives no hint which is which. After this
amendment the suffix is the type.

## Consequences

**One invariant has no expressible form in this engine.** A Mandate and the Deal that names it
must be about the same Property, and SQLite cannot enforce a cross-table condition — a `CHECK`
sees one row, and subqueries are prohibited inside it. The guard lives in the Action that
creates a Deal, and it needs a test, because nothing in the database will catch it.

**Commission is why the agent opens the application**, so the reporting question — earned
versus agreed, per mandate and per period — is a first-class query rather than an afterthought.
Both numbers being stored is what makes it answerable at all.
