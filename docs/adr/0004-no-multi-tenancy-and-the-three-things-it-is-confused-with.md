# No multi-tenancy, and the three things it gets confused with

This database serves one agent and carries no tenant key anywhere. That is a decision rather
than an omission, and it is recorded here because the question keeps arriving wearing two
disguises: an agent asking to split a commission with someone from another agency, and an
agency asking whether a colleague can log in. Neither of those is multi-tenancy, and treating
them as if they were would add the single most expensive column in the schema to solve a
problem that does not need it.

## The three questions, kept apart

| Question | What it actually asks | What it costs to add | In scope? |
|---|---|---|---|
| **Co-broke** | Two agents from different agencies co-operate on one transaction and split the commission | Nothing structural. A Contact in the `co_agent` Deal Role, plus `deals.commission_minor` recording what was actually earned rather than the mandate rate | **Yes, today.** Already modelled — see ADR 0010 |
| **Multi-user** | Several people inside one agency share one book, with different permissions over the same rows | Users, roles and a row-ownership column. Additive: new tables plus one nullable FK, no unique key changes | **No, but cheap later.** Not blocked by anything here |
| **Multi-tenant** | Several agencies' data live in one database and must be mutually invisible | `tenant_id` on every table, leading every composite index and every unique constraint — including `UNIQUE (portal_id, advertisement_id)` | **No, and expensive later** |

The reason to write these down together is that they are usually asked in the same sentence
and answered as if they were one question. They are not. Co-broke is a fact about a
transaction. Multi-user is a fact about authentication. Multi-tenancy is a fact about data
isolation, and only the third one reaches the schema.

## The ruling

No `tenant_id`, on any table. A column that is always `1` costs bytes in every index and
option value in nothing, because the retrofit it is meant to avoid is not made materially
cheaper by having the column present but unenforced.

**The trigger is a day, not a metric: the first day a second agency's data enters this
database.** At that moment `tenant_id` is added everywhere and every composite index and
unique constraint is rebuilt to lead with it. In SQLite that is a table rebuild per table, not
an `ALTER`. This is correctly called a rewrite rather than a migration, and it should be
planned as one.

## Consequences

**One deadline is earlier than the schema's.** Laravel's starter kit can be scaffolded with
team support — users belong to teams, routes scoped by team slug — and that choice is made at
`laravel new` time and is disruptive to add afterwards. Scaffold **without** teams. If the
answer to multi-tenancy ever becomes yes, the application half is re-scaffolded alongside the
schema rewrite, which is the same event.

**Uniqueness is where the pain lands, not row filtering.** Adding a tenant filter to queries
is mechanical and a linter can find the misses. Rebuilding `UNIQUE (portal_id,
advertisement_id)` into `UNIQUE (tenant_id, portal_id, advertisement_id)` changes what the
database considers the same advertisement, and two agencies scraping the same portal produce
exactly the rows that distinction governs.

Supersedes the open question at `docs/database/07-decisions.md` §20 item 6 (OQ-6). The
tripwire prose at `docs/database/02-access-patterns.md` §3 stands and now points here.
