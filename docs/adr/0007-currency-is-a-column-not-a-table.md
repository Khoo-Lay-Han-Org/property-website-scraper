# Currency is a column, not a table, and money columns are named `_minor`

Every amount in this database is Malaysian ringgit today. Rather than record that fact only in
prose, each money-bearing table carries `currency_code TEXT NOT NULL DEFAULT 'MYR'` with a
membership `CHECK`, and the integer amount columns are named with the suffix `_minor` — so
`price_cents` becomes `price_minor`.

## Why a column at all, when there is one currency

An amount without a currency is not a value. The failure mode is not that a second currency is
hard to add — adding the column later is additive and cheap. It is that **every amount already
stored becomes ambiguous retroactively, and no migration can tell you which rows were which.**
A backfill has to assume, and the assumption is unverifiable for exactly the rows where it
matters.

The column costs three bytes per row and nothing in any index, because nothing filters on it.
That is the cheapest insurance in the schema.

## Why not a `currencies` table

A lookup table is the right move when a value carries attributes. `MYR` carries one attribute
that matters — its minor-unit exponent, which is 2 — and that is a constant for every currency
this project will plausibly see. A table would buy referential integrity over a three-letter
code that ISO 4217 already governs, at the cost of a join on every price read. The membership
`CHECK` gets the same guarantee inside the DDL where it is visible.

**Revisit trigger:** the day a second currency appears with a different minor-unit exponent —
zero decimals, as with JPY, or three, as with KWD. At that point the exponent stops being a
constant, a `currencies` table earns its place, and the display layer can no longer divide by
100 unconditionally. Not before.

## Why `_minor` rather than `_cents`

The minor unit of MYR is the sen, not the cent, so `price_cents` is already the wrong word for
the values it holds. More usefully, `_minor` is the only suffix that stays true when the
revisit trigger fires: a column named `_cents` holding JPY is a lie that reads as a fact, and
it will be read by code that divides by 100.

`REAL` remains forbidden for money. `price_per_sqft` may stay `REAL` — it is a derived display
ratio, never a payable amount, and the rule is about money rather than about ratios.

## Consequences

Because the tables are still empty, this is a `CREATE TABLE` today. After data exists it is a
twelve-step table rebuild per table plus a backfill that cannot be verified.

Answers the open question at `docs/database/07-decisions.md` §20 item 5 (OQ-5), which held the
column in reserve. Amends the ruling at `docs/database/02-access-patterns.md` §4.2, which named
`price_cents` and recorded the currency fact in prose instead.
