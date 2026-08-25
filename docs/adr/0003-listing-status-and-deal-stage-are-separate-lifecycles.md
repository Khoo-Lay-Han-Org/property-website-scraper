# Listing status and deal stage are separate lifecycles

A Property originally carried one status spanning `active`, `under_offer`, `closed`,
`withdrawn` and `expired`. Those values have two different owners — the expiry sweep sets
some from staleness, the agent sets the others by hand — and they overwrite each other: a
unit moved to `under_offer` never expires, and a unit that should be `under_offer` is reset
to `expired` whenever the agent has not updated it yet. Which outcome you get depends on a
race between a human and a cron job, and both are silent.

The deeper error is grain. Being under offer is a fact about a transaction attempt, not about
a unit, and a unit can be under offer to one buyer while still being marketed to others.
Listing Status therefore keeps only `active`, `expired` and `withdrawn`; everything else
becomes a Deal's Stage.

## Consequences

"Is this unit spoken for" stops being a column read and becomes a question about whether any
Deal on it has reached offer or beyond. That is the correct question, and it is one the
previous shape could not express at all.

See `docs/database/08-review-v1.1.md` §22.5.
