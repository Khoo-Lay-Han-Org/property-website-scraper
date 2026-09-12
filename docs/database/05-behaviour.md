# Views, triggers & denormalization

*Part of [Database Schema](../DATABASE_SCHEMA.md) — §11–§13. Chapter files are authoritative; the root index only summarises.*

---

## 11. Views & materialized views {#views}

### `follow_up_inbox`

The product feature, expressed as a view: three buckets over the interaction log.

| | |
|---|---|
| **Purpose** | Classify every contact into `owed_reply` (they messaged last — the ball is in your court), `awaiting_them` (you messaged last), or `never_contacted`, with `stale_hours` measuring how long it has sat there |
| **Refresh** | None — it is a plain view, computed on every read |
| **Staleness** | Zero by construction |
| **Locking** | None |
| **Cost** | A `GROUP BY` over all `interactions` plus a `LEFT JOIN` against all `contacts`, on every read. At ~1,300 contacts and ~7,300 interactions this is microseconds. **The threshold to watch: ~100,000 interactions**, at which point promote it to a real table rebuilt after each write — materialized views do not exist in this engine family (profile §10) |
| **Engine risk** | **Views are behind `--experimental-views` on this engine** (§2.7). They demonstrably work through `pyturso` 0.7.2 `[MEASURED: 8/8 tests pass, four of which query this view @ 2026-08-06]`, but "works" and "supported" are different guarantees |

> ⚠️ **SUPERSEDED v1.1.0** — **cut the view; keep the query.** The engine risk recorded in the row above was noted and then accepted; v1.1.0 declines to accept it. Thirty lines of SQL in `src/pw/queries/` cost nothing and remove the schema's largest fragility. The `active_feed` recommendation below falls with it. See §24.1 — and §22.3 for an ordering defect in the definition itself.

Two subtleties in the definition that are easy to get wrong and are correct here — both locked by tests:

- `MAX(a, b)` inside the `CASE` is SQLite's **two-argument scalar** max, not the aggregate. `COALESCE(MAX(last_inbound_at, last_outbound_at), last_inbound_at, last_outbound_at)` therefore returns the later of the two when both exist and the non-null one when only one does. `test_stale_hours_measures_the_latest_touch` exists specifically because getting this wrong makes a thread you replied to yesterday report as weeks stale.
- `never_contacted` yields `NULL` stale hours rather than a sentinel — `test_never_contacted_has_null_stale_hours`. `NULL` means unknown, which is exactly right: there is no ball, so it has been in nobody's court for no time.

> ⚠️ **SUPERSEDED v1.1.0** — the value is right and the *consequence* was not followed through. AP-06 sorts `stale_hours DESC`, SQLite sorts `NULL` smallest, so `DESC` puts never-contacted rows **last** — the bucket that most needs action is the one the ordering hides. See §22.3.

**Recommended addition — an active-feed view.** Doctrine §9: a view is the cheap way to stop a filter being forgotten. Since §7.3 rules that scraped rows are hard-deleted rather than soft-deleted, there is no `deleted_at` to forget — but there *is* a `status='active'` that every feed query must remember:

```sql
-- ⚠️ SUPERSEDED 2026-09-11. The predicate is now:
--   WHERE listing_status = 'visible'
--     AND NOT EXISTS (SELECT 1 FROM mandates m
--                      WHERE m.property_id = properties.id
--                        AND m.withdrawn_on IS NULL AND m.completed_on IS NULL)
-- which still matches idx_properties_feed's partial predicate. See ADR 0006.
CREATE VIEW active_feed AS
SELECT * FROM properties
 WHERE acquisition = 'scraped' AND status = 'active';
```

Its predicate matches `idx_properties_feed`'s partial predicate exactly, so queries through it use that index.

---

## 12. Triggers & functions {#triggers}

**There are no triggers, and on this engine there should not be.**

Doctrine §8 makes a trigger-maintained `updated_at` the baseline, on the grounds that you cannot trust every write path to remember and the one that forgets is the one you need. That recommendation is **not available here**: triggers are gated behind `--experimental-*` on Turso Database 0.7.x and listed as absent in its manual (§2.7). Per Gate 2 Step 3, where the engine lacks a feature and the profile offers no workaround, the requirement moves to the application layer and is recorded as a gap — **IG-4**.

If the embedded path moves to stock SQLite (§16, the recommended direction), triggers become available and stable, and this is the first thing to add:

```sql
-- stock SQLite 3.37+ ONLY — not on Turso Database 0.7.x
CREATE TRIGGER trg_properties_updated_at
AFTER UPDATE ON properties FOR EACH ROW
BEGIN
  UPDATE properties SET updated_at = datetime('now') WHERE id = NEW.id;
END;
```

(One per mutable table: `contacts`, `properties`. `interactions` and `property_parties` have no `updated_at` by design — they are append-only.)

No stored functions. No user-defined functions. Both would be application code in a database, and this database has no application yet.

---

## 13. Denormalization register {#denormalization}

| Field | Source of truth | Maintained by | Staleness tolerated | Justifying AP |
|---|---|---|---|---|
| `price_history.property_id` (alongside the proposed `property_source_id`) | `advertisements.property_id` | Application, at insert | **Zero** — set once, never updated; the parent link is immutable | **AP-13.** Without it, "price trail for this unit across all portals" needs a join to `advertisements` on every read. With it, it is a single index probe on `idx_price_history` |
| `properties.price_minor` (the current price, also observable as the newest `price_history` row) | Arguably `price_history` | Application, on each scrape | One scrape cycle (~24 h) | **AP-05.** The feed browse filters and sorts on current price; deriving it from a `MAX(observed_at)` subquery per row would make the hottest read path a correlated subquery |
| `properties.price_per_sqft` | `price_minor / size_sqft` | Producer, at insert | Until the next scrape | Display only. **Note the drift risk**: when `price_minor` updates on a rescrape and `size_sqft` does not, nothing recomputes this. Prefer a *generated column* — but generated columns are experimental on this engine (§2.7), so it stays a plain column with an application obligation. Revisit on the move to stock SQLite. **⚠️ SUPERSEDED v1.1.0** — the drift risk named here has no reader to justify it. **Cut the column**; see §24.3 |

**Not denormalization, and frequently mistaken for it:** `advertisements.price_at_scrape_minor` is a **snapshot of a mutable value at observation time** (doctrine §1). The current asking price and the price this portal quoted on 3 August are different facts, and storing both is correctness, not redundancy. The same argument covers every row in `price_history`.

> ⚠️ **SUPERSEDED v1.1.0** — the *distinction* drawn above is sound; the conclusion does not follow. `price_at_scrape_minor` is a snapshot, and the snapshot is already stored — it is the newest `price_history` row for that source, one index probe away, and no access pattern reads the column. **Cut it**; see §24.4, including the ingest change the cut requires.

**Explicitly rejected denormalizations.** No `properties.contact_count`, no `contacts.last_interaction_at`, no `properties.source_count`. Each would need a maintenance mechanism (trigger — unavailable, §12) and each answers a question that a sub-millisecond index probe already answers at these volumes. Doctrine §1 requires a **measured** slow query before denormalizing; there is no such measurement because there is no such query.

---
