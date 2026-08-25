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
