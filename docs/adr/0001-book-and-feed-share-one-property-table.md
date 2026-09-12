# The book and the feed share one Property, separated by acquisition

The agent's own mandates and the scraped portal inventory have different volumes, lifecycles
and value, which makes splitting them into two tables the obvious move. We did not split
them, because a scraped listing routinely becomes an own mandate: the agent calls the owner
and wins the instruction. With one Property carrying an `acquisition` discriminator that
conversion is a single column update; with two tables it is a cross-table move that breaks
every foreign key from Interaction and Property Role, and loses the first-seen date.

## Consequences

The ten real mandates live in the same table as four thousand scraped rows, so every
book-side query must filter on the discriminator and the indexes serving them must lead with
it. That cost is paid deliberately in exchange for making the most important state change in
the domain free.

See `docs/database/07-decisions.md` §19 item 3 for the full argument.

## Amendment — the claim survives, the mechanism does not

**ADR 0006 deletes `acquisition`.** The decision recorded here — one Property table rather than
two — is unchanged and is now better supported than when it was written. What is superseded is
only the mechanism named above.

The conversion this ADR exists to protect no longer costs even a column update. Winning a
mandate on a scraped unit is one `INSERT` into `mandates`, with `properties` not written to at
all, so `first_seen_at` cannot be disturbed by it. Whether a Property is in the book or the
feed is derived from whether an open Mandate and an Advertisement exist for it, which means
both at once is expressible — and the agent winning a mandate and then advertising the unit
themselves is routine.

The consequence above is also withdrawn along with the mechanism: book-side queries no longer
filter on a discriminator, and `idx_properties_acq` is deleted and not replaced. The mandate
board leads from the small `mandates` table instead.

