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

---

## Amendment — three lifecycles, three owners, and a word that had to change

Mandate becomes an entity (ADR 0009), which adds a third lifecycle to the two this ADR
separated. Three is the number, and the reason they must stay apart is the same as before:
each has a different owner, and an owner that does not know it shares a column overwrites the
others.

| Lifecycle | Values | Owner | Grain |
|---|---|---|---|
| **Property visibility** | `visible` \| `hidden` | the staleness sweep and the owner's decision | the unit |
| **Mandate status** | `open` \| `withdrawn` \| `expired` \| `completed` | the agent, as dates; `expired` is derived from `expires_on` | the instruction |
| **Deal stage** | first lead through to completed or lost | the agent, by hand. Never a machine | one transaction attempt |

### The rename, and why it was not optional

All three vocabularies previously used `active`, `expired` and `withdrawn`, and the three
meanings do not agree. A withdrawn *Mandate* means the owner pulled the instruction; a
withdrawn *Property* meant the unit stopped being marketed. An expired Mandate has passed
`expires_on`; an expired Property had not been seen on a portal for fourteen days. Sharing
three words across three lifecycles guarantees that a query, a report or a conversation
eventually means the wrong one.

So a Mandate is `open` / `withdrawn` / `expired` / `completed`, and a Property is `visible` /
`hidden`. No word appears in both lists.

### `listing_status` stays a stored column

Deriving Property visibility was considered and rejected. It is written together with the
Mandate inside one Action, and it stays a stored, indexed column because under ADR 0005 a
stored indexed column is what makes the feed query fast. This is a deliberate exception to the
rule ADR 0006 applies to `acquisition` — the difference is that a single Action owns every
write to it, so there *is* an event that maintains it, and that Action is testable.
