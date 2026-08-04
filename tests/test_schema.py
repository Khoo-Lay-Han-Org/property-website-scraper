"""Schema + follow-up-inbox behaviour.

The inbox view is the feature most likely to be silently wrong (SQLite's two-arg
scalar MAX vs the one-arg aggregate, NULL handling when one side never happened),
so it gets exercised case by case.
"""

from pathlib import Path

import pytest
import turso

SCHEMA = Path(__file__).resolve().parents[1] / "src" / "pw" / "db" / "schema.sql"


@pytest.fixture
def db():
    conn = turso.connect(":memory:")
    conn.executescript(SCHEMA.read_text())
    return conn


def _contact(db, name, phone):
    db.execute("INSERT INTO contacts (name, phone) VALUES (?, ?)", (name, phone))
    return list(db.execute("SELECT id FROM contacts WHERE phone = ?", (phone,)))[0][0]


def _touch(db, contact_id, direction, occurred_at, channel="whatsapp"):
    db.execute(
        "INSERT INTO interactions (contact_id, channel, direction, occurred_at)"
        " VALUES (?, ?, ?, ?)",
        (contact_id, channel, direction, occurred_at),
    )


def _inbox(db):
    rows = db.execute("SELECT name, bucket, stale_hours FROM follow_up_inbox ORDER BY name")
    return {r[0]: (r[1], r[2]) for r in rows}


def test_schema_applies(db):
    tables = {r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
    assert {
        "contacts",
        "properties",
        "property_sources",
        "contact_properties",
        "interactions",
        "price_history",
        "scrape_runs",
    } <= tables


def test_inbox_buckets(db):
    never = _contact(db, "Never", "60100000001")  # noqa: F841 - inserted, untouched
    owed = _contact(db, "Owed", "60100000002")
    waiting = _contact(db, "Waiting", "60100000003")
    replied = _contact(db, "Replied", "60100000004")

    # they messaged, you never answered
    _touch(db, owed, "inbound", "2026-08-01T09:00:00")
    # you messaged, they went quiet
    _touch(db, waiting, "outbound", "2026-07-25T09:00:00")
    # they messaged and you answered after -> ball is in their court
    _touch(db, replied, "inbound", "2026-08-01T09:00:00")
    _touch(db, replied, "outbound", "2026-08-01T11:00:00")
    db.commit()

    inbox = _inbox(db)
    assert inbox["Never"][0] == "never_contacted"
    assert inbox["Owed"][0] == "owed_reply"
    assert inbox["Waiting"][0] == "awaiting_them"
    assert inbox["Replied"][0] == "awaiting_them", "replying must move a contact out of owed_reply"


def test_never_contacted_has_null_stale_hours(db):
    _contact(db, "Never", "60100000009")
    db.commit()
    assert _inbox(db)["Never"][1] is None


def test_stale_hours_measures_the_latest_touch(db):
    """stale_hours must track the most recent interaction in EITHER direction,
    not merely the inbound one — otherwise a long-dormant thread you replied to
    yesterday still reports as weeks stale."""
    c = _contact(db, "Mixed", "60100000005")
    _touch(db, c, "inbound", "2020-01-01T00:00:00")  # ancient
    _touch(db, c, "outbound", "2020-01-02T00:00:00")  # ancient, but later
    db.commit()

    (_, hours) = _inbox(db)["Mixed"]
    age_sql = "SELECT CAST((julianday('now') - julianday(?)) * 24 AS INTEGER)"
    inbound_age = list(db.execute(age_sql, ("2020-01-01T00:00:00",)))[0][0]
    outbound_age = list(db.execute(age_sql, ("2020-01-02T00:00:00",)))[0][0]
    assert hours == pytest.approx(outbound_age, abs=1), (
        f"expected age of the LATEST touch ({outbound_age}h), got {hours}h "
        f"(inbound was {inbound_age}h)"
    )


def test_owed_reply_ordering_is_by_staleness(db):
    older = _contact(db, "Older", "60100000006")
    newer = _contact(db, "Newer", "60100000007")
    _touch(db, older, "inbound", "2026-07-01T09:00:00")
    _touch(db, newer, "inbound", "2026-08-01T09:00:00")
    db.commit()

    rows = list(
        db.execute(
            "SELECT name FROM follow_up_inbox WHERE bucket='owed_reply' ORDER BY stale_hours DESC"
        )
    )
    assert [r[0] for r in rows] == ["Older", "Newer"]


def test_phone_uniqueness_is_enforced(db):
    _contact(db, "First", "60111111111")
    db.commit()
    with pytest.raises(turso.IntegrityError):
        _contact(db, "Duplicate", "60111111111")


def test_role_lives_on_the_relationship_not_the_person(db):
    """The same person can be an owner of one property and a buyer of another."""
    c = _contact(db, "Ahmad", "60122222222")
    db.execute("INSERT INTO properties (acquisition, area) VALUES ('own_mandate', 'Kajang')")
    db.execute("INSERT INTO properties (acquisition, area) VALUES ('scraped', 'Semenyih')")
    p1, p2 = [r[0] for r in db.execute("SELECT id FROM properties ORDER BY id")]

    db.execute(
        "INSERT INTO contact_properties (contact_id, property_id, role) VALUES (?,?,?)",
        (c, p1, "owner"),
    )
    db.execute(
        "INSERT INTO contact_properties (contact_id, property_id, role) VALUES (?,?,?)",
        (c, p2, "interested_buyer"),
    )
    db.commit()

    roles = {
        r[0] for r in db.execute("SELECT role FROM contact_properties WHERE contact_id = ?", (c,))
    }
    assert roles == {"owner", "interested_buyer"}


def test_bad_enum_values_are_rejected(db):
    c = _contact(db, "X", "60133333333")
    db.commit()
    with pytest.raises(turso.IntegrityError):
        _touch(db, c, "sideways", "2026-08-01T09:00:00")
    with pytest.raises(turso.IntegrityError):
        db.execute("INSERT INTO properties (acquisition) VALUES ('borrowed')")
